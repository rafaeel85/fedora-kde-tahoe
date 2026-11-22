/*
    Tahoe: macOS-style Dock badge (red pill, white bold number, top-right of the icon).
    Original: upstream WaveTask package/contents/ui/TaskBadgeOverlay.qml (KDE task manager)
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid

Item {
    id: root

    // Visual icon square inside the 66px box: drawn bottom-anchored with a small margin;
    // MacTahoe icons keep ~11% transparent padding around the squircle.
    readonly property real iconSide: width
    readonly property real pad: Math.round(iconSide * 0.11)
    readonly property real iconTop: height - iconSide - (icon.anchors.bottomMargin || 0)

    readonly property int count: task.smartLauncherItem ? task.smartLauncherItem.count : 0

    Rectangle {
        id: pill
        visible: task.smartLauncherItem && task.smartLauncherItem.countVisible

        height: Math.round(root.iconSide * 0.34)
        width: Math.max(height, Math.round(label.implicitWidth + height * 0.62))
        radius: height / 2
        antialiasing: true

        color: "#ff3b30"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.12)

        // centre the pill's right edge just outside the squircle's top-right corner
        x: Math.round(root.iconSide - root.pad + height * 0.30 - width)
        y: Math.round(root.iconTop + root.pad - height * 0.30)

        Text {
            id: label
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 0
            color: "white"
            font.pixelSize: Math.round(pill.height * 0.62)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
            text: root.count < 0 ? "—"
                : root.count > 999 ? "999+"
                : root.count.toString()
            textFormat: Text.PlainText
        }
    }
}
