// Places the Spotlight window (centred, upper part of the screen) and the
// Tahoe Control Center window (top-right, under the menu bar).
const SPOT_MARGIN = 34;   // transparent shadow margin of Spotlight
const CC_MARGIN = 22;     // transparent shadow margin of the Control Center
const MENUBAR = 32;
const MENU_MARGIN = 22;  // transparent margin of the Tahoe menus window
const OSD_MARGIN = 22;    // transparent shadow margin of the Tahoe OSD
function attach(w) {
    const cls = String(w.resourceClass);
    // plasmashell's own OSD is replaced by tahoe-osd: keep it invisible
    if (w.onScreenDisplay && (cls === "plasmashell" || cls === "org.kde.plasmashell")) { w.opacity = 0; w.keepBelow = true; return; }
    // Tahoe notification popups (plasmashell Dialogs) arrive as plain normal
    // windows on Wayland, so their QML x/y is ignored and KWin centres them.
    // The plasmoid writes the wanted position into the title: "tahoe-notification@x,y".
    if ((cls === "plasmashell" || cls === "org.kde.plasmashell") && String(w.caption).indexOf("tahoe-notification@") === 0) {
        w.skipTaskbar = true; w.skipSwitcher = true; w.skipPager = true; w.keepAbove = true;
        let busy = false;
        const placeN = function () {
            const m = /@(-?\d+),(-?\d+)/.exec(String(w.caption));
            if (!m || busy) return;
            const g = w.frameGeometry, x = parseInt(m[1]), y = parseInt(m[2]);
            if (g.x === x && g.y === y) return;
            busy = true; w.frameGeometry = {x: x, y: y, width: g.width, height: g.height}; busy = false;
        };
        w.captionChanged.connect(placeN);
        w.frameGeometryChanged.connect(placeN);
        placeN();
        return;
    }
    if (cls !== "local.spotlight" && cls !== "local.tahoecc" && cls !== "local.tahoemenus" && cls !== "local.tahoeosd") return;
    // keep these helper windows out of the dock, Alt+Tab and pager
    w.skipTaskbar = true; w.skipSwitcher = true; w.skipPager = true;
    // Wayland ignores Qt WindowStaysOnTopHint: without this the OSD (never focused)
    // opened BEHIND app windows and was only visible on the empty desktop
    w.keepAbove = true;
    // the client may reset the state right after mapping -> re-assert it
    w.keepAboveChanged.connect(function () { if (!w.keepAbove) w.keepAbove = true; });
    let moving = false;
    function place() {
        if (moving) return;
        if (!w.keepAbove) w.keepAbove = true;
        const area = w.output.geometry;
        const g = w.frameGeometry;
        let x, y;
        if (cls === "local.tahoemenus") {
            // fixed full-width window; the menu glass is positioned inside it by QML (anchor x from the caption)
            x = area.x;
            y = Math.round(area.y + MENUBAR + 4 - MENU_MARGIN);
        } else if (cls === "local.tahoeosd") {
            x = Math.round(area.x + area.width - g.width + OSD_MARGIN - 8);
            y = Math.round(area.y + MENUBAR + 6 - OSD_MARGIN);
        } else if (cls === "local.spotlight") {
            x = Math.round(area.x + (area.width - g.width) / 2);
            y = Math.round(area.y + area.height * 0.2 - SPOT_MARGIN);
        } else {
            x = Math.round(area.x + area.width - g.width + CC_MARGIN - 8);
            y = Math.round(area.y + MENUBAR + 6 - CC_MARGIN);
        }
        if (g.x === x && g.y === y) return;
        moving = true;
        w.frameGeometry = {x: x, y: y, width: g.width, height: g.height};
        moving = false;
    }
    w.frameGeometryChanged.connect(place);
    if (cls === "local.tahoemenus") w.captionChanged.connect(place);
    w.outputChanged.connect(place);
    place();
}
workspace.windowAdded.connect(attach);
workspace.windowList().forEach(attach);
