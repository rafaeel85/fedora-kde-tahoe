/*
 *  SPDX-FileCopyrightText: 2021 Devin Lin <espidev@gmail.com>
 *  SPDX-License-Identifier: LGPL-2.0-or-later
 *
 *  Local macOS Tahoe patch: tabs drawn as segments of a segmented control
 *  (text only, selected segment = raised translucent pill).
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami.templates as KT
import org.kde.kirigami.platform as Platform
import org.kde.kirigami.primitives as Primitives

KT.NavigationTabButton {
    id: control

    readonly property color __foregroundColor: Platform.Theme.textColor
    readonly property color __highlightForegroundColor: Platform.Theme.textColor
    readonly property color __pressedColor: Qt.alpha(Platform.Theme.textColor, 0.26)
    readonly property color __hoverSelectColor: Qt.alpha(Platform.Theme.textColor, 0.08)
    readonly property color __borderColor: Platform.Theme.highlightColor
    readonly property color __selectedOutlineBorderColor: Qt.alpha(__borderColor, 0.5)
    readonly property real __verticalMargins: 0
    // footer bars (mobile bottom navigation) keep their icons
    readonly property bool __segment: !(parent && parent.parent && parent.parent.position === QQC2.ToolBar.Footer)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    display: __segment && text.length > 0 ? T.AbstractButton.TextOnly : T.AbstractButton.TextUnderIcon

    Platform.Theme.colorSet: Platform.Theme.Window
    Platform.Theme.inherit: false

    hoverEnabled: true

    topPadding: __segment ? 5 : Platform.Units.smallSpacing
    bottomPadding: __segment ? 5 : Platform.Units.smallSpacing
    leftPadding: __segment ? Platform.Units.largeSpacing + 4 : Platform.Units.smallSpacing
    rightPadding: __segment ? Platform.Units.largeSpacing + 4 : Platform.Units.smallSpacing
    spacing: Platform.Units.smallSpacing

    leftInset: __segment ? 2 : Platform.Units.smallSpacing
    rightInset: __segment ? 2 : Platform.Units.smallSpacing
    topInset: __segment ? 2 : Platform.Units.smallSpacing
    bottomInset: __segment ? 2 : Platform.Units.smallSpacing

    icon.height: Platform.Units.iconSizes.smallMedium
    icon.width: Platform.Units.iconSizes.smallMedium
    icon.color: __foregroundColor

    background: Item {
        Platform.Theme.colorSet: Platform.Theme.Button
        Platform.Theme.inherit: false
        implicitHeight: control.__segment ? 0 : Platform.Units.gridUnit * 3

        Rectangle {   // keyboard focus ring
            anchors.fill: seg
            anchors.margins: -2
            radius: seg.radius + 2
            color: "transparent"
            border.color: control.visualFocus ? control.__selectedOutlineBorderColor : "transparent"
            border.width: 2
        }
        Rectangle {
            id: seg
            anchors.fill: parent
            radius: control.__segment ? height / 2 : Platform.Units.cornerRadius
            color: control.down ? control.__pressedColor
                 : control.checked ? Qt.alpha(Platform.Theme.textColor, 0.20)
                 : control.hovered ? control.__hoverSelectColor : "transparent"
            // Tahoe glass rim on the selected segment
            border.width: control.checked ? 1 : 0
            border.color: Qt.alpha(Platform.Theme.textColor, 0.12)
            Behavior on color { ColorAnimation { duration: Platform.Units.shortDuration } }
        }
    }

    contentItem: GridLayout {
        columnSpacing: 0
        rowSpacing: control.spacing
        columns: 1

        Primitives.Icon {
            id: icon
            source: control.icon.name || control.icon.source
            visible: (control.icon.name.length > 0 || control.icon.source.toString().length > 0) && control.display !== T.AbstractButton.TextOnly
            color: control.icon.color
            Layout.alignment: Qt.AlignHCenter | (label.visible ? Qt.AlignBottom : Qt.AlignVCenter)
            implicitHeight: source ? control.icon.height : 0
            implicitWidth: source ? control.icon.width : 0
        }
        QQC2.Label {
            id: label
            text: control.Primitives.MnemonicData.richTextLabel
            Accessible.name: control.Primitives.MnemonicData.plainTextLabel
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: control.display !== T.AbstractButton.IconOnly
            wrapMode: control.__segment ? Text.NoWrap : Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: control.__segment ? 1 : 2
            color: control.__foregroundColor
            font.weight: control.checked && control.__segment ? Font.DemiBold : Font.Normal
            Layout.alignment: icon.visible ? Qt.AlignHCenter | Qt.AlignTop : Qt.AlignCenter
            Layout.fillWidth: true
            Accessible.ignored: true
        }
    }
}
