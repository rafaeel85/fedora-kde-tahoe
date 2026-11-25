import QtQuick
import QtQuick.Controls as C
import QtQuick.Effects
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.brightnesscontrolplugin as Bright

// macOS Tahoe Control Center: floating Liquid-Glass modules on a 4-column grid
Item {
    id: root

    // ------------------------------------------------------------ geometry
    readonly property int m: 22          // shadow margin
    readonly property int u: 62          // grid unit (one circle)
    readonly property int g: 12          // gap
    readonly property int fullW: 4 * u + 3 * g
    readonly property int w2: 2 * u + g
    property string page: "main"         // main | wifi | bt

    width: fullW + 2 * m
    height: m + (page === "main" ? mainGrid.height : detail.height) + m

    // ------------------------------------------------------------ palette
    // adaptive glass (2026-11-26): darker glass on light wallpapers (glassTone.dim 0..1 from app.py)
    readonly property real dim: typeof glassTone !== "undefined" ? glassTone.dim : 0
    // appearance (2026-11-26): light = system light mode (black text, light glass); from app.py glassTone
    readonly property bool light: typeof glassTone !== "undefined" && glassTone.light
    function fg(a) { return light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a) }       // overlay / dim text
    readonly property color fgHex: light ? "#1d1d1f" : "#ffffff"                     // glyph tint
    // tone(darkColour, darkSolidAlpha, lightColour, lightSolidAlpha): glass fill for the current appearance,
    // pushed towards a solid dark (dark mode) / white (light mode) glass by dim
    function tone(c, a2, lc, la2) {
        c = Qt.color(light && lc !== undefined ? lc : c)
        const t = light ? [0.97, 0.97, 0.98] : [0.10, 0.10, 0.11]
        const A = light && la2 !== undefined ? la2 : a2
        return Qt.rgba(c.r + (t[0] - c.r) * dim, c.g + (t[1] - c.g) * dim, c.b + (t[2] - c.b) * dim, c.a + (A - c.a) * dim)
    }
    readonly property color glassFill: tone("#30ffffff", 0.55, "#d4f6f6f8", 0.92)
    readonly property color glassHover: tone("#40ffffff", 0.62, "#e6ffffff", 0.96)
    readonly property color rimTop: "#80ffffff"
    readonly property color rimBottom: "#26ffffff"
    readonly property color accent: "#0a84ff"
    readonly property color textMain: light ? "#1d1d1f" : "#ffffff"
    readonly property color textDim: root.fg(0.784)
    readonly property string fontName: "Inter"

    // ------------------------------------------------------------ SF-like glyphs (24x24)
    readonly property var glyphs: ({
        wifi: '<g transform="translate(2.5 5)"><path d="M9.500 12.900L6.954 10.354A3.6 3.6 0 0 1 12.046 10.354Z" fill="C" stroke="C" stroke-width="1" stroke-linejoin="round"/><path d="M3.843 7.243A8.0 8.0 0 0 1 15.157 7.243A1.25 1.25 0 0 1 13.389 9.011A5.5 5.5 0 0 0 5.611 9.011A1.25 1.25 0 0 1 3.843 7.243Z" fill="C"/><path d="M0.732 4.132A12.4 12.4 0 0 1 18.268 4.132A1.25 1.25 0 0 1 16.500 5.900A9.9 9.9 0 0 0 2.500 5.900A1.25 1.25 0 0 1 0.732 4.132Z" fill="C"/></g>',
        bluetooth: '<path d="M6.8 7.2l10.2 9.4-5 4.6V2.8l5 4.6-10.2 9.4" fill="none" stroke="C" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
        airplane: '<path fill="C" d="M21.5 15.6v-1.8l-8.2-5.2V3.9a1.3 1.3 0 0 0-2.6 0v4.7l-8.2 5.2v1.8l8.2-2.6v5l-2.3 1.7v1.4l3.6-1.1 3.6 1.1v-1.4L13.3 18v-5z"/>',
        appearance: '<circle cx="12" cy="12" r="8.2" fill="none" stroke="C" stroke-width="1.9"/><path fill="C" d="M12 3.8a8.2 8.2 0 0 1 0 16.4z"/>',
        moon: '<path fill="C" d="M19.6 15.3A8.4 8.4 0 0 1 8.7 4.4a.6.6 0 0 0-.8-.7 9 9 0 1 0 12.4 12.4.6.6 0 0 0-.7-.8z"/>',
        stage: '<g fill="none" stroke="C" stroke-width="2"><rect x="8.5" y="5" width="12.5" height="14" rx="2.6"/></g><g fill="C"><rect x="3" y="5" width="3" height="3.6" rx="1"/><rect x="3" y="10.2" width="3" height="3.6" rx="1"/><rect x="3" y="15.4" width="3" height="3.6" rx="1"/></g>',
        mirror: '<g fill="none" stroke="C" stroke-width="2" stroke-linejoin="round"><path d="M14.5 7V6a2.4 2.4 0 0 0-2.4-2.4H5.4A2.4 2.4 0 0 0 3 6v6.6A2.4 2.4 0 0 0 5.4 15h1"/><rect x="8.5" y="8.6" width="12.5" height="11" rx="2.4"/></g>',
        sun: '<circle cx="12" cy="12" r="3.6" fill="none" stroke="C" stroke-width="1.8"/><g stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/></g>',
        spkLow: '<path fill="C" d="M4 9.2h3.3L11.8 5.6v12.8l-4.5-3.6H4a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/>',
        spkHigh: '<path fill="C" d="M3 9.2h3L10 5.6v12.8l-4-3.6H3a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/><g fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M13.5 9.2a4 4 0 0 1 0 5.6"/><path d="M16.2 6.8a7.4 7.4 0 0 1 0 10.4"/><path d="M18.9 4.4a10.8 10.8 0 0 1 0 15.2"/></g>',
        airplay: '<g fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M7 16.5a7 7 0 1 1 10 0"/><path d="M9.3 14a3.6 3.6 0 1 1 5.4 0"/></g><path fill="C" d="M12 14.5l4 5.2H8z"/>',
        sunset: '<g fill="none" stroke="C" stroke-width="1.9" stroke-linecap="round"><path d="M7.5 16a4.5 4.5 0 0 1 9 0"/><path d="M3 19.5h18M12 6.5v2.5M5.4 10.4l1.6 1.4M18.6 10.4l-1.6 1.4"/></g>',
        calc: '<rect x="5" y="2.8" width="14" height="18.4" rx="3" fill="none" stroke="C" stroke-width="1.9"/><rect x="8" y="5.6" width="8" height="3.4" rx="0.8" fill="C"/><g fill="C"><circle cx="9" cy="12.5" r="1.1"/><circle cx="12" cy="12.5" r="1.1"/><circle cx="15" cy="12.5" r="1.1"/><circle cx="9" cy="15.5" r="1.1"/><circle cx="12" cy="15.5" r="1.1"/><circle cx="15" cy="15.5" r="1.1"/><circle cx="9" cy="18.4" r="1.1"/><circle cx="12" cy="18.4" r="1.1"/><circle cx="15" cy="18.4" r="1.1"/></g>',
        gauge: '<circle cx="12" cy="12.5" r="8.5" fill="none" stroke="C" stroke-width="1.9" stroke-dasharray="44 9.4" transform="rotate(115 12 12.5)"/><path d="M12 12.5L8.6 8.6" stroke="C" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="12.5" r="1.6" fill="C"/>',
        shot: '<g fill="none" stroke="C" stroke-width="1.9" stroke-linecap="round"><path d="M3 8V5.5A2.5 2.5 0 0 1 5.5 3H8M16 3h2.5A2.5 2.5 0 0 1 21 5.5V8M21 16v2.5a2.5 2.5 0 0 1-2.5 2.5H16M8 21H5.5A2.5 2.5 0 0 1 3 18.5V16"/></g><path fill="C" d="M8.6 9.2h1.5l.9-1.3h2l.9 1.3h1.5a1 1 0 0 1 1 1v4.6a1 1 0 0 1-1 1H8.6a1 1 0 0 1-1-1v-4.6a1 1 0 0 1 1-1z"/><circle cx="12" cy="12.5" r="1.6" fill="#00000000" stroke="#8a8a8a" stroke-width="0"/>',
        play: '<path fill="C" d="M7 4.6v14.8a1 1 0 0 0 1.5.9l11.6-7.4a1 1 0 0 0 0-1.8L8.5 3.7A1 1 0 0 0 7 4.6z"/>',
        pause: '<g fill="C"><rect x="6" y="4" width="4.2" height="16" rx="1.2"/><rect x="13.8" y="4" width="4.2" height="16" rx="1.2"/></g>',
        next: '<g fill="C"><path d="M2.5 6.4v11.2a.8.8 0 0 0 1.2.7l8.3-5.6a.8.8 0 0 0 0-1.4L3.7 5.7a.8.8 0 0 0-1.2.7z"/><path d="M12 6.4v11.2a.8.8 0 0 0 1.2.7l8.3-5.6a.8.8 0 0 0 0-1.4l-8.3-5.6a.8.8 0 0 0-1.2.7z"/></g>',
        prev: '<g fill="C" transform="matrix(-1 0 0 1 24 0)"><path d="M2.5 6.4v11.2a.8.8 0 0 0 1.2.7l8.3-5.6a.8.8 0 0 0 0-1.4L3.7 5.7a.8.8 0 0 0-1.2.7z"/><path d="M12 6.4v11.2a.8.8 0 0 0 1.2.7l8.3-5.6a.8.8 0 0 0 0-1.4l-8.3-5.6a.8.8 0 0 0-1.2.7z"/></g>',
        note: '<path fill="C" d="M9 17.5V6.2l10-2.2v11.5"/><path d="M9 17.5V6.2l10-2.2v11.5" fill="none" stroke="C" stroke-width="1.6"/><circle cx="6.8" cy="17.6" r="2.6" fill="C"/><circle cx="16.8" cy="15.6" r="2.6" fill="C"/>',
        lock: '<rect x="5.5" y="10.5" width="13" height="10" rx="2" fill="C"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5" fill="none" stroke="C" stroke-width="2"/>',
        back: '<path d="M15 4.5L7.5 12l7.5 7.5" fill="none" stroke="C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
        device: '<rect x="4" y="5" width="16" height="11" rx="2" fill="none" stroke="C" stroke-width="1.9"/><path d="M2.5 19h19" stroke="C" stroke-width="1.9" stroke-linecap="round"/>',
        headphones: '<path d="M4 15v-3a8 8 0 0 1 16 0v3" fill="none" stroke="C" stroke-width="1.9"/><rect x="3" y="14" width="5" height="7" rx="2" fill="C"/><rect x="16" y="14" width="5" height="7" rx="2" fill="C"/>'
    })
    function ic(name, color) {
        const body = (glyphs[name] || "").split('"C"').join('"' + color + '"')
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">' + body + '</svg>')
    }

    // ------------------------------------------------------------ backends
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.Handler { id: nm }
    PlasmaNM.NetworkStatus { id: netStatus }
    readonly property bool wifiOn: enabledConnections.wirelessEnabled
    property string wifiName: ""
    function refreshWifiName() {
        bridge.outputAsync("wifi", "LC_ALL=C nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless:' | head -1 | cut -d: -f2-")
    }
    Connections {
        target: bridge
        function onOutputReady(key, out) {
            if (key === "wifi") root.wifiName = out.trim()
            else if (key === "night") root.nightOn = out.trim() === "true"
        }
    }

    readonly property var bt: BluezQt.Manager
    readonly property bool btOn: bt.bluetoothOperational && !bt.bluetoothBlocked
    function setBluetooth(enable) {
        bt.bluetoothBlocked = !enable
        for (let i = 0; i < bt.adapters.length; ++i) bt.adapters[i].powered = enable
    }
    readonly property bool airplaneOn: !wifiOn && !btOn
    function setAirplane(on) { nm.enableWireless(!on); setBluetooth(!on) }

    NotificationManager.Settings { id: notif; live: true }
    property date nowTick: new Date()
    readonly property bool dndOn: {
        const u = notif.notificationsInhibitedUntil
        return (!!u && !isNaN(u.getTime()) && u > nowTick) || notif.notificationsInhibitedByApplication
    }
    function toggleDnd() {
        if (dndOn) {
            notif.notificationsInhibitedUntil = new Date(NaN)
            notif.revokeApplicationInhibitions()
        } else {
            const d = new Date(); d.setFullYear(d.getFullYear() + 1)
            notif.notificationsInhibitedUntil = d
        }
        notif.save()
        nowTick = new Date()
    }

    property bool nightOn: false
    function refreshNight() {
        bridge.outputAsync("night", "kreadconfig6 --file kwinrc --group NightColor --key Active --default false")
    }
    function toggleNight() {
        nightOn = !nightOn
        bridge.run("kwriteconfig6 --file kwinrc --group NightColor --key Active " + (nightOn ? "true" : "false")
                   + " && @QTBINS@/qdbus org.kde.KWin /KWin reconfigure")
    }

    Bright.ScreenBrightnessControl { id: brightnessCtl; isSilent: true }   // no HUD while dragging the CC slider (like macOS)

    readonly property var sink: Vol.PreferredDevice.sink
    readonly property int normalVolume: 65536

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: !!player && !!(player.track || player.identity)
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing

    // ------------------------------------------------------------ lifecycle
    function opened() {
        page = "main"
        nowTick = new Date()
        // row 0 is the multiplexer that follows whichever player is active/playing
        if (mpris.rowCount() > 0) mpris.currentIndex = 0
        refreshNight()
        refreshWifiName()
        intro.restart()
        Qt.callLater(pushShapes)
    }
    function launch(cmd) { bridge.dismiss(); bridge.run(cmd) }

    function collect(item, out) {
        if (!item || !item.visible || (item !== content && item.opacity < 0.05)) return
        if (item.isGlass === true) {
            const p = item.mapToItem(root, 0, 0)
            out.push([p.x, p.y, item.width, item.height, item.radius])
        }
        for (let i = 0; i < item.children.length; ++i) collect(item.children[i], out)
    }
    function pushShapes() {
        const out = []
        collect(content, out)
        bridge.setShapes(out)
    }
    onPageChanged: Qt.callLater(pushShapes)
    onHeightChanged: Qt.callLater(pushShapes)

    // ------------------------------------------------------------ components
    component Glass: Rectangle {
        id: gl
        readonly property bool isGlass: true
        property bool hoverable: true
        property alias hovered: gma.containsMouse
        signal clicked()
        radius: height / 2
        color: hoverable && gma.containsMouse ? root.glassHover : root.glassFill
        Behavior on color { ColorAnimation { duration: 120 } }
        // liquid glass rim: bright top edge, soft bottom edge
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.rimBottom
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fg(0.102) }
                GradientStop { position: 0.45; color: root.fg(0.000) }
            }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 0.5
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: "#00000000"
            Rectangle {   // top highlight line
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: parent.width - parent.radius * 1.2
                height: 1
                color: root.rimTop
                opacity: 0.55
            }
        }
        MouseArea {
            id: gma
            anchors.fill: parent
            hoverEnabled: gl.hoverable
            onClicked: gl.clicked()
        }
    }

    // circle toggle: white with blue glyph when on, glass with white glyph when off
    component CircleButton: Glass {
        id: cb
        property string glyph
        property bool on: false
        property real glyphScale: 0.42
        width: root.u; height: root.u
        color: on ? (root.light ? (hovered ? Qt.lighter(root.accent, 1.12) : root.accent) : (hovered ? Qt.rgba(1, 1, 1, 0.91) : "#ffffff")) : (hovered ? root.glassHover : root.glassFill)
        Image {
            anchors.centerIn: parent
            width: Math.round(cb.width * cb.glyphScale); height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: root.ic(cb.glyph, cb.on ? (root.light ? "#ffffff" : root.accent) : root.fgHex)
        }
    }

    // small circle used inside capsules (Wi-Fi / Focus)
    component InnerCircle: Rectangle {
        id: ic2
        property string glyph
        property bool on: false
        width: 44; height: 44; radius: 22
        color: on ? (root.light ? root.accent : "#ffffff") : root.fg(0.220)
        Image {
            anchors.centerIn: parent
            width: 21; height: 21
            sourceSize: Qt.size(48, 48)
            source: root.ic(ic2.glyph, ic2.on ? (root.light ? "#ffffff" : root.accent) : root.fgHex)
        }
    }

    component Title: Text {
        color: root.textMain
        font.family: root.fontName; font.pixelSize: 14; font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
    component Sub: Text {
        color: root.textDim
        font.family: root.fontName; font.pixelSize: 12
        elide: Text.ElideRight
    }

    // thin Tahoe slider with glyphs at both ends
    component ThinSlider: Item {
        id: ts
        property real value: 0
        property string leftGlyph
        property string rightGlyph
        property real leftSize: 14
        property real rightSize: 18
        property int rightReserve: 0
        signal moved(real v)
        signal leftClicked()
        height: 24
        // While dragging, draw the local position and send at most one update per 40 ms;
        // the system value (which arrives late) is shown again 400 ms after release.
        // Without this the fill jumped back to stale values while dragging.
        property bool dragging: false
        property real dragValue: 0
        property real pending: -1
        readonly property real shown: (dragging || settle.running) ? dragValue : value
        function request(v) {
            dragValue = v; pending = v
            if (!throttle.running) { flush(); throttle.start() }
        }
        function flush() { if (pending >= 0) { var v = pending; pending = -1; ts.moved(v) } }
        Timer { id: throttle; interval: 40; repeat: true
                onTriggered: { if (ts.pending >= 0) ts.flush(); else stop() } }
        Timer { id: settle; interval: 400 }
        Image {
            id: lg
            anchors.verticalCenter: parent.verticalCenter
            width: ts.leftSize; height: width; sourceSize: Qt.size(48, 48)
            source: root.ic(ts.leftGlyph, root.fgHex)
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: ts.leftClicked() }
        }
        Image {
            id: rg
            anchors.right: parent.right; anchors.rightMargin: ts.rightReserve
            anchors.verticalCenter: parent.verticalCenter
            width: ts.rightSize; height: width; sourceSize: Qt.size(48, 48)
            source: root.ic(ts.rightGlyph, root.fgHex)
        }
        Item {
            id: trackArea
            anchors.left: lg.right; anchors.leftMargin: 10
            anchors.right: rg.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 9; radius: 4.5
                color: root.fg(0.251)
                Rectangle {
                    width: Math.max(track.height, track.width * Math.min(1, Math.max(0, ts.shown)))
                    height: parent.height; radius: parent.radius
                    color: root.light ? "#3a3a3c" : "#ffffff"
                }
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                preventStealing: true
                function upd(mx) { ts.request(Math.min(1, Math.max(0, mx / width))) }
                onPressed: mouse => { ts.dragging = true; upd(mouse.x) }
                onPositionChanged: mouse => { if (pressed) upd(mouse.x) }
                onReleased: mouse => { upd(mouse.x); ts.flush(); ts.dragging = false; settle.restart() }
                onCanceled: { ts.flush(); ts.dragging = false; settle.restart() }
                onWheel: wheel => { ts.request(Math.min(1, Math.max(0, ts.shown + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))); settle.restart() }
            }
        }
    }

    // Tahoe switch
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled()
        width: 40; height: 24; radius: 12
        color: on ? root.accent : root.fg(0.271)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 20; height: 20; radius: 10; y: 2
            x: tg.on ? tg.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled() }
    }

    // ------------------------------------------------------------ content
    Item {
        id: content
        x: root.m; y: root.m
        width: root.fullW
        height: root.height - 2 * root.m
        transformOrigin: Item.TopRight

        ParallelAnimation {
            id: intro
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "scale"; from: 0.94; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            onFinished: root.pushShapes()
        }

        // ===================================================== MAIN GRID
        Item {
            id: mainGrid
            visible: root.page === "main"
            width: root.fullW
            height: 7 * root.u + 6 * root.g

            // --- Wi-Fi capsule (cols 0-1, row 0)
            Glass {
                x: 0; y: 0; width: root.w2; height: root.u
                onClicked: { root.page = "wifi"; nm.requestScan() }
                InnerCircle {
                    x: 9; anchors.verticalCenter: parent.verticalCenter
                    glyph: "wifi"; on: root.wifiOn
                    MouseArea { anchors.fill: parent; onClicked: nm.enableWireless(!root.wifiOn) }
                }
                Column {
                    x: 62; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 10
                    Title { text: "Wi-Fi"; width: parent.width }
                    Sub { text: root.wifiOn ? (root.wifiName || "Bağlı değil") : "Kapalı"; width: parent.width }
                }
            }

            // --- Bluetooth + Airplane circles (row 1)
            CircleButton {
                x: 0; y: root.u + root.g
                glyph: "bluetooth"; on: root.btOn
                onClicked: root.page = "bt"
            }
            CircleButton {
                x: root.u + root.g; y: root.u + root.g
                glyph: "airplane"; on: root.airplaneOn
                onClicked: root.setAirplane(!root.airplaneOn)
            }

            // --- Now Playing (cols 2-3, rows 0-1)
            Glass {
                x: root.w2 + root.g; y: 0; width: root.w2; height: root.w2
                radius: 28
                hoverable: false
                Rectangle {
                    id: art
                    x: 14; y: 14; width: 46; height: 46; radius: 10
                    color: root.fg(0.200); clip: true
                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Image {
                        anchors.centerIn: parent; width: 22; height: 22
                        sourceSize: Qt.size(48, 48)
                        visible: !root.player || !root.player.artUrl
                        source: root.ic("note", root.light ? "#6e6e73" : "#dcdce0")
                    }
                }
                Column {
                    x: 14; y: 66; width: parent.width - 24
                    Title {
                        width: parent.width; font.pixelSize: 13
                        text: root.hasPlayer ? (root.player.track || root.player.identity) : "Çalınan Yok"
                    }
                    Sub {
                        width: parent.width
                        text: root.hasPlayer ? (root.player.artist || root.player.identity) : " "
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 34
                    spacing: 14
                    opacity: root.hasPlayer ? 1 : 0.45
                    Repeater {
                        model: ["prev", "play", "next"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: 26; height: 24
                            Image {
                                anchors.centerIn: parent
                                width: index === 1 ? 22 : 24; height: width
                                sourceSize: Qt.size(48, 48)
                                source: root.ic(index === 1 ? (root.playing ? "pause" : "play") : modelData, root.fgHex)
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                onClicked: {
                                    if (!root.player) return
                                    if (index === 0) root.player.Previous()
                                    else if (index === 1) root.player.PlayPause()
                                    else root.player.Next()
                                }
                            }
                        }
                    }
                }
            }

            // --- Focus capsule (row 2)
            Glass {
                x: 0; y: 2 * (root.u + root.g); width: root.w2; height: root.u
                onClicked: root.toggleDnd()
                InnerCircle { x: 9; anchors.verticalCenter: parent.verticalCenter; glyph: "moon"; on: root.dndOn }
                Column {
                    x: 62; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 10
                    Title { text: "Odak"; width: parent.width }
                    Sub { text: "Rahatsız Etme"; visible: root.dndOn; width: parent.width }
                }
            }
            CircleButton {
                x: 2 * (root.u + root.g); y: 2 * (root.u + root.g)
                glyph: "stage"
                onClicked: root.launch("@QTBINS@/qdbus org.kde.kglobalaccel /component/kwin invokeShortcut Overview")
            }
            CircleButton {
                x: 3 * (root.u + root.g); y: 2 * (root.u + root.g)
                glyph: "mirror"
                onClicked: root.launch("kcmshell6 kcm_kscreen")
            }

            // --- Display (row 3)
            Glass {
                x: 0; y: 3 * (root.u + root.g); width: root.fullW; height: root.u
                radius: 26; hoverable: false
                Title { x: 18; y: 9; text: "Ekran" }
                Repeater {
                    id: displays
                    model: brightnessCtl.displays
                    delegate: ThinSlider {
                        required property string displayName
                        required property int brightness
                        required property int maxBrightness
                        required property int index
                        visible: index === 0
                        x: 16; y: 32; width: root.fullW - 32
                        leftGlyph: "sun"; rightGlyph: "sun"; leftSize: 14; rightSize: 19
                        value: maxBrightness > 0 ? brightness / maxBrightness : 0
                        onMoved: v => brightnessCtl.setBrightness(displayName, Math.max(1, Math.round(v * maxBrightness)))
                    }
                }
            }

            // --- Sound (row 4)
            Glass {
                x: 0; y: 4 * (root.u + root.g); width: root.fullW; height: root.u
                radius: 26; hoverable: false
                Title { x: 18; y: 9; text: "Ses" }
                ThinSlider {
                    x: 16; y: 32; width: root.fullW - 32
                    leftGlyph: "spkLow"; rightGlyph: "spkHigh"; leftSize: 16; rightSize: 20
                    rightReserve: 34
                    value: root.sink ? (root.sink.muted ? 0 : root.sink.volume / root.normalVolume) : 0
                    onMoved: v => { if (root.sink) { root.sink.muted = false; root.sink.volume = Math.round(v * root.normalVolume) } }
                    onLeftClicked: if (root.sink) root.sink.muted = !root.sink.muted
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 12
                    y: 30; width: 28; height: 28; radius: 14
                    color: root.fg(0.220)
                    Image {
                        anchors.centerIn: parent; width: 17; height: 17; sourceSize: Qt.size(48, 48)
                        source: root.ic("airplay", root.fgHex)
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.launch("kcmshell6 kcm_pulseaudio") }
                }
            }

            // --- bottom circles (row 5)
            Repeater {
                model: [
                    { glyph: "sunset", act: "night" },
                    { glyph: "calc", act: "kcalc" },
                    { glyph: "gauge", act: "plasma-systemmonitor" },
                    { glyph: "shot", act: "spectacle -r" }
                ]
                delegate: CircleButton {
                    required property var modelData
                    required property int index
                    x: index * (root.u + root.g); y: 5 * (root.u + root.g)
                    glyph: modelData.glyph
                    on: modelData.act === "night" && root.nightOn
                    onClicked: {
                        if (modelData.act === "night") root.toggleNight()
                        else root.launch(modelData.act)
                    }
                }
            }
            // --- Light / Dark appearance capsule (row 6) -> ~/.local/bin/tahoe-appearance (like macOS "Dark Mode")
            Glass {
                x: 0; y: 6 * (root.u + root.g); width: root.w2; height: root.u
                onClicked: bridge.run("\"$HOME/.local/bin/tahoe-appearance\" toggle")
                InnerCircle {
                    x: 9; anchors.verticalCenter: parent.verticalCenter
                    glyph: "appearance"; on: !root.light
                    MouseArea { anchors.fill: parent; onClicked: bridge.run("\"$HOME/.local/bin/tahoe-appearance\" toggle") }
                }
                Column {
                    x: 62; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 10
                    Title { text: "Görünüm"; width: parent.width }
                    Sub { text: root.light ? "Açık" : "Koyu"; width: parent.width }
                }
            }
        }


        // ===================================================== DETAIL (Wi-Fi / Bluetooth)
        Glass {
            id: detail
            visible: root.page !== "main"
            width: root.fullW
            radius: 26
            hoverable: false
            height: Math.min(470, header.height + Math.max(56, listView.contentHeight) + footer.height + 30)

            Item {
                id: header
                x: 0; y: 0; width: parent.width; height: 52
                Item {
                    x: 8; y: 10; width: 32; height: 32
                    Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(48, 48); source: root.ic("back", root.fgHex) }
                    MouseArea { anchors.fill: parent; onClicked: root.page = "main" }
                }
                Title {
                    x: 40; anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 15; font.weight: Font.Bold
                    text: root.page === "wifi" ? "Wi-Fi" : "Bluetooth"
                }
                Toggle {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.page === "wifi" ? root.wifiOn : root.btOn
                    onToggled: {
                        if (root.page === "wifi") nm.enableWireless(!root.wifiOn)
                        else root.setBluetooth(!root.btOn)
                    }
                }
                Rectangle { x: 14; y: parent.height - 1; width: parent.width - 28; height: 1; color: root.fg(0.149) }
            }

            PlasmaNM.NetworkModel { id: networkModel }
            PlasmaNM.AppletProxyModel { id: wifiProxy; sourceModel: networkModel }
            property string pwFor: ""

            ListView {
                id: listView
                x: 8; y: header.height + 6
                width: parent.width - 16
                height: parent.height - y - footer.height - 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.page === "wifi" ? (root.wifiOn ? wifiProxy : null) : (root.btOn ? root.bt.devices : null)
                onCountChanged: Qt.callLater(root.pushShapes)
                delegate: Loader {
                    id: dl
                    readonly property var rowModel: root.page === "bt" ? modelData : model
                    width: ListView.view.width
                    sourceComponent: root.page === "wifi" ? wifiRow : btRow
                }
                Text {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: root.page === "wifi" ? (root.wifiOn ? "Ağlar aranıyor…" : "Wi-Fi kapalı") : (root.btOn ? "Aygıt yok" : "Bluetooth kapalı")
                    color: root.textDim; font.family: root.fontName; font.pixelSize: 13
                }
            }

            Component {
                id: wifiRow
                Column {
                    readonly property var md: parent ? parent.rowModel : null
                    readonly property bool isWifi: md && md.Type === PlasmaNM.Enums.Wireless
                    readonly property bool active: md && md.ConnectionState === PlasmaNM.Enums.Activated
                    readonly property bool busy: md && md.ConnectionState === PlasmaNM.Enums.Activating
                    readonly property bool secured: md && md.SecurityType > PlasmaNM.Enums.NoneSecurity
                    readonly property string uniq: md ? md.ItemUniqueName : ""
                    width: parent ? parent.width : 0
                    visible: isWifi
                    height: isWifi ? implicitHeight : 0
                    Rectangle {
                        width: parent.width; height: 44; radius: 12
                        color: rowMa.containsMouse ? root.fg(0.122) : "transparent"
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 30; height: 30; radius: 15
                            color: parent.parent.active ? root.accent : root.fg(0.200)
                            Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(48, 48); source: root.ic("wifi", root.fgHex) }
                        }
                        Text {
                            x: 46; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46 - 40
                            text: parent.parent.md ? parent.parent.md.ItemUniqueName : ""
                            color: root.textMain; elide: Text.ElideRight
                            font.family: root.fontName; font.pixelSize: 13
                            font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                        }
                        Image {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13; height: 13; sourceSize: Qt.size(48, 48)
                            visible: parent.parent.secured
                            source: root.ic("lock", root.light ? "#6e6e73" : "#c4c4c8")
                        }
                        C.BusyIndicator {
                            anchors.right: parent.right; anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18; running: visible
                            visible: parent.parent.busy
                        }
                        MouseArea {
                            id: rowMa
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                const r = parent.parent, d = r.md
                                if (!d) return
                                if (r.active) nm.deactivateConnection(d.ConnectionPath, d.DevicePath)
                                else if (d.Uuid && d.Uuid.length) nm.activateConnection(d.ConnectionPath, d.DevicePath, d.SpecificPath)
                                else if (r.secured) detail.pwFor = (detail.pwFor === r.uniq ? "" : r.uniq)
                                else nm.addAndActivateConnection(d.DevicePath, d.SpecificPath)
                            }
                        }
                    }
                    Row {
                        visible: detail.pwFor === parent.uniq && parent.uniq !== ""
                        x: 46; spacing: 8; height: visible ? 40 : 0
                        C.TextField {
                            id: pw
                            width: 160; height: 30
                            echoMode: TextInput.Password
                            placeholderText: "Parola"
                            font.family: root.fontName
                            onVisibleChanged: if (visible) forceActiveFocus()
                            onAccepted: join.clicked()
                        }
                        Rectangle {
                            id: join
                            signal clicked()
                            width: 70; height: 30; radius: 15; color: root.accent
                            Text { anchors.centerIn: parent; text: "Katıl"; color: "white"; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: join.clicked() }
                            onClicked: {
                                const d = parent.parent.md
                                if (d && pw.text.length) nm.addAndActivateConnection(d.DevicePath, d.SpecificPath, pw.text)
                                detail.pwFor = ""
                            }
                        }
                    }
                }
            }

            Component {
                id: btRow
                Rectangle {
                    readonly property var dev: parent ? parent.rowModel : null
                    readonly property bool conn: !!dev && dev.connected
                    width: parent ? parent.width : 0
                    visible: !!dev && dev.paired
                    height: visible ? 44 : 0
                    radius: 12
                    color: bma.containsMouse ? root.fg(0.122) : "transparent"
                    Rectangle {
                        x: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30; radius: 15
                        color: parent.conn ? root.accent : root.fg(0.200)
                        Image {
                            anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(48, 48)
                            source: root.ic(parent.parent.dev && /audio|headset|head/i.test(String(parent.parent.dev.icon)) ? "headphones" : "device", root.fgHex)
                        }
                    }
                    Text {
                        x: 46; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 46 - 90
                        text: parent.dev ? parent.dev.name : ""
                        color: root.textMain; elide: Text.ElideRight
                        font.family: root.fontName; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.conn ? "Bağlı" : ""
                        color: root.textDim; font.family: root.fontName; font.pixelSize: 12
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            const d = parent.dev
                            if (!d) return
                            if (d.connected) d.disconnectFromDevice(); else d.connectToDevice()
                        }
                    }
                }
            }

            Item {
                id: footer
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                width: parent.width; height: 40
                Rectangle { x: 14; y: 0; width: parent.width - 28; height: 1; color: root.fg(0.149) }
                Rectangle {
                    x: 8; y: 5; width: parent.width - 16; height: 32; radius: 10
                    color: fma.containsMouse ? root.fg(0.122) : "transparent"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        text: root.page === "wifi" ? "Wi-Fi Ayarları…" : "Bluetooth Ayarları…"
                        color: root.textMain; font.family: root.fontName; font.pixelSize: 13
                    }
                    MouseArea {
                        id: fma; anchors.fill: parent; hoverEnabled: true
                        onClicked: root.launch(root.page === "wifi" ? "kcmshell6 kcm_networkmanagement" : "kcmshell6 kcm_bluetooth")
                    }
                }
            }
        }
    }
}
