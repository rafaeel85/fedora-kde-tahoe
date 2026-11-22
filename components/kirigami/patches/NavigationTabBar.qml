/*
 *  SPDX-FileCopyrightText: 2021 Devin Lin <espidev@gmail.com>
 *  SPDX-License-Identifier: LGPL-2.0-or-later
 *
 *  Local macOS Tahoe patch: header tab bars become a compact, centred
 *  segmented control on a translucent capsule track.
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Templates as T
import org.kde.kirigami.templates as KT
import org.kde.kirigami.platform as Platform

KT.NavigationTabBar {
    id: root

    readonly property bool __segmented: root.position !== QQC.ToolBar.Footer

    // equal-width segments sized to the widest label (like NSSegmentedControl)
    maximumContentWidth: {
        if (!__segmented) {
            return Platform.Units.gridUnit * 5 * Math.max(visibleActions.length, 5);
        }
        let widest = Platform.Units.gridUnit * 4;
        for (const b of tabGroup.buttons) {
            if (b.visible) widest = Math.max(widest, b.implicitWidth);
        }
        return Math.min(widest, Platform.Units.gridUnit * 12) * Math.max(1, visibleActions.length);
    }

    spacing: 0
    topPadding: __segmented ? Platform.Units.smallSpacing * 2 : ((root.position === QQC.ToolBar.Header && parent) ? parent.SafeArea.margins.top : 0)
    bottomPadding: __segmented ? Platform.Units.smallSpacing * 2 : ((root.position === QQC.ToolBar.Footer && parent) ? parent.SafeArea.margins.bottom : 0)
    leftPadding: Math.floor(Math.max(0, width - root.maximumContentWidth) / 2) + (parent ? parent.SafeArea.margins.left : 0)
    rightPadding: Math.floor(Math.max(0, width - root.maximumContentWidth) / 2) + (parent ? parent.SafeArea.margins.right : 0)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    background: Item {
        Rectangle {   // segmented-control track
            visible: root.__segmented
            x: root.leftPadding
            y: root.topPadding
            width: root.availableWidth
            height: root.availableHeight
            radius: height / 2
            color: Qt.alpha(Platform.Theme.textColor, 0.07)
            border.width: 1
            border.color: Qt.alpha(Platform.Theme.textColor, 0.06)
        }
    }
}
