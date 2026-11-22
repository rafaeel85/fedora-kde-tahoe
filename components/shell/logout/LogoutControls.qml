/*
    macOS Tahoe style shutdown / restart / log out alert.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami

import org.kde.plasma.private.sessions

import "timer.js" as AutoTriggerTimer

Item {
    id: controls
    anchors.fill: parent

    readonly property Item hostRoot: parent
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    readonly property string textFamily: "Inter"
    readonly property color accent: "#0a84ff"

    opacity: 0
    onHostRootChanged: fadeIn.restart()

    ParallelAnimation {
        id: fadeIn
        NumberAnimation { target: controls; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; from: 1.08; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    KCoreAddons.KUser { id: kuser }

    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    function tr(s) { return s.replace("&", ""); }
    readonly property int secs: Math.max(0, Math.ceil(controls.hostRoot.remainingTime))
    // Always two digit-widths (figure space U+2007 pads 0-9) + tabular digits,
    // so the countdown never changes the line wrapping / card height.
    readonly property string secsText: (secs < 10 ? "\u2007" : "") + secs

    readonly property string titleText: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: return "Bilgisayarınızı şimdi yeniden başlatmak istediğinizden emin misiniz?";
        case ShutdownType.ShutdownTypeHalt:   return "Bilgisayarınızı şimdi kapatmak istediğinizden emin misiniz?";
        case ShutdownType.ShutdownTypeNone:   return "Tüm uygulamalardan çıkıp oturumu kapatmak istediğinizden emin misiniz?";
        default:                              return "Ne yapmak istiyorsunuz?";
        }
    }
    readonly property string messageText: {
        // Text stays (only fades) when the countdown is cancelled, so the
        // card never changes height under the pointer.
        if (showAllOptions)
            return "Bilgisayarı uyutabilir, yeniden başlatabilir, kapatabilir ya da oturumu kapatabilirsiniz.";
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: return "Hiçbir şey yapmazsanız, bilgisayar " + secsText + " saniye içinde otomatik olarak yeniden başlayacak.";
        case ShutdownType.ShutdownTypeHalt:   return "Hiçbir şey yapmazsanız, bilgisayar " + secsText + " saniye içinde otomatik olarak kapanacak.";
        default:                              return "Hiçbir şey yapmazsanız, " + secsText + " saniye içinde otomatik olarak oturumunuz kapatılacak.";
        }
    }

    // -------- buttons --------
    component AlertButton : Rectangle {
        id: btn
        property string label
        property bool primary: false
        property bool destructive: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        radius: 14
        activeFocusOnTab: true
        color: primary ? (btnMouse.pressed ? Qt.darker(controls.accent, 1.2) : controls.accent)
                       : (btnMouse.pressed ? Qt.rgba(1, 1, 1, 0.26) : btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.14))
        border.width: activeFocus ? 2 : 0
        border.color: Qt.rgba(controls.accent.r, controls.accent.g, controls.accent.b, 0.7)
        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: btn.label
            color: btn.destructive ? "#ff6961" : "white"
            font.family: controls.textFamily
            font.pixelSize: 13
            font.weight: btn.primary ? Font.DemiBold : Font.Medium
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.activated()
        }
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        Keys.onPressed: event => { AutoTriggerTimer.cancelAutoTrigger(); event.accepted = false; }
    }

    function doPrimary() {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: controls.hostRoot.rebootRequested(); break;
        case ShutdownType.ShutdownTypeNone: controls.hostRoot.logoutRequested(); break;
        default: controls.hostRoot.haltRequested(); break;
        }
    }

    readonly property string primaryLabel: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: return tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Restart"));
        case ShutdownType.ShutdownTypeNone: return tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Log Out"));
        default: return tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Shut Down"));
        }
    }

    // -------- card --------
    Item {
        id: cardShadowHost
        anchors.centerIn: parent
        width: card.width
        height: card.height

        MultiEffect {
            anchors.fill: card
            source: card
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 1.0
            shadowVerticalOffset: 10
            blurMax: 48
        }

        Rectangle {
            id: card
            width: 272
            height: content.implicitHeight + 40
            radius: 26
            color: Qt.rgba(0.17, 0.17, 0.19, 0.96)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.13)

            Rectangle { // inner highlight
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)
            }

            MouseArea { anchors.fill: parent } // swallow clicks so the backdrop doesn't cancel

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 0

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    source: sdtype === ShutdownType.ShutdownTypeNone ? "system-log-out" : "computer"
                    fallback: "system-shutdown"
                }

                Item { Layout.preferredHeight: 14 }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: controls.titleText
                    color: "white"
                    font.family: controls.textFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    lineHeight: 1.1
                }

                Item { Layout.preferredHeight: controls.messageText ? 8 : 0 }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: controls.messageText
                    opacity: (controls.showAllOptions || controls.hostRoot.countingDown) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.family: controls.textFamily
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    lineHeight: 1.15
                }

                // extra notes (other sessions, firmware, bootloader)
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    visible: otherSessionsModel.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || controls.showAllOptions)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#ffd60a"
                    font.family: controls.textFamily
                    font.pixelSize: 11
                    text: i18ndp("plasma_shell_org.kde.plasma.desktop",
                                 "One other user is currently logged in. If the computer is shut down or restarted, that user may lose work.",
                                 "%1 other users are currently logged in. If the computer is shut down or restarted, those users may lose work.",
                                 otherSessionsModel.count)
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    visible: rebootToFirmwareSetup || rebootToBootLoaderMenu || rebootToBootLoaderEntry != ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.family: controls.textFamily
                    font.pixelSize: 11
                    text: rebootToFirmwareSetup ? i18nd("plasma_shell_org.kde.plasma.desktop", "When restarted, the computer will enter the firmware setup screen.")
                        : rebootToBootLoaderMenu ? i18nd("plasma_shell_org.kde.plasma.desktop", "When restarted, the computer will enter the boot loader menu.")
                        : i18ndc("plasma_shell_org.kde.plasma.desktop", "%1 is a boot loader entry", "When restarted, the computer will switch to %1.", rebootToBootLoaderEntry)
                }

                Item { Layout.preferredHeight: 18 }

                // ---- specific action: Cancel | Primary side by side ----
                RowLayout {
                    Layout.fillWidth: true
                    visible: !controls.showAllOptions
                    spacing: 8
                    AlertButton {
                        id: cancelA
                        Layout.preferredWidth: 1
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Cancel"))
                        onActivated: controls.hostRoot.cancelRequested()
                        KeyNavigation.right: primaryA
                        KeyNavigation.tab: primaryA
                    }
                    AlertButton {
                        id: primaryA
                        Layout.preferredWidth: 1
                        primary: true
                        label: controls.primaryLabel
                        focus: !controls.showAllOptions
                        onActivated: controls.doPrimary()
                        KeyNavigation.left: cancelA
                        KeyNavigation.tab: cancelA
                    }
                }
                AlertButton {
                    visible: !controls.showAllOptions && softwareUpdatePending && maysd
                             && (sdtype === ShutdownType.ShutdownTypeReboot || sdtype === ShutdownType.ShutdownTypeHalt)
                    Layout.topMargin: 8
                    label: sdtype === ShutdownType.ShutdownTypeReboot
                           ? controls.tr(i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button Keep short", "Install Updates and Restart"))
                           : controls.tr(i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button Keep short", "Install Updates and Shut Down"))
                    onActivated: sdtype === ShutdownType.ShutdownTypeReboot ? controls.hostRoot.rebootUpdateRequested() : controls.hostRoot.haltUpdateRequested()
                }

                // ---- all options: stacked ----
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: controls.showAllOptions
                    spacing: 8
                    AlertButton {
                        id: shutAll
                        visible: maysd
                        primary: true
                        focus: controls.showAllOptions
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Shut Down"))
                        onActivated: controls.hostRoot.haltRequested()
                        KeyNavigation.down: rebootAll; KeyNavigation.tab: rebootAll
                    }
                    AlertButton {
                        id: rebootAll
                        visible: maysd
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Restart"))
                        onActivated: controls.hostRoot.rebootRequested()
                        KeyNavigation.up: shutAll; KeyNavigation.down: sleepAll; KeyNavigation.tab: sleepAll
                    }
                    AlertButton {
                        id: sleepAll
                        visible: spdMethods.SuspendState
                        label: controls.tr(i18ndc("plasma_shell_org.kde.plasma.desktop", "Suspend to RAM", "Slee&p"))
                        onActivated: controls.hostRoot.sleepRequested()
                        KeyNavigation.up: rebootAll; KeyNavigation.down: hibAll.visible ? hibAll : logoutAll; KeyNavigation.tab: hibAll.visible ? hibAll : logoutAll
                    }
                    AlertButton {
                        id: hibAll
                        visible: spdMethods.HibernateState
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Hibernate"))
                        onActivated: controls.hostRoot.hibernateRequested()
                        KeyNavigation.up: sleepAll; KeyNavigation.down: logoutAll; KeyNavigation.tab: logoutAll
                    }
                    AlertButton {
                        id: logoutAll
                        visible: canLogout
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Log Out")) + (kuser.loginName ? " (" + kuser.loginName + ")" : "")
                        onActivated: controls.hostRoot.logoutRequested()
                        KeyNavigation.up: hibAll.visible ? hibAll : sleepAll; KeyNavigation.down: cancelAll; KeyNavigation.tab: cancelAll
                    }
                    AlertButton {
                        id: cancelAll
                        label: controls.tr(i18nd("plasma_shell_org.kde.plasma.desktop", "&Cancel"))
                        onActivated: controls.hostRoot.cancelRequested()
                        KeyNavigation.up: logoutAll; KeyNavigation.tab: shutAll
                    }
                }
            }
        }
    }
}
