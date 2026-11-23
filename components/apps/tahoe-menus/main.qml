import QtQuick
import QtQuick.Controls as C
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.plasma5support as P5
import org.kde.plasma.workspace.keyboardlayout as KB

// macOS Tahoe menu-bar menus: apple | wifi | battery | clock | weather | input
Item {
    id: root
    property string menu: "wifi"
    readonly property int m: 22                 // transparent margin (blur region only covers glass)

    // fixed full-width window (see app.py); the glass is positioned under the menu-bar item
    property int screenW: 1920
    property int anchorX: 0          // left edge of the menu-bar item (-1 = right edge)
    property bool switching: false   // menu changed while already open -> no intro animation
    // auto-close when the pointer has left both the menu bar and the menu (user request 2026-11-20)
    property bool overBar: true
    readonly property bool overGlass: glassHover.hovered
    onOverGlassChanged: armClose()
    function armClose() {
        if (overBar || overGlass) closeTimer.stop(); else closeTimer.restart()
    }
    Timer {
        id: closeTimer; interval: 450
        onTriggered: if (!root.overBar && !root.overGlass && root.pwFor === "") bridge.dismiss()
    }

    // ------------------------------------------------------------ palette
    readonly property color glassFill: "#4a3a3a42"
    readonly property color cardFill: "#3a3a3a42"
    readonly property color rimTop: "#80ffffff"
    readonly property color rimBottom: "#26ffffff"
    readonly property color accent: "#0a84ff"
    readonly property color textMain: "#ffffff"
    readonly property color textDim: "#a8ffffff"
    readonly property color hoverFill: "#2effffff"
    readonly property string fontName: "Inter"
    readonly property var loc: Qt.locale()

    // ------------------------------------------------------------ glyphs (24x24, C = colour)
    readonly property var glyphs: ({
        wifi: '<g transform="translate(2.5 5)"><path d="M9.500 12.900L6.954 10.354A3.6 3.6 0 0 1 12.046 10.354Z" fill="C" stroke="C" stroke-width="1" stroke-linejoin="round"/><path d="M3.843 7.243A8.0 8.0 0 0 1 15.157 7.243A1.25 1.25 0 0 1 13.389 9.011A5.5 5.5 0 0 0 5.611 9.011A1.25 1.25 0 0 1 3.843 7.243Z" fill="C"/><path d="M0.732 4.132A12.4 12.4 0 0 1 18.268 4.132A1.25 1.25 0 0 1 16.500 5.900A9.9 9.9 0 0 0 2.500 5.900A1.25 1.25 0 0 1 0.732 4.132Z" fill="C"/></g>',
        lock: '<rect x="5.5" y="10.5" width="13" height="10" rx="2" fill="C"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5" fill="none" stroke="C" stroke-width="2"/>',
        chevron: '<path d="M9 5l7 7-7 7" fill="none" stroke="C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
        check: '<path d="M5 12.5l4.5 4.5L19 7" fill="none" stroke="C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
        bolt: '<path fill="C" d="M13.5 2L5 13.5h6L9.8 22 19 10h-6.2z"/>',
        plug: '<g fill="none" stroke="C" stroke-width="2" stroke-linecap="round"><path d="M9 3v4M15 3v4"/><path d="M6.5 7h11v3.5a5.5 5.5 0 0 1-11 0z" fill="C"/><path d="M12 16v5"/></g>',
        prev: '<path d="M15 5l-7 7 7 7" fill="none" stroke="C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
        drop: '<path fill="C" d="M12 3.5c-3 4-5.5 7.2-5.5 10.3a5.5 5.5 0 0 0 11 0C17.5 10.7 15 7.5 12 3.5z"/>',
        wind: '<g fill="none" stroke="C" stroke-width="2" stroke-linecap="round"><path d="M3 9h11.5a2.8 2.8 0 1 0-2.8-2.8"/><path d="M3 13.5h15.5a2.8 2.8 0 1 1-2.8 2.8"/><path d="M3 18h7"/></g>',
        humidity: '<path fill="none" stroke="C" stroke-width="2" d="M12 3.5c-3 4-5.5 7.2-5.5 10.3a5.5 5.5 0 0 0 11 0C17.5 10.7 15 7.5 12 3.5z"/>',
        emoji: '<circle cx="12" cy="12" r="9" fill="none" stroke="C" stroke-width="1.9"/><circle cx="9" cy="10" r="1.3" fill="C"/><circle cx="15" cy="10" r="1.3" fill="C"/><path d="M7.8 14a4.8 4.8 0 0 0 8.4 0" fill="none" stroke="C" stroke-width="1.9" stroke-linecap="round"/>',
        keyboard: '<rect x="2.5" y="6" width="19" height="12" rx="2.5" fill="none" stroke="C" stroke-width="1.8"/><g fill="C"><rect x="5.5" y="9" width="2" height="2" rx=".5"/><rect x="9" y="9" width="2" height="2" rx=".5"/><rect x="12.5" y="9" width="2" height="2" rx=".5"/><rect x="16" y="9" width="2" height="2" rx=".5"/><rect x="7.5" y="13" width="9" height="2" rx=".8"/></g>'
    })
    function svg(body) {
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">' + body + '</svg>')
    }
    function ic(name, color) { return svg((glyphs[name] || "").split('"C"').join('"' + color + '"')) }
    // wifi glyph with signal bars (dim arcs above the level)
    function wifiIc(level, color) {
        const o = i => (i <= Math.max(1, level) ? 1 : 0.3)
        return svg('<g transform="translate(2.5 5)"><path d="M9.500 12.900L6.954 10.354A3.6 3.6 0 0 1 12.046 10.354Z" fill="' + color + '" stroke="' + color + '" stroke-width="1" stroke-linejoin="round" opacity="' + o(1) + '"/><path d="M3.843 7.243A8.0 8.0 0 0 1 15.157 7.243A1.25 1.25 0 0 1 13.389 9.011A5.5 5.5 0 0 0 5.611 9.011A1.25 1.25 0 0 1 3.843 7.243Z" fill="' + color + '" opacity="' + o(2) + '"/><path d="M0.732 4.132A12.4 12.4 0 0 1 18.268 4.132A1.25 1.25 0 0 1 16.500 5.900A9.9 9.9 0 0 0 2.500 5.900A1.25 1.25 0 0 1 0.732 4.132Z" fill="' + color + '" opacity="' + o(3) + '"/></g>')
    }
    function sigLevel(s) { return s >= 50 ? 3 : (s >= 30 ? 2 : 1) }

    // ---- weather symbols (multicolour like SF Symbols "multicolor")
    function weatherKind(icon) {
        const n = String(icon || "")
        if (/storm|thunder/.test(n)) return "storm"
        if (/snow|hail|freezing/.test(n)) return "snow"
        if (/shower|rain/.test(n)) return "rain"
        if (/mist|fog|haze/.test(n)) return "fog"
        if (/overcast/.test(n)) return "cloud"
        if (/clouds-night/.test(n)) return "moonCloud"
        if (/clouds/.test(n)) return "sunCloud"
        if (/clear-night/.test(n)) return "moon"
        if (/clear/.test(n)) return "sun"
        return "cloud"
    }
    function weatherIc(icon, mono) {
        const S = mono ? "#ffffff" : "#ffd60a", W = "#ffffff", R = mono ? "#ffffff" : "#5ac8fa", M = mono ? "#ffffff" : "#e8e6f5"
        const cloud = '<path fill="' + W + '" d="M6.8 19.5h10.6a4.3 4.3 0 0 0 .5-8.57A6.2 6.2 0 0 0 6.1 9.9 4.8 4.8 0 0 0 6.8 19.5z"/>'
        const sun = (cx, cy, r, s) => '<circle cx="' + cx + '" cy="' + cy + '" r="' + r + '" fill="' + S + '"/><g stroke="' + S + '" stroke-width="' + s + '" stroke-linecap="round" transform="translate(' + cx + ' ' + cy + ')">'
            + '<path d="M0 -' + (r + 2.3) + 'v-1.9M0 ' + (r + 2.3) + 'v1.9M-' + (r + 2.3) + ' 0h-1.9M' + (r + 2.3) + ' 0h1.9"/>'
            + '<path transform="rotate(45)" d="M0 -' + (r + 2.3) + 'v-1.9M0 ' + (r + 2.3) + 'v1.9M-' + (r + 2.3) + ' 0h-1.9M' + (r + 2.3) + ' 0h1.9"/></g>'
        const up = c => '<g transform="translate(0 -3.2)">' + c + '</g>'
        switch (weatherKind(icon)) {
        case "sun": return svg(sun(12, 12, 4.2, 1.9))
        case "moon": return svg('<path fill="' + M + '" d="M14.8 3.2a8.8 8.8 0 1 0 6 14.2A7.4 7.4 0 0 1 14.8 3.2z"/>')
        case "sunCloud": return svg(sun(8.6, 8.4, 3.2, 1.6) + '<g transform="translate(2.6 2.2) scale(0.88)">' + cloud + '</g>')
        case "moonCloud": return svg('<path fill="' + M + '" d="M10 2.5a6.2 6.2 0 1 0 4.4 10A5.2 5.2 0 0 1 10 2.5z"/><g transform="translate(2.6 2.2) scale(0.88)">' + cloud + '</g>')
        case "rain": return svg(up(cloud) + '<g stroke="' + R + '" stroke-width="1.9" stroke-linecap="round"><path d="M8.2 18.6l-1.1 2.8M12.2 18.6l-1.1 2.8M16.2 18.6l-1.1 2.8"/></g>')
        case "snow": return svg(up(cloud) + '<g fill="' + R + '"><circle cx="8" cy="19.8" r="1.2"/><circle cx="12" cy="21.2" r="1.2"/><circle cx="16" cy="19.8" r="1.2"/></g>')
        case "storm": return svg(up(cloud) + '<path fill="' + S + '" d="M12.8 15.2l-3.4 4.6h2.6l-1.2 3.4 4.2-5h-2.6l1.6-3z"/>')
        case "fog": return svg(up(cloud) + '<g stroke="' + W + '" stroke-width="1.8" stroke-linecap="round" opacity="0.85"><path d="M5 19.4h14M7.5 22h9"/></g>')
        default: return svg(cloud)
        }
    }

    // ------------------------------------------------------------ backends
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.Handler { id: nm }
    PlasmaNM.NetworkModel { id: networkModel }
    PlasmaNM.AppletProxyModel { id: wifiProxy; sourceModel: networkModel }
    readonly property bool wifiOn: enabledConnections.wirelessEnabled

    P5.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter", "Power Profiles", "PowerDevil"]
        interval: 0
    }
    readonly property var batt: pm.data["Battery"] || ({})
    readonly property int battPercent: batt["Percent"] || 0
    readonly property bool onAC: !!(pm.data["AC Adapter"] && pm.data["AC Adapter"]["Plugged in"])
    readonly property string battState: batt["State"] || ""
    readonly property real remainingMs: batt["Smoothed Remaining msec"] || batt["Remaining msec"] || 0
    readonly property var engineProfiles: (pm.data["Power Profiles"] && pm.data["Power Profiles"]["Profiles"]) || []
    readonly property string engineProfile: (pm.data["Power Profiles"] && pm.data["Power Profiles"]["Current Profile"]) || ""
    // Fallback straight from PowerDevil over D-Bus: the engine source can come
    // back empty in this long-running process (seen while on AC / after replug).
    property var dbusProfiles: []
    property string dbusProfile: ""
    readonly property var profiles: engineProfiles.length > 0 ? engineProfiles : dbusProfiles
    readonly property string profile: dbusProfile !== "" ? dbusProfile : engineProfile
    onEngineProfileChanged: if (engineProfile !== "") dbusProfile = ""
    function refreshProfiles() {
        const o = "gdbus call --session -d org.kde.Solid.PowerManagement -o /org/kde/Solid/PowerManagement/Actions/PowerProfile -m org.kde.Solid.PowerManagement.Actions.PowerProfile."
        bridge.outputAsync("powerprofile", o + "profileChoices; " + o + "currentProfile")
    }
    Connections {
        target: bridge
        function onOutputReady(key, out) {
            if (key !== "powerprofile") return
            const lines = out.split("\n")
            const names = (lines[0] || "").match(/'[^']+'/g) || []
            root.dbusProfiles = names.map(n => n.slice(1, -1))
            const cur = (lines[1] || "").match(/'([^']+)'/)
            root.dbusProfile = cur ? cur[1] : ""
        }
    }
    // At login tahoe-menus can start before tuned-ppd/power-profiles-daemon is
    // ready; the engine then reports no profiles and never refreshes -> the
    // Energy Mode control stayed hidden. Re-connect the source until it arrives.
    Timer {
        interval: 2000; repeat: true
        running: root.profiles.length === 0
        onTriggered: { pm.disconnectSource("Power Profiles"); pm.connectSource("Power Profiles") }
    }
    function setProfile(p) {
        const service = pm.serviceForSource("PowerDevil")
        const op = service.operationDescription("setPowerProfile")
        op.profile = p
        service.startOperationCall(op)
        dbusProfile = p
        refreshTimer.restart()
    }
    Timer { id: refreshTimer; interval: 700; onTriggered: root.refreshProfiles() }

    P5.DataSource {
        id: wx
        engine: "weather"
        connectedSources: [weatherSource]
        interval: 30 * 60 * 1000
    }
    readonly property var wd: wx.data[weatherSource] || ({})
    function forecast(i) {
        const s = wd["Short Forecast Day " + i]
        if (!s) return null
        const p = String(s).split("|")
        let hi = parseFloat(p[3]), lo = parseFloat(p[4])
        // providers drop today's high in the evening (and sometimes a low): fall back like Apple Weather
        const cur = parseFloat(wd["Temperature"])
        if (isNaN(hi)) hi = i === 0 && !isNaN(cur) ? Math.max(cur, isNaN(lo) ? cur : lo) : lo
        if (isNaN(lo)) lo = i === 0 && !isNaN(cur) ? Math.min(cur, isNaN(hi) ? cur : hi) : hi
        return { day: p[0], icon: p[1], text: p[2], hi: hi, lo: lo, rain: p[5] }
    }
    readonly property var today: forecast(0)
    readonly property string wxIcon: (wd["Condition Icon"] && wd["Condition Icon"] !== "weather-none-available") ? wd["Condition Icon"] : (today ? today.icon : "")
    readonly property string wxTemp: wd["Temperature"] !== undefined ? Math.round(wd["Temperature"]) + "°" : "–"
    readonly property string wxPlace: {
        const p = String(wd["Place"] || "")
        return p.split(",")[0]
    }
    function cap(s) { s = String(s || ""); return s.charAt(0).toUpperCase() + s.slice(1) }
    readonly property string wxText: cap(wd["Current Conditions"] || (today ? today.text : ""))
    readonly property string windKmh: {
        const v = wd["Wind Speed"], u = wd["Wind Speed Unit"]
        if (v === undefined || isNaN(v)) return "–"
        const k = u === 9002 ? v * 1.609 : (u === 9000 ? v * 3.6 : (u === 9003 ? v * 1.852 : v))
        return Math.round(k) + " km/sa"
    }

    KB.KeyboardLayout { id: kb }

    // ------------------------------------------------------------ lifecycle
    property bool othersOpen: false
    property string pwFor: ""
    property date calMonth: new Date()
    property date now: new Date()
    Timer { interval: 15000; repeat: true; running: true; onTriggered: root.now = new Date() }

    function opened() {
        now = new Date()
        calMonth = new Date(now.getFullYear(), now.getMonth(), 1)
        othersOpen = false
        pwFor = ""
        if (menu === "wifi") nm.requestScan()
        if (menu === "battery") refreshProfiles()
        if (switching) { intro.stop(); stage.opacity = 1; stage.scale = 1 }
        else intro.restart()
        Qt.callLater(pushShapes)
    }
    function launch(cmd) { bridge.dismiss(); bridge.run(cmd) }

    function collect(item, out) {
        if (!item || !item.visible || item.opacity < 0.05) return
        if (item.isGlass === true) {
            const p = item.mapToItem(root, 0, 0)
            out.push([p.x, p.y, item.width, item.height, item.radius])
        }
        for (let i = 0; i < item.children.length; ++i) collect(item.children[i], out)
    }
    function pushShapes() { const out = []; collect(stage, out); bridge.setShapes(out) }
    onWidthChanged: Qt.callLater(pushShapes)
    onHeightChanged: Qt.callLater(pushShapes)
    onMenuChanged: Qt.callLater(pushShapes)

    // ------------------------------------------------------------ components
    component Glass: Rectangle {
        readonly property bool isGlass: true
        color: root.glassFill
        radius: 16
        Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: root.rimBottom }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#14ffffff" }
                GradientStop { position: 0.35; color: "#00ffffff" }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0.5; width: parent.width - parent.radius * 1.4; height: 1
            color: root.rimTop; opacity: 0.5
        }
    }
    component Label: Text {
        color: root.textMain
        font.family: root.fontName; font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component Header: Text {       // bold menu title ("Wi-Fi", "Pil")
        color: root.textMain
        font.family: root.fontName; font.pixelSize: 13; font.weight: Font.Bold
    }
    component Section: Text {      // grey section caption
        color: root.textDim
        font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold
        leftPadding: 10; topPadding: 4; bottomPadding: 2
    }
    component Sep: Item {
        width: parent ? parent.width : 0; height: 11
        Rectangle { x: 10; y: 5; width: parent.width - 20; height: 1; color: "#24ffffff" }
    }
    // hover row with rounded highlight (Tahoe menus highlight with a soft pill)
    component Row2: Item {
        id: r2
        default property alias content: box.data
        property bool enabled2: true
        property alias hovered: rma.containsMouse
        signal clicked()
        width: parent ? parent.width : 0
        height: 28
        Rectangle {
            anchors.fill: parent; radius: 8
            color: rma.containsMouse && r2.enabled2 ? root.hoverFill : "transparent"
        }
        Item { id: box; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10 }
        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: if (r2.enabled2) r2.clicked() }
    }
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled()
        width: 34; height: 20; radius: 10
        color: on ? root.accent : "#45ffffff"
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 2
            x: tg.on ? tg.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: tg.toggled() }
    }
    component Glyph: Image {
        property string name
        property color tint: "#ffffff"
        width: 14; height: 14
        sourceSize: Qt.size(48, 48)
        opacity: tint.a
        source: root.ic(name, Qt.rgba(tint.r, tint.g, tint.b, 1).toString())
    }

    // ------------------------------------------------------------ stage
    Item {
        id: stage
        x: Math.round(Math.max(6, Math.min(root.anchorX < 0 ? 1e6 : root.anchorX - 6, root.screenW - 6 - width)))
        y: root.m
        onXChanged: Qt.callLater(root.pushShapes)
        HoverHandler { id: glassHover }
        width: loader.item ? loader.item.width : 10
        height: loader.item ? loader.item.height : 10
        transformOrigin: Item.Top

        ParallelAnimation {
            id: intro
            NumberAnimation { target: stage; property: "opacity"; from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "scale"; from: 0.96; to: 1; duration: 200; easing.type: Easing.OutCubic }
            onFinished: root.pushShapes()
        }

        Loader {
            id: loader
            sourceComponent: root.menu.indexOf("f-") === 0 ? finderMenu : ({ apple: appleMenu, wifi: wifiMenu, battery: batteryMenu, clock: clockMenu, weather: weatherMenu, input: inputMenu })[root.menu] || null
            onLoaded: Qt.callLater(root.pushShapes)
        }
    }

    // ===================================================================== Finder (desktop) menus
    // menu name "f-<Title>" (sent by the local.tahoe.appname plasmoid when the desktop is focused)
    readonly property string qd: "@QTBINS@/qdbus "
    readonly property var finderMenus: ({
        "Finder": [{label: "Finder Hakkında", command: "kinfocenter"}, {sep: true},
                   {label: "Çöp Kutusunu Aç…", command: "dolphin trash:/"}],
        "Dosya": [{label: "Yeni Finder Penceresi", command: "dolphin --new-window ~"},
                  {label: "Belgeler", command: "dolphin --new-window ~/Documents"},
                  {sep: true}, {label: "Terminal", command: "konsole"}],
        "Düzen": [{label: "Pano Geçmişi", command: qd + "org.kde.klipper /klipper org.kde.klipper.klipper.showKlipperPopupMenu"},
                  {sep: true},
                  {label: "Emoji ve Semboller", command: "plasma-emojier"},
                  {label: "Masaüstünü Düzenle", command: qd + "org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.editMode true"}],
        "Görüntü": [{label: "Masaüstünü Göster", command: qd + "org.kde.KWin /KWin org.kde.KWin.showDesktop true"},
                    {label: "Pencereleri Göster", command: qd + "org.kde.KWin /KWin org.kde.KWin.showDesktop false"}],
        "Git": [{label: "Ev", command: "dolphin --new-window ~"},
                {label: "Masaüstü", command: "dolphin --new-window ~/Masaüstü"},
                {label: "İndirilenler", command: "dolphin --new-window ~/İndirilenler"},
                {sep: true}, {label: "Çöp Kutusu", command: "dolphin --new-window trash:/"}],
        "Pencere": [{label: "Tüm Pencereler", command: qd + "org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut Overview"}],
        "Yardım": [{label: "Sistem Ayarları", command: "systemsettings"},
                   {label: "KDE Yardım Merkezi", command: "khelpcenter"}]
    })
    Component {
        id: finderMenu
        Glass {
            width: 240
            height: fcol.height + 12
            radius: 12
            Column {
                id: fcol
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: root.finderMenus[root.menu.slice(2)] || []
                    delegate: Loader {
                        required property var modelData
                        width: fcol.width
                        sourceComponent: modelData.sep ? sepC : rowC
                        Component { id: sepC; Sep {} }
                        Component { id: rowC
                            Row2 { onClicked: root.launch(modelData.command)
                                Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.label } } }
                    }
                }
            }
        }
    }

    // ===================================================================== Apple menu
    // Tahoe's  menu: only system commands (no app launcher). Restart/Shut Down/Log Out
    // go through the Tahoe logout alert (org.kde.LogoutPrompt), which asks first.
    readonly property string userName: "@USERNAME@"
    Component {
        id: appleMenu
        Glass {
            width: 250
            height: acol.height + 12
            radius: 14
            Column {
                id: acol
                x: 6; y: 6; width: parent.width - 12
                Row2 { onClicked: root.launch("kinfocenter")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Bu Mac Hakkında" } }
                Sep {}
                Row2 { onClicked: root.launch("systemsettings")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Sistem Ayarları…" } }
                Row2 { onClicked: root.launch("plasma-discover")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "App Store…" } }
                Sep {}
                Row2 { onClicked: root.launch("busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s 'Kill Window'")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Zorla Çık…" } }
                Sep {}
                Row2 { onClicked: root.launch("systemctl suspend")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Uyut" } }
                Row2 { onClicked: root.launch("busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptReboot")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Yeniden Başlat…" } }
                Row2 { onClicked: root.launch("busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptShutDown")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Kapat…" } }
                Sep {}
                Row2 { onClicked: root.launch("loginctl lock-session")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Ekranı Kilitle" }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "⌘L"; color: root.textDim; font.family: root.fontName; font.pixelSize: 12 } }
                Row2 { onClicked: root.launch("busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptLogout")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Oturumu Kapat: " + root.userName + "…" } }
            }
        }
    }

    // ===================================================================== Wi-Fi
    Component {
        id: wifiMenu
        Glass {
            id: wpanel
            width: 300
            height: wcol.height + 12
            onHeightChanged: Qt.callLater(root.pushShapes)
            Column {
                id: wcol
                x: 6; y: 6; width: parent.width - 12
                Item {
                    width: parent.width; height: 34
                    Header { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi" }
                    Toggle {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.wifiOn
                        onToggled: nm.enableWireless(!root.wifiOn)
                    }
                }
                Sep { visible: root.wifiOn }

                Section { visible: root.wifiOn && knownRep.shown > 0; text: "Bilinen Ağlar" }
                Repeater {
                    id: knownRep
                    property int shown: 0
                    model: root.wifiOn ? wifiProxy : null
                    delegate: NetRow { md: model; section: true; onVisibleChanged: Qt.callLater(() => knownRep.shown = wpanel.countShown(knownRep)) }
                    onItemAdded: Qt.callLater(() => shown = wpanel.countShown(knownRep))
                    onItemRemoved: Qt.callLater(() => shown = wpanel.countShown(knownRep))
                }
                Row2 {
                    visible: root.wifiOn
                    onClicked: { root.othersOpen = !root.othersOpen; Qt.callLater(root.pushShapes) }
                    Section { anchors.verticalCenter: parent.verticalCenter; leftPadding: 0; topPadding: 0; bottomPadding: 0; text: "Diğer Ağlar" }
                    Glyph {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; name: "chevron"; tint: "#c8ffffff"
                        rotation: root.othersOpen ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 150 } }
                    }
                }
                Flickable {
                    visible: root.wifiOn && root.othersOpen
                    width: parent.width
                    height: Math.min(otherCol.height, 260)
                    contentHeight: otherCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    C.ScrollBar.vertical: C.ScrollBar { policy: otherCol.height > 260 ? C.ScrollBar.AsNeeded : C.ScrollBar.AlwaysOff }
                    Column {
                        id: otherCol
                        width: parent.width
                        Repeater {
                            model: root.wifiOn && root.othersOpen ? wifiProxy : null
                            delegate: NetRow { md: model; section: false }
                        }
                    }
                }
                Sep {}
                Row2 {
                    onClicked: root.launch("kcmshell6 kcm_networkmanagement")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi Ayarları…" }
                }
            }
            function countShown(rep) {
                let n = 0
                for (let i = 0; i < rep.count; ++i) if (rep.itemAt(i) && rep.itemAt(i).visible) n++
                return n
            }
        }
    }
    component NetRow: Column {
            id: nr
            property var md
            readonly property bool isWifi: nr.md.Type === PlasmaNM.Enums.Wireless
            readonly property bool saved: !!nr.md.Uuid && String(nr.md.Uuid).length > 0
            readonly property bool active: nr.md.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool busy: nr.md.ConnectionState === PlasmaNM.Enums.Activating
            readonly property bool secured: nr.md.SecurityType > PlasmaNM.Enums.NoneSecurity
            readonly property string uniq: nr.md.ItemUniqueName || ""
            // the Repeater that created us tells which section we belong to
            property bool section: true
            width: parent ? parent.width : 0
            visible: isWifi && (section === saved)
            height: visible ? implicitHeight : 0
            Row2 {
                height: 36
                onClicked: {
                    if (nr.active) nm.deactivateConnection(nr.md.ConnectionPath, nr.md.DevicePath)
                    else if (nr.saved) nm.activateConnection(nr.md.ConnectionPath, nr.md.DevicePath, nr.md.SpecificPath)
                    else if (nr.secured) { root.pwFor = (root.pwFor === nr.uniq ? "" : nr.uniq); Qt.callLater(root.pushShapes) }
                    else nm.addAndActivateConnection(nr.md.DevicePath, nr.md.SpecificPath)
                }
                Rectangle {
                    x: -4; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: nr.active ? root.accent : "#33ffffff"
                    Image {
                        anchors.centerIn: parent; width: 15; height: 15; sourceSize: Qt.size(48, 48)
                        source: root.wifiIc(root.sigLevel(nr.md.Signal), "#ffffff")
                    }
                }
                Label {
                    x: 30; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 40
                    text: nr.md.ItemUniqueName || ""
                }
                C.BusyIndicator {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; running: visible; visible: nr.busy
                }
                Glyph {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11; height: 11; visible: nr.secured
                    name: "lock"; tint: "#b4ffffff"
                }
            }
            Row {
                visible: root.pwFor === nr.uniq && nr.uniq !== ""
                x: 40; spacing: 8; height: visible ? 38 : 0
                C.TextField {
                    id: pw
                    width: 150; height: 28
                    echoMode: TextInput.Password
                    placeholderText: "Parola"
                    font.family: root.fontName
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: joinMa.clicked(null)
                }
                Rectangle {
                    width: 64; height: 28; radius: 14; color: root.accent
                    Text { anchors.centerIn: parent; text: "Katıl"; color: "white"; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea {
                        id: joinMa; anchors.fill: parent
                        onClicked: {
                            if (pw.text.length) nm.addAndActivateConnection(nr.md.DevicePath, nr.md.SpecificPath, pw.text)
                            root.pwFor = ""
                        }
                    }
                }
            }
        }

    // ===================================================================== Battery
    Component {
        id: batteryMenu
        Glass {
            width: 290
            height: bcol.height + 12
            Column {
                id: bcol
                x: 6; y: 6; width: parent.width - 12
                Item {
                    width: parent.width; height: 34
                    Header { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Pil" }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.battPercent + "%"
                        color: root.textDim; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                Item {
                    width: parent.width; height: 24
                    Label {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        color: root.textDim
                        text: "Güç Kaynağı: " + (root.onAC ? "Güç Adaptörü" : "Pil")
                    }
                }
                Item {
                    width: parent.width; height: 24
                    visible: text2.text.length > 0
                    Label {
                        id: text2
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        color: root.textDim
                        text: {
                            if (root.battState === "FullyCharged") return "Tamamen şarj oldu"
                            if (root.onAC && root.battState === "NoCharge")
                                return root.batt["Charge Stop Threshold"] > 0 && root.battPercent >= root.batt["Charge Stop Threshold"] - 2
                                    ? "Şarj beklemede (sınır %" + root.batt["Charge Stop Threshold"] + ")" : "Şarj beklemede"
                            if (root.remainingMs <= 0) return root.battState === "Charging" ? "Şarj oluyor" : ""
                            const min = Math.round(root.remainingMs / 60000)
                            const t = Math.floor(min / 60) + " sa " + (min % 60) + " dk"
                            return root.battState === "Charging" ? "Dolmasına " + t : "Kalan süre: " + t
                        }
                    }
                }
                Sep {}
                Section { text: "Enerji Modu" }
                // segmented control (Tahoe "Energy Mode")
                Rectangle {
                    x: 8; width: parent.width - 16; height: 30; radius: 15
                    color: "#26ffffff"
                    visible: root.profiles.length > 0
                    Row {
                        anchors.fill: parent; anchors.margins: 2
                        Repeater {
                            model: [["power-saver", "Düşük Güç"], ["balanced", "Otomatik"], ["performance", "Yüksek Güç"]]
                            delegate: Rectangle {
                                width: (parent.width) / 3; height: parent.height; radius: height / 2
                                color: root.profile === modelData[0] ? "#ffffff" : (sma.containsMouse ? "#1fffffff" : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData[1]
                                    color: root.profile === modelData[0] ? "#1c1c1e" : root.textMain
                                    font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold
                                }
                                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: root.setProfile(modelData[0]) }
                            }
                        }
                    }
                }
                Item { width: 1; height: 6 }
                Sep {}
                Row2 {
                    onClicked: root.launch("kcmshell6 kcm_powerdevilprofilesconfig")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Pil Ayarları…" }
                }
            }
        }
    }

    // ===================================================================== Input source
    Component {
        id: inputMenu
        Glass {
            width: 260
            height: icol.height + 12
            Column {
                id: icol
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: kb.layoutsList
                    delegate: Row2 {
                        onClicked: { kb.layout = index; bridge.dismiss() }
                        Glyph {
                            x: -2; anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; name: "check"
                            visible: index === kb.layout
                        }
                        Rectangle {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            height: 15; width: Math.max(20, bl.implicitWidth + 7); radius: 4
                            color: "transparent"; border.width: 1; border.color: "white"
                            Text {
                                id: bl; anchors.centerIn: parent; anchors.verticalCenterOffset: 0.5
                                text: String(modelData.displayName || modelData.shortName).toUpperCase()
                                color: "white"; font.family: root.fontName; font.pixelSize: 10; font.weight: Font.DemiBold
                            }
                        }
                        Label { x: 50; anchors.verticalCenter: parent.verticalCenter; text: modelData.longName }
                    }
                }
                Sep {}
                Row2 {
                    onClicked: root.launch("plasma-emojier")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Emoji ve Semboller" }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "⌘."; color: root.textDim; font.family: root.fontName; font.pixelSize: 12 }
                }
                Sep {}
                Row2 {
                    onClicked: root.launch("kcmshell6 kcm_keyboard")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Klavye Ayarlarını Aç…" }
                }
            }
        }
    }

    // ===================================================================== Weather
    component WeatherList: Column {
        id: wl
        property int days: 7
        readonly property var fc: { root.wd; const a = []; for (let i = 0; i < days; ++i) { const f = root.forecast(i); if (f) a.push(f) } return a }
        readonly property real minT: Math.min.apply(null, fc.map(f => f.lo))
        readonly property real maxT: Math.max.apply(null, fc.map(f => f.hi))
        Repeater {
            model: wl.fc
            delegate: Item {
                width: wl.width; height: 30
                Rectangle { visible: index > 0; width: parent.width; height: 1; color: "#1fffffff" }
                Text {
                    x: 0; width: 52; anchors.verticalCenter: parent.verticalCenter
                    text: index === 0 ? "Bugün" : modelData.day
                    color: root.textMain; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Image {
                    x: 54; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; sourceSize: Qt.size(48, 48)
                    source: root.weatherIc(modelData.icon, false)
                }
                Text {
                    x: 78; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.rain && modelData.rain !== "N/A" && parseInt(modelData.rain) >= 10 ? "%" + modelData.rain : ""
                    color: "#5ac8fa"; font.family: root.fontName; font.pixelSize: 11; font.weight: Font.DemiBold
                }
                Text {
                    id: lo
                    x: 110; width: 30; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(modelData.lo) + "°"
                    color: root.textDim; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Rectangle {   // temperature range bar
                    id: track
                    x: 148; width: parent.width - 148 - 40; height: 5; radius: 2.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#26ffffff"
                    readonly property real span: Math.max(1, wl.maxT - wl.minT)
                    Rectangle {
                        x: track.width * (modelData.lo - wl.minT) / track.span
                        width: Math.max(height, track.width * (modelData.hi - modelData.lo) / track.span)
                        height: parent.height; radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: modelData.lo < 8 ? "#64d2ff" : "#9fe870" }
                            GradientStop { position: 1; color: modelData.hi > 20 ? "#ff9f0a" : "#ffd60a" }
                        }
                    }
                }
                Text {
                    anchors.right: parent.right; width: 32; horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(modelData.hi) + "°"
                    color: root.textMain; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                }
            }
        }
    }

    Component {
        id: weatherMenu
        Glass {
            width: 320
            height: wxcol.height + 28
            radius: 22
            Column {
                id: wxcol
                x: 16; y: 14; width: parent.width - 32
                spacing: 2
                Item {
                    width: parent.width; height: 92
                    Text {
                        y: 0; text: root.wxPlace + "  ➤"
                        color: root.textMain; font.family: root.fontName; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Text {
                        y: 18; text: root.wxTemp
                        color: root.textMain; font.family: root.fontName; font.pixelSize: 50; font.weight: Font.Light
                    }
                    Image {
                        anchors.right: parent.right; y: 4
                        width: 34; height: 34; sourceSize: Qt.size(96, 96)
                        source: root.weatherIc(root.wxIcon, false)
                    }
                    Column {
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        Text {
                            anchors.right: parent.right
                            text: root.wxText
                            color: root.textMain; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.today ? "Y:" + Math.round(root.today.hi) + "°  D:" + Math.round(root.today.lo) + "°" : ""
                            color: root.textMain; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                    }
                }
                // small detail tiles
                Row {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: [["wind", "Rüzgar", root.windKmh],
                                ["humidity", "Nem", root.wd["Humidity"] !== undefined ? "%" + Math.round(root.wd["Humidity"]) : "–"],
                                ["drop", "Yağış", root.today && root.today.rain !== "N/A" ? "%" + root.today.rain : "–"]]
                        delegate: Rectangle {
                            width: (parent.width - 16) / 3; height: 52; radius: 12
                            color: "#1fffffff"
                            Row {
                                x: 9; y: 8; spacing: 4
                                Image { width: 11; height: 11; sourceSize: Qt.size(48, 48); source: root.ic(modelData[0], "#ffffff"); opacity: 0.66; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData[1].toLocaleUpperCase(); color: root.textDim; font.family: root.fontName; font.pixelSize: 10; font.weight: Font.DemiBold }
                            }
                            Text { x: 9; y: 25; text: modelData[2]; color: root.textMain; font.family: root.fontName; font.pixelSize: 15; font.weight: Font.DemiBold }
                        }
                    }
                }
                Item { width: 1; height: 8 }
                Text {
                    text: "7 GÜNLÜK TAHMİN"
                    color: root.textDim; font.family: root.fontName; font.pixelSize: 11; font.weight: Font.DemiBold
                }
                Rectangle { width: parent.width; height: 1; color: "#26ffffff" }
                WeatherList { width: parent.width; days: 7 }
                Item { width: 1; height: 4 }
                Row2 {
                    x: -10; width: parent.width + 20; height: 26
                    onClicked: root.launch("xdg-open '" + String(root.wd["Credit Url"] || "https://www.bbc.com/weather") + "'")
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "Hava Durumu'nu Aç…" }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "BBC Weather"; color: root.textDim; font.family: root.fontName; font.pixelSize: 11 }
                }
            }
        }
    }

    // ===================================================================== Clock → Notification Center widgets
    Component {
        id: clockMenu
        Column {
            width: 344
            spacing: 10
            // ---- big date header
            Glass {
                width: parent.width; height: 64; radius: 22
                color: root.cardFill
                Column {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.now.toLocaleDateString(root.loc, "dddd, d MMMM")
                        color: root.textDim; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    Text {
                        text: Qt.formatTime(root.now, "HH:mm")
                        color: root.textMain; font.family: root.fontName; font.pixelSize: 26; font.weight: Font.Bold
                    }
                }
            }
            Row {
                spacing: 10
                // ---- calendar widget (small square, Tahoe style)
                Glass {
                    id: cal
                    width: 167; height: 167; radius: 22
                    color: root.cardFill
                    readonly property int y0: root.calMonth.getFullYear()
                    readonly property int m0: root.calMonth.getMonth()
                    readonly property int first: (new Date(y0, m0, 1).getDay() + 6) % 7      // Monday first
                    readonly property int days: new Date(y0, m0 + 1, 0).getDate()
                    readonly property bool thisMonth: y0 === root.now.getFullYear() && m0 === root.now.getMonth()
                    Text {
                        x: 14; y: 11
                        text: root.loc.standaloneMonthName(cal.m0).toLocaleUpperCase()
                        color: "#ff453a"; font.family: root.fontName; font.pixelSize: 11; font.weight: Font.Bold
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; y: 8; spacing: 2
                        Repeater {
                            model: [-1, 1]
                            delegate: Item {
                                width: 18; height: 18
                                Glyph { anchors.centerIn: parent; width: 9; height: 9; name: modelData < 0 ? "prev" : "chevron"; tint: "#c8ffffff" }
                                MouseArea { anchors.fill: parent; onClicked: root.calMonth = new Date(cal.y0, cal.m0 + modelData, 1) }
                            }
                        }
                    }
                    Grid {
                        x: 9; y: 30; columns: 7
                        Repeater {
                            model: 7
                            delegate: Text {
                                width: 21; height: 16; horizontalAlignment: Text.AlignHCenter
                                text: root.loc.dayName((index + 1) % 7, Locale.NarrowFormat).toLocaleUpperCase()
                                color: root.textDim; font.family: root.fontName; font.pixelSize: 9; font.weight: Font.Bold
                            }
                        }
                        Repeater {
                            model: 42
                            delegate: Item {
                                readonly property int d: index - cal.first + 1
                                readonly property bool isToday: cal.thisMonth && d === root.now.getDate()
                                width: 21; height: 19
                                visible: index < Math.ceil((cal.first + cal.days) / 7) * 7
                                Rectangle {
                                    anchors.centerIn: parent; width: 18; height: 18; radius: 9
                                    color: "#ff453a"; visible: parent.isToday
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.d >= 1 && parent.d <= cal.days ? parent.d : ""
                                    color: parent.isToday ? "#ffffff" : ((index % 7) >= 5 ? root.textDim : root.textMain)
                                    font.family: root.fontName; font.pixelSize: 10; font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
                // ---- weather widget (small square)
                Glass {
                    width: 167; height: 167; radius: 22
                    color: "#5a2f6fb8"
                    MouseArea { anchors.fill: parent; onClicked: bridge.display("weather", -1) }
                    Column {
                        x: 14; y: 12; width: parent.width - 28
                        Text { text: root.wxPlace + " ➤"; color: "white"; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { text: root.wxTemp; color: "white"; font.family: root.fontName; font.pixelSize: 40; font.weight: Font.Light }
                    }
                    Column {
                        x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                        Image { width: 20; height: 20; sourceSize: Qt.size(48, 48); source: root.weatherIc(root.wxIcon, false) }
                        Text { text: root.wxText; color: "white"; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Text {
                            text: root.today ? "Y:" + Math.round(root.today.hi) + "° D:" + Math.round(root.today.lo) + "°" : ""
                            color: "white"; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                }
            }
            // ---- medium forecast widget
            Glass {
                width: parent.width; height: fcl.height + 24; radius: 22
                color: root.cardFill
                WeatherList { id: fcl; x: 16; y: 12; width: parent.width - 32; days: 5 }
            }
            // ---- footer pill
            Glass {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150; height: 30; radius: 15
                color: eda.containsMouse ? "#5a5a5a62" : root.cardFill
                Text { anchors.centerIn: parent; text: "Tarih ve Saat…"; color: root.textMain; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold }
                MouseArea { id: eda; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch("kcmshell6 kcm_clock") }
            }
        }
    }
}
