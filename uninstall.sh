#!/usr/bin/env bash
# Remove fedora-kde-tahoe and restore the configuration saved by install.sh.
#   ./uninstall.sh            restore the newest backup
#   ./uninstall.sh FILE       restore a specific backup tarball
set -uo pipefail
STATE="$HOME/.local/state/fedora-kde-tahoe"
LS="$HOME/.local/share"; BIN="$HOME/.local/bin"; UNITS="$HOME/.config/systemd/user"
BK="${1:-$(cat "$STATE/last-backup" 2>/dev/null)}"

echo "==> Stopping Tahoe services"
for u in tahoe-cc.service tahoe-menus.service tahoe-osd.service spotlight-search.service \
         tahoe-health-sync.service konsole-hide-toolbars.path konsole-hide-toolbars.service; do
  systemctl --user disable --now "$u" >/dev/null 2>&1
  rm -f "$UNITS/$u"
done
rm -rf "$UNITS/plasma-krunner.service.d"
systemctl --user daemon-reload

echo "==> Removing Tahoe components"
rm -rf "$LS"/{spotlight-tahoe,tahoe-cc,tahoe-menus,tahoe-osd,tahoe-overrides} \
       "$LS"/plasma/plasmoids/{local.tahoe.appname,local.tahoe.controlcenter,local.tahoe.menuitem,local.tahoe.notifications,local.tahoe.search,local.desktop.persistentmenu} \
       "$LS"/kwin/scripts/{spotlight-center,tahoe-center-windows} "$LS/kwin/tabbox/tahoe" "$LS/kwin/effects/launchpad-smooth" \
       "$LS/plasma/shells/org.kde.plasma.desktop" "$LS/sounds/Tahoe-Glass" \
       "$LS"/applications/{local.spotlight.desktop,local.tahoecc.desktop,mac-trash.desktop,org.kde.konsole.desktop} \
       "$LS"/applications/local.dock-{1..9}.desktop \
       "$HOME/.config/fontconfig/conf.d/99-tahoe-rendering.conf" "$HOME/.config/plasma-workspace/env/wavetask.sh"
rm -f "$BIN"/{spotlight-search,tahoe-cc,dock-number,konsole-hide-toolbars,systemsettings-stable,tahoe-health-check,tahoe-kirigami-tabs}
rm -f "$LS"/icons/hicolor/scalable/places/tahoe-sb-*.svg

if [ -n "$BK" ] && [ -f "$BK" ]; then
  echo "==> Restoring configuration from $BK"
  systemctl --user stop plasma-plasmashell.service
  (cd "$HOME" && tar -xzf "$BK")
  systemctl --user start plasma-plasmashell.service
else
  echo "no backup found — panels and settings were left as they are"
fi
gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1

cat <<EOF
Done. The MacTahoe themes (vinceliuice) and the WaveTask dock stay installed; remove them with
their own uninstallers if you no longer want them. If you ran --kirigami-tabs, restore KDE's
originals with:  sudo dnf reinstall kf6-kirigami   (Arch: sudo pacman -S kirigami)
Log out and back in to finish.
EOF
