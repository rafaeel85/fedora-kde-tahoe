#!/usr/bin/env bash
# kde-tahoe (formerly fedora-kde-tahoe) — macOS Tahoe look & feel for KDE Plasma 6 (Wayland).
# Supported: Fedora KDE; Arch Linux and Arch-based distros (EndeavourOS, CachyOS, Manjaro).
#
#   ./install.sh                  install everything for the current user
#   ./install.sh --no-layout      keep your current panels (skip menu bar + dock layout)
#   ./install.sh --kirigami-tabs  also patch System Settings tabs (writes system files, needs sudo)
#   ./install.sh --no-session     install files/settings only, don't touch the running session (tests/CI)
#   ./install.sh --skip-packages  don't install distro packages (you installed the dependencies yourself)
#
# A backup of your current desktop configuration is written first; ./uninstall.sh restores it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
C="$REPO/components"; O="$REPO/overlays"
LS="$HOME/.local/share"; BIN="$HOME/.local/bin"; UNITS="$HOME/.config/systemd/user"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/fedora-kde-tahoe"
STATE="$HOME/.local/state/fedora-kde-tahoe"   # old name kept so existing installs still find their backups

# Upstream projects, pinned to tested commits
MACTAHOE_KDE=cbf6a1f71b591d143184855d62f6272ce533e7c3
MACTAHOE_ICONS=839848b9a8a38a92a6936e30c4abe35cc6f2546d
MACTAHOE_GTK=1e45e19f510edb8cde18fa84d6cd5319f60b086b
WAVETASK=54c6a7669a54fcb49d617da30b6a3b746619739c

DO_LAYOUT=1; DO_KIRIGAMI=0; SESSION=1; DO_PKGS=1
for a in "$@"; do
  case "$a" in
    --no-layout) DO_LAYOUT=0 ;;
    --kirigami-tabs) DO_KIRIGAMI=1 ;;
    --no-session) SESSION=0; DO_LAYOUT=0 ;;
    --skip-packages) DO_PKGS=0 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*"; exit 1; }

# ---------------------------------------------------------------- checks
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root (sudo is asked for when needed)"
# distro family -> package manager
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *" fedora "*) DISTRO=fedora ;;
  *" arch "*)   DISTRO=arch ;;
  *) DISTRO=other ;;
esac
if [ "$DISTRO" = other ] && [ "$DO_PKGS" = 1 ]; then
  die "${PRETTY_NAME:-this distro} is not supported yet (Fedora, Arch and Arch-based only).
       Install the dependencies yourself (see README) and run: ./install.sh --skip-packages"
fi
echo "distro: ${PRETTY_NAME:-$ID} ($DISTRO)"
PV=$(QT_QPA_PLATFORM=offscreen plasmashell --version 2>/dev/null | awk '{print $2}' || true)
[ -n "$PV" ] || die "KDE Plasma (plasmashell) not found"
case "$PV" in 6.8.*) ;; *) warn "tested on Plasma 6.8, you have $PV — lock screen/logout overrides are checked and switched off automatically if they fail" ;; esac
[ "$SESSION" = 0 ] || [ "${XDG_SESSION_TYPE:-}" = wayland ] || warn "tested on Wayland only"
command -v git >/dev/null || die "git is required (Fedora: sudo dnf install git, Arch: sudo pacman -S git)"

# ---------------------------------------------------------------- backup
say "Backing up your current desktop configuration"
mkdir -p "$STATE"
BK="$STATE/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
(cd "$HOME" && tar --ignore-failed-read -czf "$BK" \
  .config/kdeglobals .config/kwinrc .config/kwinrulesrc .config/plasma-org.kde.plasma.desktop-appletsrc \
  .config/plasmashellrc .config/plasmarc .config/kcminputrc .config/kglobalshortcutsrc .config/plasmanotifyrc \
  .config/Kvantum .config/gtk-3.0 .config/gtk-4.0 .config/konsolerc .config/dolphinrc \
  .local/share/user-places.xbel 2>/dev/null) || true
echo "$BK" > "$STATE/last-backup"
# the FIRST backup is your pre-Tahoe desktop: keep pointing at it when install.sh is rerun to update
orig=$(cat "$STATE/original-backup" 2>/dev/null || true)
[ -n "$orig" ] && [ -f "$orig" ] || echo "$BK" > "$STATE/original-backup"
echo "saved: $BK (original desktop: $(cat "$STATE/original-backup"))"

# ---------------------------------------------------------------- packages
FEDORA_PKGS="git rsync kvantum python3-pyside6 python3-dbus python3-gobject python3-pillow rsms-inter-fonts
      source-foundry-hack-fonts kdeplasma-addons plasma-milou plasma-nm kf6-bluez-qt qt6-qt5compat
      cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel
      kf6-ki18n-devel kf6-kservice-devel kf6-kwindowsystem-devel kf6-kconfig-devel kf6-kconfigwidgets-devel
      kf6-knotifications-devel kf6-kio-devel kf6-kcoreaddons-devel kf6-kitemmodels-devel kf6-kglobalaccel-devel
      kf6-kxmlgui-devel libplasma-devel plasma-activities-devel plasma-activities-stats-devel
      plasma-workspace-devel libksysguard-devel kwin-devel libepoxy-devel libdrm-devel"
# Arch: KDE libraries ship their headers/CMake files in the main package (no -devel split)
ARCH_PKGS="git rsync xz kvantum pyside6 python-dbus python-gobject python-pillow inter-font ttf-hack
      kdeplasma-addons milou plasma-nm plasma-pa powerdevil plasma5support bluez-qt qt6-5compat qt6-tools
      gtk-update-icon-cache
      cmake extra-cmake-modules base-devel qt6-base qt6-declarative ki18n kservice kwindowsystem kconfig
      kconfigwidgets knotifications kio kcoreaddons kitemmodels kglobalaccel kxmlgui libplasma
      plasma-activities plasma-activities-stats plasma-workspace libksysguard kwin libepoxy libdrm vulkan-headers"
if [ "$DO_PKGS" = 1 ]; then
  say "Installing packages (sudo)"
  case "$DISTRO" in
    fedora)
      missing=$(for p in $FEDORA_PKGS; do rpm -q "$p" >/dev/null 2>&1 || echo "$p"; done)
      if [ -n "$missing" ]; then sudo dnf install -y $missing; else echo "all present"; fi ;;
    arch)
      missing=$(pacman -T $ARCH_PKGS || true)
      if [ -n "$missing" ]; then sudo pacman -S --needed --noconfirm $missing; else echo "all present"; fi ;;
  esac
fi

# Qt 6 locations differ per distro (/usr/lib64/qt6, /usr/lib/qt6, /usr/lib/<triplet>/qt6)
qtq() { local q
  for q in qtpaths6 qtpaths-qt6 /usr/lib/qt6/bin/qtpaths /usr/lib64/qt6/bin/qtpaths qtpaths; do
    command -v "$q" >/dev/null 2>&1 || continue
    case "$("$q" --query QT_VERSION 2>/dev/null)" in 6.*) "$q" --query "$1"; return ;; esac
  done; }
QTQML=$(qtq QT_INSTALL_QML || true); QTBINS=$(qtq QT_INSTALL_BINS || true)
for d in /usr/lib64/qt6 /usr/lib/qt6 /usr/lib/*/qt6; do
  [ -d "${QTQML:-/nonexistent}/org/kde/kirigami" ] || { [ -d "$d/qml/org/kde/kirigami" ] && QTQML=$d/qml; }
  [ -x "${QTBINS:-/nonexistent}/qdbus" ] || { [ -x "$d/bin/qdbus" ] && QTBINS=$d/bin; }
done
[ -d "${QTQML:-/nonexistent}/org/kde/kirigami" ] || die "Qt 6 QML directory with Kirigami not found"
[ -x "${QTBINS:-/nonexistent}/qdbus" ] || die "qdbus (Qt 6) not found — install your distro's Qt 6 tools package"
echo "Qt 6: qml=$QTQML bins=$QTBINS"

# ---------------------------------------------------------------- upstream sources
fetch() { # repo commit dir
  local d="$WORK/$3"
  if [ ! -d "$d/.git" ]; then git clone -q "https://github.com/$1.git" "$d"; fi
  git -C "$d" fetch -q --depth 1 origin "$2" 2>/dev/null || git -C "$d" fetch -q origin
  git -C "$d" checkout -q --force "$2"
}
say "Downloading upstream themes (vinceliuice MacTahoe) and WaveTask dock"
mkdir -p "$WORK"
fetch vinceliuice/MacTahoe-kde        "$MACTAHOE_KDE"   MacTahoe-kde
fetch vinceliuice/MacTahoe-icon-theme "$MACTAHOE_ICONS" MacTahoe-icon-theme
fetch vinceliuice/MacTahoe-gtk-theme  "$MACTAHOE_GTK"   MacTahoe-gtk-theme
fetch vickoc911/org.vicko.wavetask    "$WAVETASK"       wavetask

say "Installing MacTahoe themes"
(cd "$WORK/MacTahoe-kde" && ./install.sh)   # light + dark (tahoe-appearance switches between them)
(cd "$WORK/MacTahoe-icon-theme" && ./install.sh -d "$LS/icons" -t default)
(cd "$WORK/MacTahoe-icon-theme/cursors" && ./install.sh)
mkdir -p "$HOME/.themes"
tar -xJf "$WORK/MacTahoe-gtk-theme/release/MacTahoe-Dark.tar.xz" -C "$HOME/.themes"
tar -xJf "$WORK/MacTahoe-gtk-theme/release/MacTahoe-Light.tar.xz" -C "$HOME/.themes" 2>/dev/null || true

say "Applying Tahoe overlays on the themes"
# Plasma style "MacTahoe-Dark-Clear": transparent menu bar + SF-style tray icons
rm -rf "$LS/plasma/desktoptheme/MacTahoe-Dark-Clear"
cp -r "$LS/plasma/desktoptheme/MacTahoe-Dark" "$LS/plasma/desktoptheme/MacTahoe-Dark-Clear"
cp -r "$O/plasma-MacTahoe-Dark-Clear/." "$LS/plasma/desktoptheme/MacTahoe-Dark-Clear/"
# ... and its light twin "MacTahoe-Light-Clear" (used by tahoe-appearance light)
if [ -d "$LS/plasma/desktoptheme/MacTahoe-Light" ]; then
  rm -rf "$LS/plasma/desktoptheme/MacTahoe-Light-Clear"
  cp -r "$LS/plasma/desktoptheme/MacTahoe-Light" "$LS/plasma/desktoptheme/MacTahoe-Light-Clear"
  cp -r "$O/plasma-MacTahoe-Light-Clear/." "$LS/plasma/desktoptheme/MacTahoe-Light-Clear/"
fi
# Icons: SF-style Wi-Fi, volume, notification, tab icons
# (upstream links some size folders, e.g. preferences -> ../MacTahoe/…, so write through the link)
(cd "$O/icons-MacTahoe-dark" && find . -type f) | while read -r f; do
  d=$(readlink -m "$LS/icons/MacTahoe-dark/$(dirname "$f")"); mkdir -p "$d"
  cp -f --remove-destination "$O/icons-MacTahoe-dark/$f" "$d/$(basename "$f")"
done
gtk-update-icon-cache -f -t "$LS/icons/MacTahoe-dark" >/dev/null 2>&1 || true
# Kvantum: Tahoe pill tabs + Tahoe menus
mkdir -p "$HOME/.config/Kvantum/MacTahoe"
cp "$O/kvantum-MacTahoe/"* "$HOME/.config/Kvantum/MacTahoe/"
# Window decoration (Windows-style buttons on the right, MacTahoe look)
mkdir -p "$LS/aurorae/themes"; rm -rf "$LS/aurorae/themes/MacTahoe-Dark-Windows" "$LS/aurorae/themes/MacTahoe-Light-Windows"
cp -r "$C/aurorae/MacTahoe-Dark-Windows" "$C/aurorae/MacTahoe-Light-Windows" "$LS/aurorae/themes/"

say "Building and installing the WaveTask dock (into ~/.local)"
cmake -S "$WORK/wavetask" -B "$WORK/wavetask-build" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DKDE_INSTALL_QMLDIR=lib/qt6/qml -DKDE_INSTALL_PLUGINDIR=lib/qt6/plugins >/dev/null
cmake --build "$WORK/wavetask-build" -j"$(nproc)" >/dev/null
cmake --install "$WORK/wavetask-build" >/dev/null
cp -r "$O/wavetask/." "$LS/plasma/plasmoids/org.vicko.wavetask/"

# ---------------------------------------------------------------- Tahoe components
subst() { # replace placeholders in text files under $1
  local name; name=$(getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1); name=${name:-$(id -un)}
  (grep -rlIZ -e "@HOME@" -e "@USERNAME@" -e "@QTQML@" -e "@QTBINS@" "$1" 2>/dev/null | xargs -0 -r sed -i \
     -e "s|@HOME@|$HOME|g" -e "s|@USERNAME@|$name|g" -e "s|@QTQML@|$QTQML|g" -e "s|@QTBINS@|$QTBINS|g") || true
}
say "Installing Tahoe components"
mkdir -p "$BIN" "$UNITS" "$LS/plasma/plasmoids" "$LS/kwin/scripts" "$LS/kwin/tabbox" "$LS/kwin/effects" \
         "$LS/tahoe-overrides" "$LS/sounds" "$LS/applications" "$LS/icons/hicolor/scalable/places" \
         "$LS/konsole" "$LS/kxmlgui5/konsole" "$HOME/.config/fontconfig/conf.d" "$HOME/.config/plasma-workspace/env"
for a in "$C"/apps/*; do rm -rf "$LS/$(basename "$a")"; cp -r "$a" "$LS/"; subst "$LS/$(basename "$a")"; done
for p in "$C"/plasmoids/*; do rm -rf "$LS/plasma/plasmoids/$(basename "$p")"; cp -r "$p" "$LS/plasma/plasmoids/"; subst "$LS/plasma/plasmoids/$(basename "$p")"; done
cp -r "$C/kwin/scripts/." "$LS/kwin/scripts/"
rm -rf "$LS/kwin/tabbox/tahoe"; cp -r "$C/kwin/tabbox/tahoe" "$LS/kwin/tabbox/"
rm -rf "$LS/kwin/effects/launchpad-smooth"; cp -r "$C/kwin/effects/launchpad-smooth" "$LS/kwin/effects/"
rm -rf "$LS/tahoe-overrides/lockscreen" "$LS/tahoe-overrides/logout"
cp -r "$C/shell/lockscreen" "$C/shell/logout" "$LS/tahoe-overrides/"
rm -rf "$LS/sounds/Tahoe-Glass"; cp -r "$C/sounds/Tahoe-Glass" "$LS/sounds/"
install -m755 "$C"/bin/* "$BIN/"; subst "$BIN"
cp "$C"/systemd/*.service "$C"/systemd/*.path "$UNITS/"; cp -r "$C/systemd/plasma-krunner.service.d" "$UNITS/"; subst "$UNITS"
cp "$C"/applications/*.desktop "$LS/applications/"; subst "$LS/applications"
cp "$C"/icons/places/*.svg "$LS/icons/hicolor/scalable/places/"
cp "$C"/konsole/* "$LS/konsole/"; cp "$C"/kxmlgui5/*.rc "$LS/kxmlgui5/konsole/"
cp "$C/fontconfig/99-tahoe-rendering.conf" "$HOME/.config/fontconfig/conf.d/"
cp "$C/plasma-env/wavetask.sh" "$HOME/.config/plasma-workspace/env/"; subst "$HOME/.config/plasma-workspace/env"
mkdir -p "$HOME/.local/src/kirigami-tahoe"; rm -rf "$HOME/.local/src/kirigami-tahoe/patches"
cp -r "$C/kirigami/patches" "$HOME/.local/src/kirigami-tahoe/"
install -m755 "$C/kirigami/tahoe-kirigami-tabs" "$BIN/"; subst "$BIN"

# ---------------------------------------------------------------- settings
say "Applying settings"
kw() { kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }
kw kdeglobals General ColorScheme MacTahoeDark
kw kdeglobals General XftSubPixel none
kw kdeglobals General XftHintStyle hintslight
kw kdeglobals General font "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals General menuFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals General toolBarFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals General smallestReadableFont "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals General fixed "Hack,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals WM activeFont "Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"
kw kdeglobals Icons Theme MacTahoe-dark
kw kdeglobals KDE LookAndFeelPackage com.github.vinceliuice.MacTahoe-Dark
kw kdeglobals KDE widgetStyle kvantum-dark
kw kdeglobals Sounds Theme Tahoe-Glass
kw plasmarc Theme name MacTahoe-Dark-Clear
kw kcminputrc Mouse cursorTheme MacTahoe-cursors
kw Kvantum/kvantum.kvconfig General theme MacTahoeDark
kw plasmanotifyrc Notifications PopupPosition TopRight
# KWin
kw kwinrc org.kde.kdecoration2 library org.kde.kwin.aurorae.v2
kw kwinrc org.kde.kdecoration2 theme __aurorae__svg__MacTahoe-Dark-Windows
kw kwinrc org.kde.kdecoration2 ButtonsOnLeft M
kw kwinrc org.kde.kdecoration2 ButtonsOnRight IAX
kw kwinrc org.kde.kdecoration2 BorderSize Tiny
kw kwinrc TabBox LayoutName tahoe
kw kwinrc TabBox ApplicationsMode 1
kw kwinrc TabBox HighlightWindows false
for e in blur contrast magiclamp sheet slide launchpad-smooth spotlight-center tahoe-center-windows; do kw kwinrc Plugins "${e}Enabled" true; done
for e in squash dialogparent; do kw kwinrc Plugins "${e}Enabled" false; done
kw kwinrc Effect-magiclamp AnimationDuration 450
kw kwinrc Effect-blur Saturation 100
kw kwinrc Effect-overview BorderActivate 5
kw kwinrc ElectricBorders BottomRight ShowDesktop
kw kwinrc ScreenEdges RemainActiveOnFullscreen true
# Tahoe OSD must never take focus (otherwise Control Center closes on volume change)
kw kwinrulesrc tahoe-osd-nofocus Description "Tahoe OSD - never take focus"
kw kwinrulesrc tahoe-osd-nofocus wmclass local.tahoeosd
kw kwinrulesrc tahoe-osd-nofocus wmclassmatch 1
kw kwinrulesrc tahoe-osd-nofocus acceptfocus false
kw kwinrulesrc tahoe-osd-nofocus acceptfocusrule 2
kw kwinrulesrc tahoe-osd-nofocus skiptaskbar true
kw kwinrulesrc tahoe-osd-nofocus skiptaskbarrule 2
kw kwinrulesrc tahoe-osd-nofocus skipswitcher true
kw kwinrulesrc tahoe-osd-nofocus skipswitcherrule 2
kw kwinrulesrc tahoe-osd-nofocus above true
kw kwinrulesrc tahoe-osd-nofocus aboverule 2
order=$(kreadconfig6 --file kwinrulesrc --group General --key Order)
case ",$order," in *,tahoe-osd-nofocus,*) ;; *) kw kwinrulesrc General Order "${order:+$order,}tahoe-osd-nofocus" ;; esac
# Meta+1..9 open Dock items (local.dock-N.desktop) -> take the keys away from Plasma's task-manager entries
for n in 1 2 3 4 5 6 7 8 9; do
  if [ "$SESSION" = 1 ]; then
    gdbus call --session -d org.kde.kglobalaccel -o /kglobalaccel -m org.kde.KGlobalAccel.setForeignShortcutKeys \
      "['plasmashell','activate task manager entry $n','','']" "@ai []" >/dev/null 2>&1 || true
  else
    kw kglobalshortcutsrc plasmashell "activate task manager entry $n" "none,Meta+$n,Activate Task Manager Entry $n"
  fi
done
# Konsole = Terminal
kw konsolerc "Desktop Entry" DefaultProfile SequoiaGlass.profile
# GTK apps
for v in 3.0 4.0; do
  mkdir -p "$HOME/.config/gtk-$v"
  kw "$HOME/.config/gtk-$v/settings.ini" Settings gtk-theme-name MacTahoe-Dark
  kw "$HOME/.config/gtk-$v/settings.ini" Settings gtk-icon-theme-name MacTahoe-dark
  kw "$HOME/.config/gtk-$v/settings.ini" Settings gtk-cursor-theme-name MacTahoe-cursors
  kw "$HOME/.config/gtk-$v/settings.ini" Settings gtk-font-name "Inter 10"
  kw "$HOME/.config/gtk-$v/settings.ini" Settings gtk-decoration-layout "icon:minimize,maximize,close"
done
if command -v flatpak >/dev/null; then
  flatpak override --user --env=GTK_THEME=MacTahoe-Dark --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-data/icons:ro --filesystem=~/.themes:ro --filesystem=xdg-config/fontconfig:ro || true
fi

# ---------------------------------------------------------------- services
say "Enabling Tahoe services"
if [ "$SESSION" = 1 ]; then
systemctl --user daemon-reload
systemctl --user enable tahoe-cc.service tahoe-menus.service tahoe-osd.service tahoe-bartint.service spotlight-search.service \
  tahoe-health-sync.service konsole-hide-toolbars.path >/dev/null 2>&1 || true
fi
"$BIN/tahoe-health-check" --sync
kbuildsycoca6 >/dev/null 2>&1 || true
fc-cache -f >/dev/null 2>&1 || true

if [ "$DO_KIRIGAMI" = 1 ]; then
  say "Patching System Settings tabs (sudo)"
  sudo "$BIN/tahoe-kirigami-tabs"
fi

# ---------------------------------------------------------------- layout + reload
if [ "$DO_LAYOUT" = 1 ]; then
  say "Creating the Tahoe menu bar and dock"
  gdbus call --session -d org.kde.plasmashell -o /PlasmaShell -m org.kde.PlasmaShell.evaluateScript \
    "$(cat "$REPO/config/layout.js")" >/dev/null
  plasma-apply-wallpaperimage "$LS/wallpapers/MacTahoe-Dark" >/dev/null 2>&1 || true
fi
if [ "$SESSION" = 1 ]; then
  gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1 || true
  for s in tahoe-cc tahoe-menus tahoe-osd tahoe-bartint spotlight-search; do systemctl --user restart "$s" || true; done
  systemctl --user restart plasma-plasmashell.service || true
fi

say "Done"
case "$DISTRO" in
  arch) BLUR="AUR package kwin-effects-better-blur-dx (e.g. yay -S kwin-effects-better-blur-dx)" ;;
  *)    BLUR="sudo dnf copr enable infinality/kwin-effects-better-blur-dx && sudo dnf install kwin-effects-better-blur-dx" ;;
esac
cat <<EOF
Log out and back in once so every app picks up the new style.
  * Spotlight: Meta+X        * Alt+Tab: Tahoe switcher      * Overview: Meta+W
  * Check / auto-repair after a Plasma update:   tahoe-health-check --full
  * Undo everything:                              $REPO/uninstall.sh
Optional (real blur behind translucent windows):
  $BLUR
EOF
