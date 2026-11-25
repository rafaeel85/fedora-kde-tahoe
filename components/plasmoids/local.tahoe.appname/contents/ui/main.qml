import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC
import org.kde.plasma.plasma5support as Support
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property string qdbus: "@QTBINS@/qdbus "
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
    Component.onCompleted: { refresh(); clearBarBackground(); pollTint(); }

    // ---- macOS Tahoe adaptive menu bar: black text over a light wallpaper, white over a dark one.
    // tahoe-bartint (~/.local/share/tahoe-bartint) measures the wallpaper under the bar.
    // The colour is set on the panel's top item so every applet in the bar (incl. KDE's appmenu
    // and our extras, which use Kirigami.Theme.textColor) follows it.
    property string tint: ""
    // restyle right after the active app changes (appmenu rebuilds its delegates)
    onAppNameChanged: { restyle.n = 0; restyle.restart(); Qt.callLater(styleBar) }
    Timer { id: restyle; property int n: 0; interval: 40; repeat: true; onTriggered: { root.styleBar(); if (++n >= 8) stop() } }
    readonly property color barText: tint === "dark" ? "#000000" : "#ffffff"   // "" = not known yet -> leave the theme alone
    function pollTint() {
        DBus.SessionBus.asyncCall({ service: "local.TahoeBar", path: "/Bar", iface: "local.TahoeBar", member: "tint", arguments: [] },
            v => { const t = String(((v && v.value !== undefined) ? v.value : v) || "light"); if (t !== root.tint) root.tint = t; root.styleBar() },
            () => root.styleBar())
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.pollTint() }
    function styleBar() {
        // only the panel window's root item (before the applet is placed in the panel the
        // parent chain ends at the applet itself, and a theme set there would stick)
        const top = root.Window.window ? root.Window.window.contentItem : null
        if (!top || !Plasmoid.containment) return
        const th = top.Kirigami.Theme
        if (root.tint !== "") {
            if (th.inherit) th.inherit = false
            if (!Qt.colorEqual(th.textColor, root.barText)) th.textColor = root.barText
        }
        // one menu-bar font everywhere (same as the clock/extras: Inter 13 px Medium; app name Bold),
        // applied to our ToolButtons AND KDE appmenu's MenuDelegates (they used Inter 10 pt Regular)
        const walk = it => {
            const kids = it.children || []
            for (let i = 0; i < kids.length; ++i) {
                const k = kids[i]
                const ks = String(k)
                if ((ks.indexOf("ToolButton") >= 0 || ks.indexOf("MenuDelegate") >= 0) && k.font !== undefined && k.text !== undefined) {
                    // same title spacing for our Finder menus and KDE's appmenu (9 px each side ≈ macOS)
                    if (k.leftPadding !== 9) k.leftPadding = 9
                    const rp = (k.tahoeBold === true && !root.onDesktop) ? 5 : 9
                    if (k.rightPadding !== rp) k.rightPadding = rp
                    const w = (k.tahoeBold === true) ? Font.Bold : Font.Medium
                    if (k.font.family !== "Inter" || k.font.pixelSize !== 13 || k.font.weight !== w)
                        k.font = Qt.font({ family: "Inter", pixelSize: 13, weight: w })
                }
                walk(k)
            }
        }
        walk(top)
    }

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
            property bool tahoeBold: true
            text: root.onDesktop ? "Finder" : root.appName
            font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Bold
            topPadding: 0; bottomPadding: 4   // PC.ToolButton text sat 2 px below the clock/appmenu baseline
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
                font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium
                topPadding: 0; bottomPadding: 4
                focusPolicy: Qt.NoFocus
                onClicked: { root.openMenu(modelData, this); Qt.callLater(root.poll); pollTimer.restart() }
                onHoveredChanged: { root.barHover(hovered); if (hovered) root.hoverSwitch(modelData, this) }
                down: root.openName === "f-" + modelData
            }
        }
    }
}
