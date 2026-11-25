#!/usr/bin/env python3
"""Tahoe menu-bar tint: like macOS Tahoe, the transparent menu bar uses black text
over a light wallpaper and white text over a dark one.
Measures the wallpaper strip that lies under the top bar and publishes the result.
D-Bus: local.TahoeBar /Bar  tint() -> "light" (white text) | "dark" (black text)
       signal tintChanged(s)
Re-measures whenever plasma-org.kde.plasma.desktop-appletsrc changes."""
import sys, re, os
from pathlib import Path
from urllib.parse import unquote, urlparse
from PySide6.QtCore import QObject, Slot, Signal, ClassInfo, QTimer, QFileSystemWatcher, Qt, QRect, QSize
from PySide6.QtGui import QGuiApplication, QImage, QImageReader
from PySide6.QtDBus import QDBusConnection

CFG = Path.home() / '.config/plasma-org.kde.plasma.desktop-appletsrc'
BAR = 32            # top panel thickness (px)
THRESH = 0.58       # mean lightness above this -> black text

app = QGuiApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)
bus = QDBusConnection.sessionBus()
if bus.interface().isServiceRegistered('local.TahoeBar').value():
    sys.exit(0)

def parse_cfg():
    groups, cur = {}, None
    try:
        for line in CFG.read_text(encoding='utf-8', errors='replace').splitlines():
            if line.startswith('['):
                cur = tuple(re.findall(r'\[([^\]]*)\]', line)); groups.setdefault(cur, {})
            elif cur is not None and '=' in line:
                k, v = line.split('=', 1); groups[cur][k] = v
    except OSError:
        pass
    return groups

def wallpaper():
    """(plugin, settings) of the desktop containment on screen 0."""
    g = parse_cfg()
    for key, v in g.items():
        if len(key) == 2 and key[0] == 'Containments' and v.get('activityId') and v.get('lastScreen', '0') == '0':
            plug = v.get('wallpaperplugin', 'org.kde.image')
            return plug, g.get(key + ('Wallpaper', plug, 'General'), {})
    return None, {}

def resolve_image(s):
    p = unquote(urlparse(s).path) if s.startswith('file:') else s
    p = Path(p)
    if p.is_dir():   # wallpaper package: pick the largest image
        imgs = [f for f in (p / 'contents/images').glob('*') if f.is_file()]
        if not imgs: return None
        def area(f):
            m = re.match(r'(\d+)x(\d+)', f.stem); return int(m[1]) * int(m[2]) if m else 0
        return str(max(imgs, key=area))
    return str(p) if p.is_file() else None

def lightness_of(img):
    img = img.convertToFormat(QImage.Format_RGB32).scaled(160, 8, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
    tot, n = 0.0, 0
    for y in range(img.height()):
        for x in range(img.width()):
            c = img.pixelColor(x, y)
            tot += 0.299 * c.redF() + 0.587 * c.greenF() + 0.114 * c.blueF(); n += 1
    return tot / max(1, n)

def measure():
    scr = app.primaryScreen()
    W, H = (scr.size().width(), scr.size().height()) if scr else (1920, 1200)
    plug, s = wallpaper()
    if plug == 'org.kde.color':
        c = s.get('Color', '0,0,0').split(',')
        try: r, gg, b = [int(x) / 255 for x in c[:3]]
        except ValueError: return None
        return 0.299 * r + 0.587 * gg + 0.114 * b
    if plug != 'org.kde.image':
        return None
    path = resolve_image(s.get('Image', ''))
    if not path: return None
    rd = QImageReader(path); rd.setAutoTransform(True)
    sz = rd.size()
    if not sz.isValid():
        full = rd.read(); sz = full.size()
    iw, ih = sz.width(), sz.height()
    if iw <= 0 or ih <= 0: return None
    mode = int(s.get('FillMode', '2') or 2)
    # source rectangle (image px) that ends up under screen rows 0..BAR
    if mode == 0:                       # stretch
        src = QRect(0, 0, iw, max(1, round(BAR * ih / H)))
    elif mode == 6:                     # pad: centred, unscaled
        x0, y0 = (iw - W) // 2, (ih - H) // 2
        src = QRect(max(0, x0), max(0, y0), min(iw, W), BAR).intersected(QRect(0, 0, iw, ih))
        if src.isEmpty():               # image smaller than screen: bar shows the fill colour
            return None
    elif mode == 1:                     # fit: bar may show the background colour
        k = min(W / iw, H / ih); top = (H - ih * k) / 2
        if top >= BAR: return None
        src = QRect(0, 0, iw, max(1, round((BAR - top) / k)))
    else:                               # crop (2) and tiles: approximate as crop
        k = max(W / iw, H / ih); vw, vh = W / k, H / k
        src = QRect(round((iw - vw) / 2), round((ih - vh) / 2), round(vw), max(1, round(BAR / k)))
    rd = QImageReader(path); rd.setAutoTransform(True)
    rd.setClipRect(src)
    img = rd.read()
    if img.isNull(): return None
    return lightness_of(img)

@ClassInfo({'D-Bus Interface': 'local.TahoeBar'})
class Bar(QObject):
    tintChanged = Signal(str)
    def __init__(self):
        super().__init__(); self._tint = 'light'
    @Slot(result=str)
    def tint(self): return self._tint
    @Slot(result=float)
    def lightness(self): return self._l
    def update(self):
        try: l = measure()
        except Exception as e:
            print('measure failed:', e, file=sys.stderr); l = None
        self._l = -1.0 if l is None else l
        t = 'dark' if (l is not None and l > THRESH) else 'light'
        print(f'wallpaper lightness={self._l:.3f} -> {t}', flush=True)
        if t != self._tint:
            self._tint = t; self.tintChanged.emit(t)

bar = Bar(); bar._l = -1.0
bus.registerObject('/Bar', bar, QDBusConnection.ExportAllSlots | QDBusConnection.ExportAllSignals)
bus.registerService('local.TahoeBar')

deb = QTimer(); deb.setSingleShot(True); deb.setInterval(400); deb.timeout.connect(bar.update)
w = QFileSystemWatcher([str(CFG.parent)])
w.directoryChanged.connect(lambda _: deb.start())
def rewatch(_=None):
    if str(CFG) not in w.files() and CFG.exists(): w.addPath(str(CFG))
    deb.start()
w.fileChanged.connect(rewatch); rewatch()
bar.update()
sys.exit(app.exec())
