// KWin's placement shifts every new window +40/+24 px when it would cover
// another one ("cascade"), so windows drift to the bottom-right. Centre new
// top-level app windows on the work area instead (macOS behaviour).
// plasmashell popups (Tahoe notifications etc.) show up as normal windows on Wayland
const SKIP = ["org.kde.plasmashell", "plasmashell", "local.spotlight", "local.tahoecc", "local.tahoemenus", "local.tahoeosd"];
function center(w) {
    if (!w.normalWindow || w.transient || w.fullScreen || w.maximizeMode !== 0) return;
    if (SKIP.indexOf(String(w.resourceClass)) >= 0) return;
    const a = workspace.clientArea(KWin.PlacementArea, w);
    const g = w.frameGeometry;
    if (g.width >= a.width || g.height >= a.height) return;
    const x = Math.floor(a.x + (a.width - g.width) / 2);
    const y = Math.floor(a.y + (a.height - g.height) / 2);
    if (Math.abs(g.x - x) < 1 && Math.abs(g.y - y) < 1) return;
    w.frameGeometry = {x: x, y: y, width: g.width, height: g.height};
}
workspace.windowAdded.connect(center);
