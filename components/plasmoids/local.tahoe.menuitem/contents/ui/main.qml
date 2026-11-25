import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.workspace.keyboardlayout as KB
import org.kde.kirigami as Kirigami

// One macOS Tahoe menu-bar extra. kind = apple | wifi | battery | clock | weather | input.
// Clicking toggles the matching menu of the Tahoe menus window (~/.local/share/tahoe-menus).
PlasmoidItem {
    id: root
    readonly property string kind: Plasmoid.configuration.kind
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ({ apple: "", wifi: "Wi-Fi", battery: "Pil", clock: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat)), weather: wxPlace, input: kbName })[kind] || ""
    toolTipSubText: ({ wifi: ci.connectionTooltipIcon !== "" ? wifiSsid : "", battery: battPercent + "%" + (onAC ? " · Güç adaptörü" : ""), weather: wxTemp })[kind] || ""

    // menu-bar foreground follows the bar tint (set panel-wide by local.tahoe.appname)
    readonly property bool darkText: Kirigami.Theme.textColor.hslLightness < 0.5
    readonly property color fg: darkText ? "#000000" : "#ffffff"
    readonly property string fgHex: darkText ? "#000" : "#fff"
    function fgA(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }

    // ---------------------------------------------------------------- open/close
    P5.DataSource {
        id: exec; engine: "executable"; connectedSources: []
        onNewData: (src, data) => disconnectSource(src)
    }
    property bool open: false
    function poll() {
        DBus.SessionBus.asyncCall({ service: "local.TahoeMenus", path: "/Menus", iface: "local.TahoeMenus", member: "current", arguments: [] },
                                  v => { const s = (v && v.value !== undefined) ? v.value : v; root.open = s === root.kind; if (!root.open) pollTimer.stop() },
                                  () => { root.open = false; pollTimer.stop() })
    }
    Timer { id: pollTimer; interval: 300; repeat: true; onTriggered: root.poll() }
    function toggle(item) {
        const x = Math.round(item.mapToGlobal(0, 0).x)
        exec.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus toggle si " + kind + " " + x + " #" + Date.now())
        Qt.callLater(poll); pollTimer.restart()
    }

    // macOS: while any menu-bar menu is open, hovering this item switches to its menu
    function hoverSwitch(item) {
        const x = Math.round(item.mapToGlobal(0, 0).x)
        DBus.SessionBus.asyncCall({ service: "local.TahoeMenus", path: "/Menus", iface: "local.TahoeMenus", member: "current", arguments: [] },
            v => {
                const s = String(((v && v.value !== undefined) ? v.value : v) || "")
                if (s !== "" && s !== root.kind) {
                    exec.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus display si " + kind + " " + x + " #" + Date.now())
                    root.open = true; pollTimer.restart()
                }
            }, () => {})
    }

    // ---------------------------------------------------------------- data
    property date now: new Date()
    Timer {
        running: root.kind === "clock"; repeat: true; triggeredOnStart: true
        interval: 1000 * (60 - new Date().getSeconds()) || 60000
        onTriggered: { root.now = new Date(); interval = 1000 * (60 - root.now.getSeconds()) }
    }

    PlasmaNM.ConnectionIcon { id: ci }
    PlasmaNM.WirelessStatus { id: wls }
    readonly property string wifiSsid: wls.wifiSSID

    P5.DataSource {
        id: pm; engine: "powermanagement"
        connectedSources: root.kind === "battery" ? ["Battery", "AC Adapter"] : []
    }
    readonly property int battPercent: (pm.data["Battery"] && pm.data["Battery"]["Percent"]) || 0
    readonly property bool onAC: !!(pm.data["AC Adapter"] && pm.data["AC Adapter"]["Plugged in"])
    readonly property bool charging: !!(pm.data["Battery"] && pm.data["Battery"]["State"] === "Charging")

    P5.DataSource {
        id: wx; engine: "weather"; interval: 30 * 60 * 1000
        connectedSources: root.kind === "weather" ? [Plasmoid.configuration.weatherSource] : []
    }
    readonly property var wd: wx.data[Plasmoid.configuration.weatherSource] || ({})
    readonly property string wxTemp: wd["Temperature"] !== undefined ? Math.round(wd["Temperature"]) + "°" : ""
    readonly property string wxPlace: String(wd["Place"] || "Hava Durumu").split(",")[0]
    readonly property string wxIcon: {
        const c = wd["Condition Icon"]
        if (c && c !== "weather-none-available") return c
        const d = String(wd["Short Forecast Day 0"] || "").split("|")
        return d.length > 1 ? d[1] : ""
    }

    KB.KeyboardLayout { id: kb }
    readonly property var kbCur: root.kind === "input" && kb.layoutsList.length > kb.layout ? kb.layoutsList[kb.layout] : null
    readonly property string kbShort: kbCur ? String(kbCur.displayName || kbCur.shortName).toUpperCase() : ""
    readonly property string kbName: kbCur ? kbCur.longName : ""

    // ---------------------------------------------------------------- glyphs
    function svg(body) {
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">' + body + '</svg>')
    }
    readonly property int wifiLevel: {
        const m = /wireless[^0-9]*(\d+)/.exec(ci.connectionIcon)
        if (!m) return -1
        const v = parseInt(m[1]); return v >= 60 ? 3 : (v >= 40 ? 2 : 1)
    }
    // SF Symbols "wifi": rounded wedge + two thick arcs (viewBox 21.2 x 15.6)
    readonly property string wifiGlyph: {
        const icon = String(ci.connectionIcon)
        if (/wired/.test(icon))   // ethernet: <··>
            return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="47" viewBox="-2.5 -5 24 24"><g fill="none" stroke="' + root.fgHex + '" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7l-5 5 5 5M17 7l5 5-5 5"/></g><g fill="' + root.fgHex + '"><circle cx="8.5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="15.5" cy="12" r="1.4"/></g></svg>')
        const lv = wifiLevel
        const o = i => (lv < 0 ? 0.3 : (i <= lv ? 1 : 0.3))
        let s = '<g><path d="M9.500 12.900L6.954 10.354A3.6 3.6 0 0 1 12.046 10.354Z" fill="' + root.fgHex + '" stroke="' + root.fgHex + '" stroke-width="1" stroke-linejoin="round" opacity="' + o(1) + '"/><path d="M3.843 7.243A8.0 8.0 0 0 1 15.157 7.243A1.25 1.25 0 0 1 13.389 9.011A5.5 5.5 0 0 0 5.611 9.011A1.25 1.25 0 0 1 3.843 7.243Z" fill="' + root.fgHex + '" opacity="' + o(2) + '"/><path d="M0.732 4.132A12.4 12.4 0 0 1 18.268 4.132A1.25 1.25 0 0 1 16.500 5.900A9.9 9.9 0 0 0 2.500 5.900A1.25 1.25 0 0 1 0.732 4.132Z" fill="' + root.fgHex + '" opacity="' + o(3) + '"/></g>'
        if (lv < 0 && !ci.connecting) s += '<path d="M2.5 1l16.5 14" stroke="' + root.fgHex + '" stroke-width="1.9" stroke-linecap="round"/>'
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="19" height="14" viewBox="0 0 19 14">' + s + '</svg>')
    }
    function weatherGlyph(icon) {
        const n = String(icon || ""), W = root.fgHex
        const cloud = '<path fill="' + W + '" d="M6.8 19.5h10.6a4.3 4.3 0 0 0 .5-8.57A6.2 6.2 0 0 0 6.1 9.9 4.8 4.8 0 0 0 6.8 19.5z"/>'
        const up = c => '<g transform="translate(0 -3.2)">' + c + '</g>'
        const sun = (cx, cy, r, s) => '<circle cx="' + cx + '" cy="' + cy + '" r="' + r + '" fill="' + W + '"/><g stroke="' + W + '" stroke-width="' + s + '" stroke-linecap="round" transform="translate(' + cx + ' ' + cy + ')">'
            + '<path d="M0 -' + (r + 2.3) + 'v-1.9M0 ' + (r + 2.3) + 'v1.9M-' + (r + 2.3) + ' 0h-1.9M' + (r + 2.3) + ' 0h1.9"/>'
            + '<path transform="rotate(45)" d="M0 -' + (r + 2.3) + 'v-1.9M0 ' + (r + 2.3) + 'v1.9M-' + (r + 2.3) + ' 0h-1.9M' + (r + 2.3) + ' 0h1.9"/></g>'
        // cut-out ring around the cloud so sun/moon and cloud stay readable in one colour
        const cutCloud = '<g transform="translate(2.6 2.2) scale(0.88)"><path fill="none" stroke="#000" stroke-width="3.2" d="M6.8 19.5h10.6a4.3 4.3 0 0 0 .5-8.57A6.2 6.2 0 0 0 6.1 9.9 4.8 4.8 0 0 0 6.8 19.5z"/></g>'
        const masked = (back) => '<defs><mask id="m"><rect width="24" height="24" fill="#fff"/>' + cutCloud.replace(/#000/, "#000") + '</mask></defs><g mask="url(#m)">' + back + '</g><g transform="translate(2.6 2.2) scale(0.88)">' + cloud + '</g>'
        if (/storm|thunder/.test(n)) return svg(up(cloud) + '<path fill="' + W + '" d="M12.8 15.2l-3.4 4.6h2.6l-1.2 3.4 4.2-5h-2.6l1.6-3z"/>')
        if (/snow|hail|freezing/.test(n)) return svg(up(cloud) + '<g fill="' + W + '"><circle cx="8" cy="19.8" r="1.2"/><circle cx="12" cy="21.2" r="1.2"/><circle cx="16" cy="19.8" r="1.2"/></g>')
        if (/shower|rain/.test(n)) return svg(up(cloud) + '<g stroke="' + W + '" stroke-width="1.9" stroke-linecap="round"><path d="M8.2 18.6l-1.1 2.8M12.2 18.6l-1.1 2.8M16.2 18.6l-1.1 2.8"/></g>')
        if (/mist|fog|haze/.test(n)) return svg(up(cloud) + '<g stroke="' + W + '" stroke-width="1.8" stroke-linecap="round"><path d="M5 19.4h14M7.5 22h9"/></g>')
        if (/overcast/.test(n)) return svg(cloud)
        if (/clouds-night/.test(n)) return svg(masked('<path fill="' + W + '" d="M10 2.5a6.2 6.2 0 1 0 4.4 10A5.2 5.2 0 0 1 10 2.5z"/>'))
        if (/clouds/.test(n)) return svg(masked(sun(8.6, 8.4, 3.2, 1.6)))
        if (/clear-night/.test(n)) return svg('<path fill="' + W + '" d="M14.8 3.2a8.8 8.8 0 1 0 6 14.2A7.4 7.4 0 0 1 14.8 3.2z"/>')
        if (/clear/.test(n)) return svg(sun(12, 12, 4.2, 1.9))
        return svg(cloud)
    }

    // ---------------------------------------------------------------- menu-bar item
    fullRepresentation: MouseArea {
        id: btn
        readonly property real pad: (root.kind === "clock" ? 16 : (root.kind === "apple" ? 22 : 14)) / 2 + (Math.round(body.width) % 2) / 2
        Layout.preferredWidth: body.width + 2 * pad
        Layout.minimumWidth: body.width + 2 * pad
        Layout.maximumWidth: body.width + 2 * pad
        Layout.fillHeight: true
        hoverEnabled: true
        onContainsMouseChanged: {
            exec.connectSource("busctl --user call local.TahoeMenus /Menus local.TahoeMenus barHover bx " + containsMouse + " " + Date.now())
            if (containsMouse) root.hoverSwitch(btn)
        }
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton && root.kind === "input") kb.switchToNextLayout()
            else root.toggle(btn)
        }
        onWheel: w => { if (root.kind === "input") (w.angleDelta.y > 0 ? kb.switchToPreviousLayout() : kb.switchToNextLayout()) }

        Rectangle {   // Tahoe highlights the open menu's item with a pill
            anchors.centerIn: parent
            width: parent.width; height: Math.min(parent.height - 6, 24)
            radius: height / 2
            color: root.open ? (root.darkText ? "#26000000" : "#40ffffff") : (btn.containsMouse ? (root.darkText ? "#14000000" : "#1fffffff") : "transparent")
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Item {
            id: body
            anchors.centerIn: parent
            width: loader.item ? loader.item.width : 16
            height: parent.height
            Loader {
                id: loader
                // whole-pixel position keeps the 1x glyphs crisp
                x: 0; y: Math.round((body.height - (item ? item.height : 0)) / 2)
                sourceComponent: ({ apple: appleC, wifi: wifiC, battery: batteryC, clock: clockC, weather: weatherC, input: inputC })[root.kind] || clockC
            }
        }
    }

    Component {
        id: appleC
        // Apple logo (same shape as the old kickerdash icon), drawn at exact 1x pixel size
        Image {
            width: 16; height: 16; sourceSize: Qt.size(16, 16)
            source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="' + root.fgHex + '" d="M11.881 8.5c-.02-2 1.653-3 1.727-3-.94-1.4-2.404-1.6-2.925-1.6-1.246-.2-2.432.7-3.064.7-.63 0-1.606-.7-2.64-.7-1.358 0-2.61.8-3.31 2C.26 8.4 1.31 12 2.684 14c.673.9 1.474 2 2.526 2 1.013 0 1.396-.7 2.621-.7s1.57.7 2.642.7c1.09 0 1.781-1 2.448-2 .771-1.1 1.089-2.2 1.108-2.3-.024 0-2.126-.8-2.147-3.2zM9.866 2.6c.559-.7.936-1.7.833-2.6-.804 0-1.78.5-2.357 1.2-.517.6-.97 1.6-.85 2.5.899.1 1.815-.5 2.374-1.1z"/></svg>')
        }
    }
    Component {
        id: wifiC
        Image { width: 19; height: 14; sourceSize: Qt.size(19, 14); source: root.wifiGlyph }
    }
    Component {
        id: clockC
        Text {
            text: root.now.toLocaleString(Qt.locale(), "ddd d MMM") + "   " + Qt.formatTime(root.now, "HH:mm")
            color: root.fg
            font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium
        }
    }
    Component {
        id: weatherC
        Row {
            spacing: 4
            Image { anchors.verticalCenter: parent.verticalCenter; width: 17; height: 17; sourceSize: Qt.size(48, 48); source: root.weatherGlyph(root.wxIcon) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.wxTemp; color: root.fg; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium }
        }
    }
    Component {
        id: inputC
        Rectangle {
            height: 15; width: Math.max(20, lbl.implicitWidth + 7); radius: 4
            color: "transparent"; border.width: 1; border.color: root.fg
            Text {
                id: lbl; anchors.centerIn: parent; anchors.verticalCenterOffset: 0.5
                text: root.kbShort; color: root.fg
                font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold
            }
        }
    }
    Component {
        id: batteryC
        // macOS Tahoe battery with the percentage drawn inside: translucent shell, white level,
        // number knocked out of the white part (dark) and white over the empty part
        Item {
            id: bat
            readonly property bool pct: Plasmoid.configuration.showPercent
            readonly property bool plug: root.charging || root.onAC
            readonly property real level: Math.min(100, Math.max(0, root.battPercent)) / 100
            readonly property color fillColor: root.battPercent <= 10 && !root.onAC ? "#ff453a" : (root.charging ? "#30d158" : root.fg)
            width: shell.width + 3; height: 14
            Rectangle {   // rounded mask for the shell contents
                id: shellMask
                width: shell.width; height: shell.height; radius: shell.radius
                layer.enabled: true; visible: false
            }
            Rectangle {
                id: shell
                width: bat.pct ? 27 : 24; height: bat.pct ? 13 : 12.5
                radius: 4.2
                anchors.verticalCenter: parent.verticalCenter
                color: bat.pct ? root.fgA(0.25) : "transparent"
                border.width: bat.pct ? 0 : 1; border.color: root.fgA(0.55)
                layer.enabled: bat.pct
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true; maskSource: shellMask
                    maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                }
                Item {   // level
                    id: lvl
                    x: bat.pct ? 0 : 2; y: bat.pct ? 0 : 2
                    height: parent.height - (bat.pct ? 0 : 4)
                    width: Math.max(bat.pct ? 0 : 2.5, (parent.width - (bat.pct ? 0 : 4)) * bat.level)
                    clip: bat.pct
                    Rectangle { width: bat.pct ? shell.width : parent.width; height: parent.height; radius: bat.pct ? 0 : 2.2; color: bat.fillColor }
                    Row {   // dark copy of the label, only visible over the level
                        x: (shell.width - width) / 2 - lvl.x; y: (shell.height - height) / 2 - lvl.y
                        visible: bat.pct; spacing: 0
                        Image { visible: false; width: 7; height: 9; anchors.verticalCenter: parent.verticalCenter; sourceSize: Qt.size(28, 36); source: root.svg('<path fill="#1c1c3c" d="M13.5 2L5 13.5h6L9.8 22 19 10h-6.2z"/>') }
                        Text { text: root.battPercent; color: "#e61c1c3c"; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
                Item {   // white copy of the label over the empty part
                    x: lvl.x + lvl.width; width: parent.width - x; height: parent.height
                    clip: true; visible: bat.pct
                    Row {
                        x: (shell.width - width) / 2 - parent.x; y: (shell.height - height) / 2
                        Image { visible: false; width: 7; height: 9; anchors.verticalCenter: parent.verticalCenter; sourceSize: Qt.size(28, 36); source: root.svg('<path fill="#fff" d="M13.5 2L5 13.5h6L9.8 22 19 10h-6.2z"/>') }
                        Text { text: root.battPercent; color: root.fg; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
                Image {   // charging bolt without percentage
                    visible: false
                    anchors.centerIn: parent
                    width: 10; height: 11; sourceSize: Qt.size(40, 44)
                    source: root.svg('<path fill="#fff" stroke="#000" stroke-opacity="0.55" stroke-width="1.6" paint-order="stroke" d="M13.5 2L5 13.5h6L9.8 22 19 10h-6.2z"/>')
                }
            }
            Rectangle {   // terminal cap
                x: shell.width + 1; anchors.verticalCenter: parent.verticalCenter
                width: 1.8; height: 4.5; radius: 1
                color: bat.pct ? root.fgA(0.4) : root.fgA(0.55)
            }
        }
    }
}
