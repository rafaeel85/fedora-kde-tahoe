/*
    macOS Tahoe style lock screen for Plasma (based on the Plasma 6.8 LockScreenUi).
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n

import org.kde.plasma.private.sessions
import org.kde.plasma.private.battery
import org.kde.breeze.components

Item {
    id: lockScreenUi

    readonly property string fontFamily: "Inter Display"
    readonly property string textFamily: "Inter"

    property bool expectingPrompt: false
    property bool showPrompt: false
    property string pendingPassword

    function handleMessage(msg) {
        if (!msg) return;
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
        lockScreenRoot.uiVisible = true
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return;
            const msg = i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed");
            lockScreenUi.handleMessage(msg);
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationRemoveTimer.restart();
            shake.start();
        }
        function onSucceeded() {
            authenticator.stopAuthenticating()
            if (!lockScreenUi.expectingPrompt) Qt.quit()
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"), { userListModel: users }, StackView.Immediate);
                mainStack.forceActiveFocus();
            }
        }
        function onInfoMessageChanged() { lockScreenUi.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { lockScreenUi.handleMessage(authenticator.errorMessage); }
        function onPromptChanged() { lockScreenUi.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged() {
            passwordBox.forceActiveFocus();
            if (lockScreenUi.showPrompt) lockScreenUi.handleMessage(authenticator.promptForSecret);
        }
        function onPamTimeoutChanged(): void {
            if (!authenticator.pamTimeout && lockScreenUi.pendingPassword.length > 0) {
                authenticator.respond(lockScreenUi.pendingPassword);
                lockScreenUi.pendingPassword = "";
                passwordBlock.enabled = true;
            }
        }
    }

    SessionManagement { id: sessionManagement }
    AccessibilityStatus { id: accessibilityStatus }
    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }
    BatteryControlModel { id: batteryControl }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword(); }
    }

    ListModel {
        id: users
        Component.onCompleted: users.append({
            name: kscreenlocker_userName,
            realName: kscreenlocker_userName,
            icon: kscreenlocker_userImage !== ""
                  ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : "",
        })
    }

    // ---- glass helpers ----
    component Glass : Rectangle {
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
        Rectangle { // top sheen
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    component RoundAction : Item {
        id: ra
        property string iconName
        property string label
        signal clicked()
        implicitWidth: 76
        implicitHeight: 70
        Glass {
            id: raBg
            width: 40; height: 40; radius: 20
            anchors.horizontalCenter: parent.horizontalCenter
            color: raMouse.pressed ? Qt.rgba(1,1,1,0.34) : raMouse.containsMouse ? Qt.rgba(1,1,1,0.26) : Qt.rgba(1,1,1,0.16)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20; height: 20
                source: ra.iconName
                isMask: true
                color: "white"
            }
        }
        Text {
            anchors.top: raBg.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: ra.label.replace("&", "")
            color: "white"
            opacity: raMouse.containsMouse ? 1 : 0.85
            font.family: lockScreenUi.textFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: raMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: ra.clicked()
        }
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || passwordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) Window.window.requestActivate();
            if (blockUI) fadeoutTimer.running = false;
            else if (uiVisible) fadeoutTimer.restart();
            authenticator.startAuthenticating();
        }
        onBlockUIChanged: {
            if (blockUI) { fadeoutTimer.running = false; uiVisible = true; }
            else fadeoutTimer.restart();
        }

        Timer {
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }

        ScreenLocker.ActiveScreenMonitor {
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: if (!active) lockScreenRoot.uiVisible = false;
        }
        Keys.onEscapePressed: {
            if (uiVisible) {
                uiVisible = false;
                if (Keyboards.KWinVirtualKeyboard.visible) Keyboards.KWinVirtualKeyboard.active = false;
                root.clearPassword();
            }
        }
        Keys.onPressed: event => { uiVisible = true; event.accepted = false; }

        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: if (!lockScreenRoot.blockUI) lockScreenRoot.uiVisible = false;
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        // ---------- wallpaper ----------
        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            blurEnabled: true
            blurMax: 64
            blur: lockScreenRoot.uiVisible ? 0.55 : 0.0
            saturation: lockScreenRoot.uiVisible ? 0.15 : 0.0
            brightness: lockScreenRoot.uiVisible ? -0.06 : 0.0
            Behavior on blur { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on brightness { NumberAnimation { duration: 450 } }
            Behavior on saturation { NumberAnimation { duration: 450 } }
        }
        // legibility vignettes
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height * 0.38
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.22) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.35
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.28) }
            }
        }

        // ---------- top-right status ----------
        RowLayout {
            anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 18 }
            spacing: 14

            Item {
                id: kbItem
                visible: kbSwitcher.hasMultipleKeyboardLayouts
                implicitWidth: kbBadge.width
                implicitHeight: 18
                Rectangle {
                    id: kbBadge
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(22, kbText.implicitWidth + 8); height: 15; radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: "white"
                    Text {
                        id: kbText
                        anchors.centerIn: parent
                        text: kbSwitcher.layoutNames.shortName.toUpperCase()
                        color: "white"
                        font.family: lockScreenUi.textFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
                PW.KeyboardLayoutSwitcher {
                    id: kbSwitcher
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: keyboardLayout.switchToNextLayout()
                }
            }

            Row {
                visible: batteryControl.hasInternalBatteries
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: batteryControl.percent + "%"
                    color: "white"
                    font.family: lockScreenUi.textFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Item { // Tahoe battery glyph
                    width: 27; height: 13
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        x: 0; y: 0; width: 24; height: 13; radius: 4
                        color: Qt.rgba(1, 1, 1, 0.30)
                        Rectangle {
                            x: 2; y: 2; height: 9; radius: 2
                            width: Math.max(2, Math.round(20 * batteryControl.percent / 100))
                            color: batteryControl.percent <= 20 && !batteryControl.pluggedIn ? "#ff453a" : "white"
                        }
                    }
                    Rectangle { x: 25; y: 4; width: 2; height: 5; radius: 1; color: Qt.rgba(1, 1, 1, 0.45) }
                }
            }
        }

        // ---------- clock ----------
        Column {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.075)
            spacing: -6
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.35)
                shadowBlur: 0.6
                shadowVerticalOffset: 1
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: lockScreenUi.fontFamily
                font.pixelSize: 26
                font.weight: Font.DemiBold
                text: Qt.locale().toString(timeSource.now, "dddd, d MMMM")
            }
            Text {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: lockScreenUi.fontFamily
                font.pixelSize: Math.round(Math.min(lockScreenRoot.height * 0.16, 190))
                font.weight: Font.Bold
                font.letterSpacing: -2
                text: Qt.locale().toString(timeSource.now, "H:mm")
            }
        }
        QtObject {
            id: timeSource
            property date now: new Date()
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: timeSource.now = new Date()
        }

        // ---------- main block ----------
        StackView {
            id: mainStack
            anchors.fill: parent
            focus: true
            visible: opacity > 0

            initialItem: Item {
                id: passwordBlock

                Column {
                    id: userColumn
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(lockScreenRoot.height * 0.09)
                    spacing: 0

                    transform: Translate { id: shakeX }

                    // avatar
                    Item {
                        width: 64; height: 64
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            id: avatarFallback
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#a5a9b4" }
                                GradientStop { position: 1; color: "#6e727c" }
                            }
                            visible: avatarImg.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: kscreenlocker_userName.charAt(0).toUpperCase()
                                color: "white"
                                font.family: lockScreenUi.fontFamily
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                            }
                        }
                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: users.count > 0 ? users.get(0).icon : ""
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: avatarImg
                            visible: avatarImg.status === Image.Ready
                            maskEnabled: true
                            maskSource: avatarMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                        Item {
                            id: avatarMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                        }
                    }

                    Item { width: 1; height: 10 }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: kscreenlocker_userName.charAt(0).toUpperCase() + kscreenlocker_userName.slice(1)
                        color: "white"
                        font.family: lockScreenUi.textFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.15)
                    }

                    Item { width: 1; height: 12 }

                    // password pill
                    Glass {
                        id: field
                        width: 220; height: 32; radius: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lockScreenUi.passwordInputVisible
                        color: passwordBox.activeFocus ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.15)

                        TextInput {
                            id: passwordBox
                            anchors.left: parent.left
                            anchors.right: goButton.left
                            anchors.leftMargin: 14
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            passwordMaskDelay: 0
                            color: "white"
                            selectionColor: Qt.rgba(1, 1, 1, 0.35)
                            font.family: lockScreenUi.textFamily
                            font.pixelSize: passwordBox.text.length ? 10 : 13
                            font.letterSpacing: passwordBox.text.length ? 2 : 0
                            clip: true
                            focus: true
                            cursorVisible: visible && activeFocus
                            cursorDelegate: Rectangle { width: 1.5; color: "white"; visible: passwordBox.cursorVisible
                                SequentialAnimation on opacity { loops: Animation.Infinite; running: passwordBox.cursorVisible
                                    NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                            text: PasswordSync.password

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordBox.text.length === 0
                                text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
                                color: Qt.rgba(1, 1, 1, 0.62)
                                font.family: lockScreenUi.textFamily
                                font.pixelSize: 13
                            }

                            onAccepted: lockScreenUi.startLogin()
                            Keys.onEnterPressed: lockScreenUi.startLogin()

                            Connections {
                                target: root
                                function onClearPassword() {
                                    passwordBox.forceActiveFocus()
                                    passwordBox.text = "";
                                    passwordBox.text = Qt.binding(() => PasswordSync.password);
                                }
                                function onNotificationRepeated() { shake.start(); }
                            }
                        }
                        Binding { target: PasswordSync; property: "password"; value: passwordBox.text }

                        Rectangle {
                            id: goButton
                            width: 22; height: 22; radius: 11
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: goMouse.pressed ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.32)
                            opacity: passwordBox.text.length > 0 ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 14; height: 14
                                source: "go-next"
                                isMask: true
                                color: "white"
                            }
                            MouseArea { id: goMouse; anchors.fill: parent; onClicked: lockScreenUi.startLogin() }
                        }
                    }

                    Item { width: 1; height: 10 }

                    Text {
                        id: hint
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.family: lockScreenUi.textFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        text: {
                            const parts = [];
                            if (capsLockState.locked) parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"));
                            if (accessibilityStatus.slowKeysEnabled) parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Slow Keys are enabled"));
                            if (root.notification) parts.push(root.notification);
                            if (parts.length === 0 && (authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint))
                                parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your fingerprint on the reader)"));
                            return parts.join(" • ");
                        }
                        height: Math.max(implicitHeight, 16)
                    }

                    // authenticator selector (only when several exist)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        visible: authRepeater.count > 1
                        Repeater {
                            id: authRepeater
                            model: ScreenLocker.AuthenticatorModel
                            delegate: PlasmaComponents3.ToolButton {
                                required property int type
                                required property string iconName
                                required property bool passwordField
                                required property bool expectingPrompt
                                required property string tooltip
                                required property bool showPrompt
                                required property bool functional
                                enabled: functional
                                icon.name: iconName
                                checked: authenticator.authenticator === type
                                onClicked: {
                                    authenticator.authenticator = type
                                    root.notification = ""
                                    lockScreenUi.passwordInputVisible = passwordField
                                    lockScreenUi.expectingPrompt = expectingPrompt
                                    lockScreenUi.showPrompt = showPrompt
                                }
                                PlasmaComponents3.ToolTip.text: tooltip
                                PlasmaComponents3.ToolTip.visible: hovered
                                Component.onCompleted: if (checked) clicked()
                            }
                        }
                    }
                }

                // bottom actions (Sleep / Switch user)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 18
                    opacity: lockScreenRoot.uiVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    RoundAction {
                        visible: sessionManagement.canSuspend
                        iconName: "system-suspend"
                        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Slee&p")
                        onClicked: sessionManagement.suspend()
                    }
                    RoundAction {
                        visible: sessionManagement.canSwitchUser
                        iconName: "system-switch-user"
                        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Switch &User")
                        onClicked: sessionManagement.switchUser()
                    }
                }

                StackView.onStatusChanged: {
                    if (StackView.status === StackView.Activating) {
                        passwordBox.text = "";
                        passwordBox.focus = true;
                        root.notification = "";
                    }
                }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Kirigami.Units.gridUnit }
        }
    }

    property bool passwordInputVisible: true

    function startLogin() {
        if (!lockScreenRoot.uiVisible) {
            lockScreenRoot.uiVisible = true;
            return;
        }
        const password = passwordBox.text;
        if (authenticator.pamTimeout) {
            lockScreenUi.pendingPassword = password;
            passwordBlock.enabled = false;
        } else {
            authenticator.respond(password);
        }
    }

    SequentialAnimation {
        id: shake
        property real d: 10
        NumberAnimation { target: shakeX; property: "x"; to: -shake.d; duration: 50 }
        NumberAnimation { target: shakeX; property: "x"; to: shake.d; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: -shake.d * 0.7; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: shake.d * 0.5; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
    }
}
