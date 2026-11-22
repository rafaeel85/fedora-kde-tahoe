// macOS Tahoe style notification banner content
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Item {
    id: card

    // data
    property int type: NotificationManager.Notifications.NotificationType
    property string summary
    property string body
    property string applicationName
    property var icon
    property string appIcon
    property date time
    property var actionNames: []
    property var actionLabels: []
    property int percentage: 0
    property int jobState: 0
    property var jobDetails: null

    function fmtBytes(b) {
        if (!(b > 0)) return "0 B";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; ++i; }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)).toString().replace(".", ",") + " " + u[i];
    }
    function fmtLeft(sec) {
        if (sec < 60) return Math.max(1, Math.round(sec)) + " sn kaldı";
        if (sec < 3600) return "~" + Math.round(sec / 60) + " dk kaldı";
        return "~" + Math.floor(sec / 3600) + " sa " + Math.round((sec % 3600) / 60) + " dk kaldı";
    }
    readonly property string jobText: {
        const d = card.jobDetails;
        if (!card.isJob || !d) return "";
        const parts = [];
        if (d.totalBytes > 0) parts.push(fmtBytes(d.processedBytes) + " / " + fmtBytes(d.totalBytes));
        else if (d.totalFiles > 1) parts.push(d.processedFiles + " / " + d.totalFiles + " dosya");
        if (card.jobState === NotificationManager.Notifications.JobStateSuspended) parts.push("Duraklatıldı");
        else if (d.speed > 0) {
            parts.push(fmtBytes(d.speed) + "/s");
            if (d.totalBytes > d.processedBytes) parts.push(fmtLeft((d.totalBytes - d.processedBytes) / d.speed));
        }
        return parts.join(" · ");
    }
    property bool killable: false
    property bool suspendable: false
    property bool closable: true
    property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    property int now: 0  // bump to refresh the "ago" label

    signal clicked()
    signal closeClicked()
    signal actionClicked(string name)
    signal killClicked()
    signal suspendClicked()
    signal resumeClicked()

    readonly property string font: "Inter"
    readonly property bool isJob: type === NotificationManager.Notifications.JobType
    readonly property bool hasImage: icon !== undefined && icon !== null && typeof icon !== "string"

    implicitWidth: 330
    implicitHeight: Math.max(48, content.implicitHeight + 22)

    function ago() {
        card.now;
        const t = card.time;
        if (!t || isNaN(t.getTime())) return "";
        const m = Math.floor((Date.now() - t.getTime()) / 60000);
        if (m < 1) return "şimdi";
        if (m < 60) return m + " dk önce";
        return Qt.formatTime(t, "HH:mm");
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? card.closeClicked() : card.clicked()
    }

    RowLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 11 }
        spacing: 10

        // icon (image with small app badge, or app icon)
        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            Kirigami.Icon {
                id: mainIcon
                anchors.fill: parent
                source: card.hasImage ? card.icon : (card.icon || card.appIcon || "preferences-desktop-notification-bell")
                fallback: card.appIcon || "preferences-desktop-notification-bell"
                roundToIconSize: !card.hasImage
            }
            Kirigami.Icon {
                visible: card.hasImage && card.appIcon !== ""
                width: 18; height: 18
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: -4; bottomMargin: -4 }
                source: card.appIcon
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: card.summary || card.applicationName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: "white"
                    font.family: card.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: card.isJob ? (card.percentage + "%") : card.ago()
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: card.font
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: card.isJob ? 2 : 4
                color: Qt.rgba(1, 1, 1, 0.86)
                linkColor: "#64b5ff"
                font.family: card.font
                font.pixelSize: 13
                lineHeight: 1.05
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // job progress
            RowLayout {
                visible: card.isJob
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 5; radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.18)
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(100, card.percentage)) / 100
                        color: "#0a84ff"
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }
                Repeater {
                    model: [
                        { show: card.suspendable && card.jobState !== NotificationManager.Notifications.JobStateSuspended, icon: "media-playback-pause", act: "suspend" },
                        { show: card.suspendable && card.jobState === NotificationManager.Notifications.JobStateSuspended, icon: "media-playback-start", act: "resume" },
                        { show: card.killable, icon: "media-playback-stop", act: "kill" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        visible: modelData.show
                        width: 22; height: 22; radius: 11
                        color: jm.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.14)
                        Kirigami.Icon { anchors.centerIn: parent; width: 12; height: 12; source: modelData.icon; isMask: true; color: "white" }
                        MouseArea {
                            id: jm; anchors.fill: parent; hoverEnabled: true
                            onClicked: modelData.act === "kill" ? card.killClicked() : modelData.act === "suspend" ? card.suspendClicked() : card.resumeClicked()
                        }
                    }
                }
            }

            Text {
                visible: card.isJob && text !== ""
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: card.jobText
                color: Qt.rgba(1, 1, 1, 0.6)
                font.family: card.font
                font.pixelSize: 11
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }

            // action buttons
            Flow {
                visible: !card.isJob && card.actionLabels.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 6
                Repeater {
                    model: card.isJob ? 0 : card.actionLabels.length
                    delegate: Rectangle {
                        required property int index
                        height: 26
                        width: Math.min(card.width - 70, lbl.implicitWidth + 24)
                        radius: 13
                        color: am.pressed ? Qt.rgba(1, 1, 1, 0.30) : am.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.15)
                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 16)
                            elide: Text.ElideRight
                            text: card.actionLabels[index]
                            color: "white"
                            font.family: card.font
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: card.actionClicked(card.actionNames[index]) }
                    }
                }
            }
            Item { Layout.preferredHeight: 0 }
        }
    }

    // close button (top-left, on hover) like macOS
    Rectangle {
        id: closeBtn
        visible: card.closable
        opacity: card.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        x: -2; y: -2
        width: 20; height: 20; radius: 10
        color: closeMouse.containsMouse ? Qt.rgba(0.35, 0.35, 0.38, 1) : Qt.rgba(0.24, 0.24, 0.27, 1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Canvas {
            anchors.centerIn: parent
            width: 8; height: 8
            onPaint: {
                const c = getContext("2d");
                c.clearRect(0, 0, width, height);
                c.strokeStyle = "white"; c.lineWidth = 1.6; c.lineCap = "round";
                c.beginPath(); c.moveTo(1, 1); c.lineTo(7, 7); c.moveTo(7, 1); c.lineTo(1, 7); c.stroke();
            }
        }
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.closeClicked() }
    }
}
