import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC
import org.kde.plasma.plasma5support as Support
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property string qdbus: "/usr/lib64/qt6/bin/qdbus "
    property string appName: ""
    readonly property bool onDesktop: appName === ""

    // Desktop ("Finder") menus are drawn by the Tahoe menus window (~/.local/share/tahoe-menus, kind "f-<Title>")
    readonly property var menuOrder: ["Dosya", "Düzen", "Görüntü", "Git", "Pencere", "Yardım"]

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: true
        filterByActivity: true
        onActiveTaskChanged: root.refresh()
        onDataChanged: root.refresh()
        onCountChanged: root.refresh()
    }

    function refresh() {
        const idx = tasksModel.activeTask;
        if (!idx || !idx.valid) { appName = ""; return; }
        let n = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || "";
        if (!n) n = tasksModel.data(idx, Qt.DisplayRole) || "";
        if (n === "plasmashell") n = "";
        appName = n;
    }
    // Tahoe menu bar has no background/blur at all: drop the panel containment's background
    // (Panel.qml + PanelView then neither draw panel-background.svgz nor request KWin blur).
    function clearBarBackground() {
        const c = Plasmoid.containment;
        if (c && c.location === PlasmaCore.Types.TopEdge && c.backgroundHints !== PlasmaCore.Types.NoBackground)
            c.backgroundHints = PlasmaCore.Types.NoBackground;
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: root.clearBarBackground() }
    Component.onCompleted: { refresh(); clearBarBackground(); }

    Support.DataSource {
        id: runner; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName); }
    }
    function openMenu(name, button) {
        const x = Math.round(button.mapToGlobal(0, 0).x)
        runner.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus toggle si 'f-" + name + "' " + x + " #" + Date.now())
    }

    // macOS: while any menu-bar menu is open, hovering another title switches to its menu
    property string openName: ""
    function poll() {
        DBus.SessionBus.asyncCall({ service: "local.TahoeMenus", path: "/Menus", iface: "local.TahoeMenus", member: "current", arguments: [] },
                                  v => { const s = (v && v.value !== undefined) ? v.value : v; root.openName = String(s || ""); if (root.openName.indexOf("f-") !== 0) pollTimer.stop() },
                                  () => { root.openName = ""; pollTimer.stop() })
    }
    Timer { id: pollTimer; interval: 300; repeat: true; onTriggered: root.poll() }
    function barHover(inside) {
        runner.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus barHover bx " + inside + " " + Date.now())
    }
    function hoverSwitch(name, button) {
        const x = Math.round(button.mapToGlobal(0, 0).x)
        DBus.SessionBus.asyncCall({ service: "local.TahoeMenus", path: "/Menus", iface: "local.TahoeMenus", member: "current", arguments: [] },
            v => {
                const s = String(((v && v.value !== undefined) ? v.value : v) || "")
                if (s !== "" && s !== "f-" + name) {
                    runner.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus display si 'f-" + name + "' " + x + " #" + Date.now())
                    root.openName = "f-" + name; pollTimer.restart()
                }
            }, () => {})
    }

    fullRepresentation: RowLayout {
        spacing: 0
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth

        PC.ToolButton {
            id: nameButton
            text: root.onDesktop ? "Finder" : root.appName
            font.weight: Font.Bold
            focusPolicy: Qt.NoFocus
            onClicked: if (root.onDesktop) { root.openMenu("Finder", nameButton); Qt.callLater(root.poll); pollTimer.restart() }
            onHoveredChanged: { root.barHover(hovered); if (hovered && root.onDesktop) root.hoverSwitch("Finder", nameButton) }
            down: root.openName === "f-Finder"
        }
        Repeater {
            model: root.onDesktop ? root.menuOrder : []
            PC.ToolButton {
                required property string modelData
                text: modelData
                focusPolicy: Qt.NoFocus
                onClicked: { root.openMenu(modelData, this); Qt.callLater(root.poll); pollTimer.restart() }
                onHoveredChanged: { root.barHover(hovered); if (hovered) root.hoverSwitch(modelData, this) }
                down: root.openName === "f-" + modelData
            }
        }
    }
}
