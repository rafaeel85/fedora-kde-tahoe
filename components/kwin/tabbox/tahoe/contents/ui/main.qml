// macOS Tahoe style Cmd+Tab switcher: big icons in a glass bar, name under the selected one
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: (instantiator.object && instantiator.object.currentIndex !== undefined) ? instantiator.object.currentIndex : currentIndex

    Instantiator {
        id: instantiator
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            id: dlg
            property alias currentIndex: icons.currentIndex
            location: PlasmaCore.Types.Floating
            visible: tabBox.visible
            flags: Qt.ToolTip | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + Math.round((tabBox.screenGeometry.width - width) / 2)
            y: tabBox.screenGeometry.y + Math.round((tabBox.screenGeometry.height - height) / 2)

            mainItem: Item {
                id: main
                readonly property int iconSize: tabBox.screenGeometry.width >= 1800 ? 96 : 80
                readonly property int cell: iconSize + 16
                readonly property int maxPerRow: Math.max(1, Math.floor(tabBox.screenGeometry.width * 0.9 / cell))
                readonly property int perRow: Math.max(1, Math.min(icons.count, maxPerRow))
                width: perRow * cell + 12
                height: Math.ceil(Math.max(1, icons.count) / maxPerRow) * (cell + 26) + 10

                GridView {
                    id: icons
                    anchors.fill: parent
                    anchors.margins: 6
                    cellWidth: main.cell
                    cellHeight: main.cell + 26
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    focus: true
                    interactive: false
                    keyNavigationWraps: true
                    highlightMoveDuration: 0

                    highlight: Item {
                        Rectangle {
                            x: 0; y: 0
                            width: main.cell; height: main.cell
                            radius: 18
                            color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                        }
                    }

                    delegate: Item {
                        id: del
                        required property int index
                        required property var model
                        width: main.cell
                        height: main.cell + 26
                        property string caption: model.caption

                        Kirigami.Icon {
                            x: 8; y: 8
                            width: main.iconSize; height: main.iconSize
                            source: del.model.icon
                            scale: tap.pressed ? 0.94 : 1
                        }
                        Text {
                            visible: del.index === icons.currentIndex
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: main.cell + 4
                            width: Math.max(main.cell, implicitWidth)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: {
                                // app name ("Konsole" from "~ : claude — Konsole")
                                const c = del.caption || "";
                                const parts = c.split(/ [—–-] /);
                                return parts.length > 1 ? parts[parts.length - 1] : c;
                            }
                            color: "white"
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        TapHandler {
                            id: tap
                            onTapped: {
                                if (del.index === icons.currentIndex) icons.model.activate(del.index);
                                else icons.currentIndex = del.index;
                            }
                        }
                    }
                }

                Connections {
                    target: tabBox
                    function onCurrentIndexChanged() { icons.currentIndex = tabBox.currentIndex; }
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) icons.moveCurrentIndexLeft();
                    else if (event.key === Qt.Key_Right) icons.moveCurrentIndexRight();
                    else if (event.key === Qt.Key_Up) icons.moveCurrentIndexUp();
                    else if (event.key === Qt.Key_Down) icons.moveCurrentIndexDown();
                }
            }
            onSceneGraphError: () => {}
        }
    }
}
