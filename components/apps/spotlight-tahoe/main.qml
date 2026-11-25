import QtQuick
import QtQuick.Controls as C
import QtQuick.Effects
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami

// macOS Tahoe style Spotlight — pill search bar + mode buttons + glass result panel
Item {
    id: root

    // ---------- geometry
    readonly property int m: 34              // transparent margin for shadows
    readonly property int cw: 720            // content width
    readonly property int barH: 58
    readonly property int btnD: 48
    readonly property int btnGap: 8
    readonly property int btnsW: 4 * btnD + 3 * btnGap
    readonly property int panelGap: 10
    readonly property int maxListH: 452
    readonly property int gridCols: 5
    readonly property int appsW: 600            // Tahoe "Applications" card width
    readonly property int gridRows: 4

    // ---------- palette (dark liquid glass)
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
    readonly property color glassFill: tone("#4a3a3a42", 0.62, "#8cf4f4f6", 0.86)      // clear liquid glass (bar)
    readonly property color panelFill: tone("#60323238", 0.70, "#a6f4f4f6", 0.90)      // a touch denser for legible results
    readonly property color glassEdge: root.fg(0.302)
    readonly property color textMain: light ? "#1d1d1f" : "#f5f5f7"
    readonly property color textDim: light ? "#6e6e73" : "#98989f"
    readonly property color selBlue: "#e01a6ae8"
    readonly property string fontName: "Inter"

    // ---------- state
    property int mode: 0   // 0 all, 1 apps, 2 files, 3 actions, 4 clipboard
    readonly property var modeIcons: ["search", "apps", "files", "actions", "clipboard"]
    readonly property var modeNames: ["", "Uygulamalar", "Dosyalar", "Eylemler", "Pano"]
    readonly property var placeholders: ["Spotlight'ta Ara", "Uygulamalarda Ara", "Dosyalarda Ara", "Eylemlerde Ara", "Pano Geçmişinde Ara"]
    property var localSrc: []
    property var appsCache: null
    property var appCats: []
    property var suggested: []
    property string catFilter: ""
    readonly property bool showSugg: useGrid && q.length === 0 && catFilter === "" && suggested.length > 0
    property bool pendingRun: false
    readonly property string q: field.text.trim()
    readonly property bool compact: mode === 0 && field.text.length === 0
    readonly property bool useGrid: mode === 1
    readonly property var listSource: mode === 0 ? milouAll : (mode === 2 && q.length > 0 ? milouFiles : localModel)
    readonly property bool panelShown: mode !== 1 && (mode !== 0 || q.length > 0)
    readonly property bool busy: (mode === 0 && milouAll.querying) || (mode === 2 && milouFiles.querying)
    // grow immediately, shrink only after results settle -> no jumping while typing
    property real shownH: 64
    onRawHChanged: {
        if (rawH >= shownH) { shrinkTimer.stop(); shownH = rawH }
        else shrinkTimer.restart()
    }
    Timer { id: shrinkTimer; interval: 180; onTriggered: if (!root.busy || list.count > 0) root.shownH = root.rawH; else restart() }
    readonly property real rawH: {
        if (useGrid) {
            const rows = Math.max(1, Math.min(gridRows, Math.ceil(grid.count / gridCols)))
            return 44 + rows * grid.cellHeight + 12
        }
        if (list.count === 0) return 64
        return Math.min(maxListH, list.contentHeight + 16)
    }

    width: cw + 2 * m
    readonly property int maxPanelH: Math.max(maxListH, 44 + gridRows * 104 + 12)
    height: m + barH + panelGap + maxPanelH + m   // fixed: window never resizes -> no flicker

    // ---------- API used from Python / D-Bus
    function opened() {
        appsCache = null
        mode = 0
        field.text = ""
        field.forceActiveFocus()
        intro.restart()
        Qt.callLater(pushShapes)
    }
    function search(text) { field.text = text; field.forceActiveFocus() }
    function resultCount() { return useGrid ? grid.count : list.count }
    function activateFirst() { if (useGrid) grid.currentIndex = 0; else list.currentIndex = 0; runCurrent() }
    function setMode(n) {
        mode = (mode === n) ? 0 : n
        field.text = ""
        loadLocal()
        field.forceActiveFocus()
    }

    // ---------- data
    ListModel { id: localModel }
    ListModel { id: appsModel }

    Milou.ResultsModel {
        id: milouAll
        limit: 24
        queryString: root.mode === 0 ? field.text : ""
        onQueryStringChanged: list.currentIndex = 0
        onModelReset: list.currentIndex = 0
        onQueryStringChangeRequested: (s, pos) => { field.text = s; field.cursorPosition = pos }
        onRowsInserted: if (root.pendingRun && root.mode === 0) { root.pendingRun = false; Qt.callLater(root.runCurrent) }
    }
    Milou.ResultsModel {
        id: milouFiles
        limit: 30
        singleRunner: "baloosearch"
        queryString: root.mode === 2 ? field.text : ""
        onQueryStringChanged: list.currentIndex = 0
    }

    function loadLocal() {
        if (mode === 2) localSrc = bridge.recentFiles()
        else if (mode === 3) localSrc = bridge.actions()
        else if (mode === 4) localSrc = bridge.clipboard()
        else localSrc = []
        if (mode === 1 && appsCache === null) {
            appsCache = bridge.apps(); appCats = bridge.appCategories(); suggested = bridge.suggestedApps()
        }
        if (mode !== 1) catFilter = ""
        refilter()
    }

    function refilter() {
        const needle = q.toLocaleLowerCase()
        if (mode === 1) {
            appsModel.clear()
            const src = appsCache || []
            const pre = [], mid = []
            for (let i = 0; i < src.length; i++) {
                const a = src[i]
                const n = a.name.toLocaleLowerCase()
                if (!needle.length && catFilter !== "" && a.cat !== catFilter) continue
                if (!needle.length || n.startsWith(needle)) pre.push(a)
                else if (n.indexOf(needle) >= 0 || a.generic.toLocaleLowerCase().indexOf(needle) >= 0 || a.keys.indexOf(needle) >= 0) mid.push(a)
            }
            pre.concat(mid).forEach(a => appsModel.append({ name: a.name, icon: a.icon, path: a.path }))
            grid.currentIndex = 0
            return
        }
        localModel.clear()
        for (let i = 0; i < localSrc.length; i++) {
            const it = localSrc[i]
            if (!needle.length || it.display.toLocaleLowerCase().indexOf(needle) >= 0 || (mode !== 4 && it.subtext.toLocaleLowerCase().indexOf(needle) >= 0))
                localModel.append(it)
        }
        list.currentIndex = 0
    }

    function catAt(i) {
        if (i < 0 || i >= list.count) return ""
        if (listSource === localModel) return localModel.get(i).category
        return listSource.data(listSource.index(i, 0), Milou.ResultsModel.CategoryRole) || ""
    }
    function headerFor(i) {
        if (listSource === milouAll) {
            if (i === 0) return "En İyi Sonuç"
            if (i === 1 || catAt(i) !== catAt(i - 1)) return catAt(i)
            return ""
        }
        return (i === 0 || catAt(i) !== catAt(i - 1)) ? catAt(i) : ""
    }

    function runCurrent() {
        if (useGrid) {
            if (grid.count === 0) return
            bridge.launchApp(appsModel.get(grid.currentIndex).path)
            bridge.dismiss()
            return
        }
        if (list.count === 0) {
            if (mode === 0 && milouAll.querying) pendingRun = true
            return
        }
        const i = Math.max(0, list.currentIndex)
        if (listSource === localModel) {
            const it = localModel.get(i)
            if (mode === 2) bridge.openPath(it.payload)
            else if (mode === 3) bridge.runAction(it.payload)
            else if (mode === 4) bridge.copyText(it.payload)
            bridge.dismiss()
        } else if (listSource.run(listSource.index(i, 0))) {
            bridge.dismiss()
        }
    }

    function move(delta) {
        if (useGrid) {
            const n = grid.currentIndex + delta
            if (n >= 0 && n < grid.count) grid.currentIndex = n
            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
            return
        }
        if (list.count === 0) return
        list.currentIndex = (list.currentIndex + delta + list.count) % list.count
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    // ---------- blur region sync
    function pushShapes() {
        if (useGrid) { bridge.setShapes([[m + appsCard.x, m + appsCard.y, appsCard.width, appsCard.height, appsCard.radius]]); return }
        const s = [[pill.x + m, pill.y + m, pill.width, pill.height, pill.height / 2]]
        for (let i = 0; i < btnRepeater.count; i++) {
            const b = btnRepeater.itemAt(i)
            if (b && b.opacity > 0.05) s.push([m + b.x + btnRow.x, m + btnRow.y + b.y, b.width, b.height, b.width / 2])
        }
        if (panelShown && panel.height > 4) s.push([m, m + panel.y, panel.width, panel.height, 26])
        bridge.setShapes(s)
    }
    onPanelShownChanged: { if (panelShown) { shrinkTimer.stop(); shownH = rawH } Qt.callLater(pushShapes) }
    onModeChanged: Qt.callLater(pushShapes)

    // click on transparent margin closes
    MouseArea { anchors.fill: parent; onClicked: bridge.dismiss() }

    // ---------- reusable glass surface
    component Glass: Item {
        id: g
        property real radius: height / 2
        property bool shadow: true
        property color fill: root.glassFill
        property bool bare: false        // keep children, hide the glass itself
        RectangularShadow {
            anchors.fill: parent
            visible: g.shadow && !g.bare
            radius: g.radius
            blur: 34
            spread: -2
            offset.y: 12
            color: "#59000000"
        }
        Rectangle {
            anchors.fill: parent
            radius: g.radius
            color: g.fill
            visible: !g.bare
        }
        // liquid-glass sheen: bright top edge fading downwards
        Rectangle {
            visible: !g.bare
            anchors.fill: parent
            radius: g.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fg(0.188) }
                GradientStop { position: 0.3; color: root.fg(0.051) }
                GradientStop { position: 0.75; color: root.fg(0.012) }
                GradientStop { position: 1.0; color: root.fg(0.000) }
            }
        }
        Rectangle {
            visible: !g.bare
            anchors.fill: parent
            radius: g.radius
            color: "transparent"
            border.width: 1
            border.color: root.glassEdge
        }
        // soft bottom inner rim
        Rectangle {
            visible: !g.bare
            anchors.fill: parent
            anchors.margins: 1
            radius: g.radius - 1
            color: "transparent"
            border.width: 1
            border.color: root.fg(0.051)
        }
    }

    component AppCell: Item {
        id: ac
        property string name
        property string icon
        property bool current: false
        signal activate()
        width: 112; height: 96
        Rectangle {
            anchors.fill: parent; anchors.margins: 3
            radius: 16
            color: ac.current ? root.fg(0.188) : (acm.containsMouse ? root.fg(0.078) : "transparent")
        }
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 54; height: 54
            source: ac.icon
            fallback: "application-x-executable"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 68
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            text: ac.name
            color: root.textMain
            font.family: root.fontName; font.pixelSize: 12
        }
        MouseArea { id: acm; anchors.fill: parent; hoverEnabled: true; onClicked: ac.activate() }
    }

    // =====================================================================
    Item {
        id: content
        x: root.m; y: root.m
        width: root.cw
        height: root.height - 2 * root.m
        transformOrigin: Item.Top

        ParallelAnimation {
            id: intro
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "scale"; from: 0.965; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        // ------------------------------------------------ Tahoe "Applications" card (mode 1)
        // one tall glass card: search header, category chips, suggestions, divider, A–Z grid
        Glass {
            id: appsCard
            x: (root.cw - root.appsW) / 2; y: 0
            width: root.appsW
            height: content.height
            radius: 30
            fill: root.panelFill
            opacity: root.useGrid ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }   // don't fall through to "dismiss"

            Item {
                id: appsBody
                y: root.barH; width: parent.width; height: parent.height - y

                // category chips
                ListView {
                    id: chips
                    x: 18; y: 0
                    width: parent.width - 36; height: root.q.length ? 0 : 28
                    visible: height > 0
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.appCats
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool on: root.catFilter === modelData
                        height: 26; width: ct.implicitWidth + 22; radius: 13
                        color: on ? root.fg(0.302) : (chm.containsMouse ? root.fg(0.141) : root.fg(0.078))
                        border.width: 1; border.color: on ? root.fg(0.349) : root.fg(0.122)
                        Text {
                            id: ct; anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.on ? root.textMain : (root.light ? "#3a3a3c" : "#c8c8ce")
                            font.family: root.fontName; font.pixelSize: 12; font.weight: Font.Medium
                        }
                        MouseArea {
                            id: chm; anchors.fill: parent; hoverEnabled: true
                            onClicked: { root.catFilter = chip.on ? "" : chip.modelData; root.refilter(); field.forceActiveFocus() }
                        }
                    }
                }

                // suggestions (most used apps) + divider
                Item {
                    id: sugg
                    y: chips.height + (chips.visible ? 10 : 0)
                    width: parent.width; height: root.showSugg ? 96 + 14 : 0
                    visible: height > 0
                    Row {
                        x: 18
                        Repeater {
                            model: root.suggested
                            delegate: AppCell {
                                required property var modelData
                                name: modelData.name; icon: modelData.icon
                                onActivate: { bridge.launchApp(modelData.path); bridge.dismiss() }
                            }
                        }
                    }
                    Rectangle { x: 20; y: 96 + 6; width: parent.width - 40; height: 1; color: root.fg(0.149) }
                }

                GridView {
                    id: grid
                    x: 18; y: sugg.y + sugg.height
                    width: parent.width - 36
                    height: parent.height - y - 10
                    clip: true
                    cellWidth: Math.floor(width / root.gridCols)
                    cellHeight: 96
                    model: appsModel
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    delegate: AppCell {
                        id: gcell
                        required property int index
                        required property var model
                        width: grid.cellWidth; height: grid.cellHeight
                        name: model.name; icon: model.icon
                        current: GridView.isCurrentItem && root.q.length > 0
                        onActivate: { grid.currentIndex = gcell.index; root.runCurrent() }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: "Sonuç Bulunamadı"
                        color: root.textDim
                        font.family: root.fontName; font.pixelSize: 15
                    }
                }
            }
        }

        // ------------------------------------------------ search pill
        Glass {
            id: pill
            x: root.useGrid ? (root.cw - root.appsW) / 2 : 0
            y: 0
            height: root.barH
            bare: root.useGrid          // becomes the header of the Applications card
            width: root.useGrid ? root.appsW : (root.compact ? root.cw - root.btnsW - 12 : root.cw)
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            onWidthChanged: root.pushShapes()

            MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

            Image {
                id: lead
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                sourceSize: Qt.size(44, 44)
                source: iconDir + root.modeIcons[root.mode] + ".svg"
                opacity: root.mode === 0 ? 0.62 : 0.95
            }

            C.TextField {
                id: field
                x: 54
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (hitIcon.visible || root.useGrid ? 60 : 22)
                height: 40
                background: Item {}
                padding: 0
                color: root.textMain
                selectionColor: "#5a0b5fd6"
                selectedTextColor: root.textMain
                placeholderText: root.placeholders[root.mode]
                placeholderTextColor: root.light ? Qt.rgba(0, 0, 0, 0.45) : (root.dim > 0 ? Qt.rgba(1, 1, 1, 0.55) : "#8a8a91")
                font.family: root.fontName
                font.pixelSize: 22
                font.weight: Font.Normal
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                onTextChanged: { if (root.mode !== 0) root.refilter(); root.pendingRun = false }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        if (field.text.length) field.text = ""
                        else if (root.mode !== 0) root.setMode(root.mode)
                        else bridge.dismiss()
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                        root.setMode(event.key - Qt.Key_0)
                    } else if (event.key === Qt.Key_Backspace && field.text.length === 0 && root.mode !== 0) {
                        root.setMode(root.mode)
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.runCurrent()
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.move(root.useGrid && event.key === Qt.Key_Down ? root.gridCols : 1)
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        root.move(root.useGrid && event.key === Qt.Key_Up ? -root.gridCols : -1)
                    } else if (root.useGrid && field.text.length === 0 && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                        root.move(event.key === Qt.Key_Left ? -1 : 1)
                    } else if (event.key === Qt.Key_Right && ghost.visible && field.cursorPosition === field.text.length) {
                        field.text = ghost.full
                    } else if (event.key === Qt.Key_PageDown) {
                        root.move(5)
                    } else if (event.key === Qt.Key_PageUp) {
                        root.move(-5)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                // inline completion of the top hit, like macOS
                Text {
                    id: ghost
                    readonly property string full: list.count > 0 && root.mode === 0 ? String(milouAll.data(milouAll.index(0, 0), Qt.DisplayRole) || "") : ""
                    readonly property string sub: list.count > 0 && root.mode === 0 ? String(milouAll.data(milouAll.index(0, 0), Milou.ResultsModel.SubtextRole) || "") : ""
                    visible: field.text.length > 0 && full.length >= field.text.length
                             && full.toLocaleLowerCase().startsWith(field.text.toLocaleLowerCase())
                             && field.cursorPosition === field.text.length && list.currentIndex === 0
                    x: field.contentWidth + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, field.width - x)
                    elide: Text.ElideRight
                    font: field.font
                    color: "#7a7a82"
                    textFormat: Text.PlainText
                    text: full.substring(field.text.length) + (sub.length ? " — " + sub : "")
                }
            }

            // Tahoe "⋯" button (Applications): opens the app store
            Rectangle {
                visible: root.useGrid
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                color: dma.containsMouse ? root.fg(0.141) : "transparent"
                border.width: 1.5; border.color: root.light ? "#8e8e93" : "#c8c8ce"
                Row {
                    anchors.centerIn: parent; spacing: 3
                    Repeater { model: 3; Rectangle { width: 3; height: 3; radius: 1.5; color: root.light ? "#3a3a3c" : "#e6e6ea" } }
                }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: { bridge.launchApp("/usr/share/applications/org.kde.discover.desktop"); bridge.dismiss() } }
            }

            Kirigami.Icon {
                id: hitIcon
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                visible: root.mode === 0 && list.count > 0 && field.text.length > 0
                source: visible ? milouAll.data(milouAll.index(Math.max(0, list.currentIndex), 0), Qt.DecorationRole) : ""
            }
        }

        // ------------------------------------------------ mode buttons
        Row {
            id: btnRow
            x: root.cw - root.btnsW
            y: (root.barH - root.btnD) / 2
            spacing: root.btnGap
            Repeater {
                id: btnRepeater
                model: 4
                delegate: Glass {
                    id: btn
                    required property int index
                    readonly property int modeId: index + 1
                    width: root.btnD; height: root.btnD
                    opacity: root.compact ? 1 : 0
                    scale: root.compact ? 1 : 0.6
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    onOpacityChanged: root.pushShapes()

                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: root.fgHex
                        opacity: bma.pressed ? 0.16 : bma.containsMouse ? 0.09 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        sourceSize: Qt.size(44, 44)
                        source: iconDir + root.modeIcons[btn.modeId] + ".svg"
                        opacity: bma.containsMouse ? 1 : 0.82
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.setMode(btn.modeId)
                    }
                    // tooltip
                    Rectangle {
                        visible: bma.containsMouse
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 9
                        width: tip.implicitWidth + 18; height: 24; radius: 7
                        color: "#ee2a2a2e"; border.color: root.fg(0.188)
                        Text {
                            id: tip
                            anchors.centerIn: parent
                            text: root.modeNames[btn.modeId] + "   ⌃" + btn.modeId
                            color: root.textMain; font.family: root.fontName; font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // ------------------------------------------------ results panel
        Glass {
            id: panel
            y: root.barH + root.panelGap
            width: root.cw
            radius: 26
            fill: root.panelFill
            height: root.panelShown ? root.shownH : 0
            opacity: root.panelShown ? 1 : 0
            visible: opacity > 0
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            onHeightChanged: root.pushShapes()

            // ---- list (all / files / actions / clipboard)
            ListView {
                id: list
                visible: !root.useGrid
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: root.useGrid ? null : root.listSource
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                currentIndex: 0
                onCountChanged: if (currentIndex >= count || currentIndex < 0) currentIndex = 0

                delegate: Column {
                    id: row
                    required property int index
                    required property var model
                    readonly property bool isTop: list.model === milouAll && index === 0
                    readonly property bool sel: ListView.isCurrentItem
                    readonly property string header: root.headerFor(index)
                    width: ListView.view.width

                    Item {
                        width: parent.width
                        height: row.header.length ? (row.index === 0 ? 26 : 34) : 0
                        visible: height > 0
                        Text {
                            x: 12
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 5
                            text: row.header
                            color: root.textDim
                            font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                    Rectangle {
                        id: cell
                        width: parent.width
                        height: row.isTop ? 54 : 40
                        radius: 11
                        color: row.sel ? root.selBlue : (rma.containsMouse ? root.fg(0.078) : "transparent")

                        Kirigami.Icon {
                            id: ico
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.isTop ? 38 : 26; height: width
                            source: row.model.decoration || "unknown"
                        }
                        Text {
                            id: title
                            anchors.left: ico.right; anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, cell.width - x - (subT.text.length ? Math.min(subT.implicitWidth, cell.width * 0.4) + 28 : 14))
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: String(row.model.display || "")
                            color: row.sel ? "#ffffff" : root.textMain
                            font.family: root.fontName
                            font.pixelSize: row.isTop ? 16 : 14
                            font.weight: row.isTop ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            id: subT
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, cell.width * 0.4)
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                            text: String(row.model.subtext || "")
                            color: row.sel ? "#d9e6ff" : root.textDim
                            font.family: root.fontName; font.pixelSize: 13
                        }
                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { list.currentIndex = row.index; root.runCurrent() }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0 && !root.busy && !shrinkTimer.running
                    text: (root.mode === 4 ? "Pano geçmişi boş" : "Sonuç Bulunamadı")
                    color: root.textDim
                    font.family: root.fontName; font.pixelSize: 15
                }
            }

        }
    }
}
