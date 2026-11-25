import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// macOS Tahoe HUD: a Control-Center-like glass module in the top-right corner
Item {
    id: root
    readonly property bool light: typeof glassTone !== "undefined" && glassTone.light   // system light mode

    readonly property int m: 22            // shadow margin (KWin script accounts for it)
    readonly property int cardW: 300
    readonly property string fontName: "Inter"

    width: cardW + 2 * m
    height: card.height + 2 * m

    property string mode: "progress"      // progress | text
    property string title: ""
    property string extra: ""
    property string iconName: ""
    property string glyph: "spkHigh"
    property real value: 0                 // 0..1 (may exceed 1 with overamplification)
    property real maxValue: 1

    // animated bar: shown value glides towards `value`
    property real shownValue: 0
    property bool animateBar: true
    property var lastValues: ({})          // last level per kind (Ses, Ekran, ...)
    property string lastKind: ""
    Behavior on shownValue {
        enabled: root.animateBar
        NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
    }
    onValueChanged: shownValue = value
    function setLevel(kind, v) {
        const hidden = card.opacity < 0.05 || kind !== lastKind;
        if (hidden) {
            // start from where this kind was last time (or empty), then slide to the new level
            animateBar = false;
            shownValue = (lastValues[kind] !== undefined) ? lastValues[kind] : 0;
            animateBar = true;
        }
        lastKind = kind;
        lastValues[kind] = v;
        if (value === v) shownValue = v; else value = v;
        if (hidden || Math.abs(v - shownValue) > 0.001) glyphPulse.restart();
    }

    // ---- SF-like glyphs ----
    readonly property var glyphs: ({
        spkOff:  '<path fill="C" d="M3 9.2h3L10 5.6v12.8l-4-3.6H3a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/><g stroke="C" stroke-width="1.9" stroke-linecap="round"><path d="M14.5 9.5l5 5M19.5 9.5l-5 5"/></g>',
        spkLow:  '<path fill="C" d="M3 9.2h3L10 5.6v12.8l-4-3.6H3a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/><path d="M13.5 9.2a4 4 0 0 1 0 5.6" fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"/>',
        spkMid:  '<path fill="C" d="M3 9.2h3L10 5.6v12.8l-4-3.6H3a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/><g fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M13.5 9.2a4 4 0 0 1 0 5.6"/><path d="M16.2 6.8a7.4 7.4 0 0 1 0 10.4"/></g>',
        spkHigh: '<path fill="C" d="M3 9.2h3L10 5.6v12.8l-4-3.6H3a1 1 0 0 1-1-1v-3.6a1 1 0 0 1 1-1z"/><g fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M13.5 9.2a4 4 0 0 1 0 5.6"/><path d="M16.2 6.8a7.4 7.4 0 0 1 0 10.4"/><path d="M18.9 4.4a10.8 10.8 0 0 1 0 15.2"/></g>',
        sun:     '<circle cx="12" cy="12" r="3.6" fill="none" stroke="C" stroke-width="1.8"/><g stroke="C" stroke-width="1.8" stroke-linecap="round"><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/></g>',
        mic:     '<rect x="8.5" y="2.8" width="7" height="12" rx="3.5" fill="C"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3.2" fill="none" stroke="C" stroke-width="1.8" stroke-linecap="round"/>',
        kbd:     '<rect x="2.5" y="6" width="19" height="12" rx="2.4" fill="none" stroke="C" stroke-width="1.8"/><g fill="C"><rect x="5.5" y="9" width="2" height="2" rx=".5"/><rect x="9" y="9" width="2" height="2" rx=".5"/><rect x="12.5" y="9" width="2" height="2" rx=".5"/><rect x="16" y="9" width="2" height="2" rx=".5"/><rect x="7.5" y="13" width="9" height="2" rx=".6"/></g>'
    })
    function glyphUrl(name, color) {
        const body = (glyphs[name] || "").replace(/="C"/g, '="' + color + '"');
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">' + body + '</svg>');
    }

    function show() {
        bridge.setShown(true);
        card.opacity = 1;
        hideTimer.restart();
        Qt.callLater(pushShapes);
    }
    function pushShapes() {
        bridge.setShapes([[card.x, card.y, card.width, card.height, card.radius]]);
    }

    function progress(icon, percent, maximum, extraText) {
        mode = "progress";
        iconName = icon;
        extra = extraText || "";
        maxValue = Math.max(100, maximum) / 100;
        const ic = icon || "";
        if (ic.indexOf("microphone") >= 0) { title = "Mikrofon"; glyph = "mic"; }
        else if (ic.indexOf("keyboard") >= 0) { title = "Klavye Aydınlatması"; glyph = "kbd"; }
        else if (ic.indexOf("brightness") >= 0 || ic.indexOf("display") >= 0) { title = "Ekran"; glyph = "sun"; }
        else if (ic.indexOf("audio") >= 0 || ic.indexOf("volume") >= 0) {
            title = "Ses";
            glyph = (percent <= 0 || ic.indexOf("muted") >= 0) ? "spkOff" : percent < 34 ? "spkLow" : percent < 67 ? "spkMid" : "spkHigh";
        } else { title = ""; glyph = ""; }
        setLevel(title || ic, Math.max(0, percent) / 100);
        show();
    }
    function text(icon, t) {
        mode = "text";
        iconName = icon;
        title = t;
        extra = "";
        const ic = icon || "";
        if (ic.indexOf("audio-volume-muted") >= 0) { mode = "progress"; title = "Ses"; glyph = "spkOff"; maxValue = 1; extra = t; setLevel("Ses", 0); }
        else if (ic.indexOf("microphone-sensitivity-muted") >= 0) { mode = "progress"; title = "Mikrofon"; glyph = "mic"; maxValue = 1; extra = t; setLevel("Mikrofon", 0); }
        show();
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: card.opacity = 0
    }

    MultiEffect {
        anchors.fill: card
        source: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.35
        shadowBlur: 0.9
        shadowVerticalOffset: 6
        blurMax: 32
        opacity: card.opacity
    }

    Rectangle {
        id: card
        x: root.m; y: root.m
        width: root.cardW
        height: root.mode === "progress" ? 70 : 52
        radius: 22
        opacity: 0
        color: root.light ? Qt.rgba(0.97, 0.97, 0.98, 0.80) : Qt.rgba(0.16, 0.16, 0.19, 0.42)
        border.width: 1
        border.color: root.light ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.18)
        onOpacityChanged: if (opacity === 0) bridge.setShown(false)
        Behavior on opacity { NumberAnimation { duration: card.opacity > 0.5 ? 350 : 120; easing.type: Easing.OutCubic } }
        onHeightChanged: Qt.callLater(root.pushShapes)

        // top sheen
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }

        // ---- text mode ----
        Row {
            visible: root.mode === "text"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            spacing: 10
            Kirigami.Icon {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconName
                isMask: true
                color: root.light ? "#1d1d1f" : "white"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.cardW - 60
                elide: Text.ElideRight
                text: root.title
                color: root.light ? "#1d1d1f" : "white"
                font.family: root.fontName
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        // ---- progress mode ----
        Item {
            visible: root.mode === "progress"
            anchors.fill: parent
            anchors.margins: 14

            Text {
                id: titleText
                anchors.left: parent.left
                anchors.top: parent.top
                text: root.title
                color: root.light ? "#1d1d1f" : "white"
                font.family: root.fontName
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: titleText.baseline
                anchors.left: titleText.right
                anchors.leftMargin: 10
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: root.extra
                color: root.light ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.6)
                font.family: root.fontName
                font.pixelSize: 11
            }

            // slider track (like Control Center)
            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                radius: 11
                color: root.light ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.18)
                clip: true

                Rectangle {
                    id: fill
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(parent.height, parent.width * Math.min(1, root.shownValue / root.maxValue))
                    color: root.light ? "#3a3a3c" : "white"
                }
                // over-amplification tint (>100%)
                Rectangle {
                    visible: root.maxValue > 1 && root.shownValue > 1
                    x: parent.width / root.maxValue
                    width: fill.width - x
                    height: parent.height
                    color: "#ff9f0a"
                    opacity: 0.85
                }
                Image {
                    id: glyphImg
                    visible: root.glyph !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    width: 16; height: 16
                    sourceSize: Qt.size(16, 16)
                    source: root.glyph ? root.glyphUrl(root.glyph, root.light ? "#ffffff" : "#5a5a60") : ""
                    SequentialAnimation {
                        id: glyphPulse
                        NumberAnimation { target: glyphImg; property: "scale"; to: 1.18; duration: 90; easing.type: Easing.OutQuad }
                        NumberAnimation { target: glyphImg; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.OutBack }
                    }
                }
            }
        }
    }
}
