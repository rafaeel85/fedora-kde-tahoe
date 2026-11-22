// Plasma desktop script: builds the Tahoe panel layout.
// Run by install.sh through org.kde.PlasmaShell.evaluateScript (plasmashell must be running).
// Existing panels are removed (install.sh backs up the old layout first).

panels().forEach(function (p) { p.remove(); });

function addApplet(panel, plugin, cfg) {
    var w = panel.addWidget(plugin);
    if (cfg) {
        w.currentConfigGroup = ["General"];
        for (var k in cfg) w.writeConfig(k, cfg[k]);
    }
    return w;
}

// ---- Menu bar (top) --------------------------------------------------------
var top = new Panel("org.kde.panel");
top.location = "top";
top.height = 32;
top.floating = false;
top.hiding = "none";

addApplet(top, "local.tahoe.menuitem", { kind: "apple" });
addApplet(top, "local.tahoe.appname");
var appmenu = addApplet(top, "org.kde.plasma.appmenu", { compactView: "false" });
appmenu.globalShortcut = "Meta+Alt+M";
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.marginsseparator");
var tray = addApplet(top, "org.kde.plasma.systemtray");
// status-notifier apps only (Discord, Steam, …); KDE's own tray applets live in the hidden panel below
tray.currentConfigGroup = ["General"];
tray.writeConfig("extraItems", "");
tray.writeConfig("showAllItems", "true");
addApplet(top, "local.tahoe.menuitem", { kind: "weather" });
addApplet(top, "local.tahoe.menuitem", { kind: "input" });
addApplet(top, "local.tahoe.menuitem", { kind: "battery" });
addApplet(top, "local.tahoe.menuitem", { kind: "wifi" });
top.addWidget("local.tahoe.controlcenter");
top.addWidget("local.tahoe.search");
addApplet(top, "local.tahoe.menuitem", { kind: "clock" });
top.addWidget("org.kde.plasma.marginsseparator");

// ---- Dock (bottom) ---------------------------------------------------------
var dock = new Panel("org.kde.panel");
dock.location = "bottom";
dock.height = 100;
dock.floating = true;
dock.lengthMode = "fit";
dock.hiding = "windowscover";
addApplet(dock, "org.vicko.wavetask", {
    skinName: "Tahoe Liquid",
    iconSize: "66",
    iconSpacing: "0",
    amplitud: "1.8",
    magnification: "60",
    showReflection: "false",
    indicateAudioStreams: "false",
    launchers: [
        "applications:org.kde.discover.desktop",
        "applications:firefox.desktop",
        "applications:systemsettings.desktop",
        "applications:org.kde.konsole.desktop",
        "preferred://filemanager",
        "applications:mac-trash.desktop"
    ].join(",")
});

// ---- Hidden left edge panel: KDE tray applets (kdeconnect, clipboard, …) + Tahoe notifications
var side = new Panel("org.kde.panel");
side.location = "left";
side.height = 32;
side.hiding = "autohide";
side.alignment = "right";   // bottom of the left edge
side.minimumLength = 36;
side.maximumLength = 36;
var hiddenTray = side.addWidget("org.kde.plasma.systemtray");
hiddenTray.currentConfigGroup = ["General"];
hiddenTray.writeConfig("extraItems", [
    "org.kde.kdeconnect", "org.kde.plasma.vault", "org.kde.plasma.cameraindicator",
    "org.kde.plasma.clipboard", "org.kde.plasma.devicenotifier", "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.mediacontroller", "local.tahoe.notifications", "org.kde.plasma.brightness",
    "org.kde.plasma.printmanager", "org.kde.plasma.keyboardindicator", "org.kde.kscreen",
    "org.kde.plasma.volume", "org.kde.plasma.bluetooth"
].join(","));
hiddenTray.writeConfig("hiddenItems", [
    "org.kde.plasma.volume", "org.kde.plasma.bluetooth", "org.kde.plasma.brightness",
    "org.kde.plasma.mediacontroller", "org.kde.plasma.clipboard", "org.kde.plasma.keyboardindicator"
].join(","));
