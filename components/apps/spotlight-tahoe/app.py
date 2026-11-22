#!/usr/bin/env python3
"""macOS Tahoe style Spotlight for KDE Plasma (Wayland). D-Bus: local.Spotlight /Search"""
import sys, os, ctypes, sqlite3, subprocess, configparser, locale
from pathlib import Path
from PySide6.QtCore import QObject, Slot, Signal, ClassInfo, QUrl, QTimer, Qt, QMimeDatabase
from PySide6.QtGui import QColor, QRegion, QPainterPath, QFont
from PySide6.QtQuick import QQuickView
from PySide6.QtDBus import QDBusConnection, QDBusInterface
from PySide6.QtWidgets import QApplication
import shiboken6

HERE = Path(__file__).resolve().parent
HOME = Path.home()

app = QApplication(sys.argv)
app.setDesktopFileName('local.spotlight')
app.setApplicationName('Spotlight Search')
app.setQuitOnLastWindowClosed(False)
app.setQuitLockEnabled(False)
app.setFont(QFont('Inter', 10))

bus = QDBusConnection.sessionBus()
if bus.interface().isServiceRegistered('local.Spotlight').value():
    QDBusInterface('local.Spotlight', '/Search', 'local.Spotlight', bus).call('display')
    sys.exit(0)


def spawn(args):
    try:
        subprocess.Popen(args, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print('spawn failed', args, e, flush=True)


# ---------------------------------------------------------------- applications
LANGS = []
_l = (os.environ.get('LANGUAGE') or os.environ.get('LC_MESSAGES') or os.environ.get('LANG') or '').split(':')[0].split('.')[0]
if _l:
    LANGS = [_l, _l.split('_')[0]]


def app_dirs():
    dirs = [os.environ.get('XDG_DATA_HOME', str(HOME / '.local/share'))]
    dirs += os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
    dirs += [str(HOME / '.local/share/flatpak/exports/share'), '/var/lib/flatpak/exports/share']
    seen, out = set(), []
    for d in dirs:
        p = Path(d) / 'applications'
        if p.is_dir() and str(p) not in seen:
            seen.add(str(p)); out.append(p)
    return out


def localized(sec, key):
    for l in LANGS:
        v = sec.get(f'{key}[{l}]')
        if v:
            return v
    return sec.get(key, '')


# Tahoe Spotlight "Applications" chips (App Store style categories, Turkish macOS names)
CAT_ORDER = ['Araçlar', 'Sosyal', 'İnternet', 'Verimlilik ve Finans', 'Fotoğraf ve Video', 'Müzik',
             'Geliştirici Araçları', 'Oyunlar', 'Eğitim', 'Diğer']


def app_category(cats):
    c = set(x for x in cats.split(';') if x)
    if 'Game' in c: return 'Oyunlar'
    if 'Development' in c: return 'Geliştirici Araçları'
    if c & {'Chat', 'InstantMessaging', 'Email', 'VideoConference', 'IRCClient'}: return 'Sosyal'
    if c & {'Graphics', 'Photography', 'Video', '2DGraphics', '3DGraphics', 'RasterGraphics', 'VectorGraphics'}: return 'Fotoğraf ve Video'
    if c & {'Audio', 'Music', 'Player'} or 'AudioVideo' in c: return 'Müzik'
    if c & {'WebBrowser', 'Network', 'FileTransfer', 'P2P'}: return 'İnternet'
    if c & {'Office', 'Finance', 'ProjectManagement', 'WordProcessor', 'Spreadsheet', 'Presentation', 'Calendar'}: return 'Verimlilik ve Finans'
    if c & {'Education', 'Science', 'Math'}: return 'Eğitim'
    if c & {'Utility', 'System', 'Settings', 'Accessibility', 'Archiving', 'TextEditor', 'FileManager', 'Monitor'}: return 'Araçlar'
    return 'Diğer'


def suggested_ids(limit=5):
    """most used apps (KActivities score cache, read-only)"""
    import sqlite3
    db = Path.home() / '.local/share/kactivitymanagerd/resources/database'
    try:
        c = sqlite3.connect(f'file:{db}?mode=ro', uri=True, timeout=0.3)
        rows = c.execute("select targettedResource, sum(cachedScore) s from ResourceScoreCache "
                         "where targettedResource like 'applications:%' group by targettedResource "
                         "order by s desc limit 30").fetchall()
        c.close()
        return [r[0].split(':', 1)[1] for r in rows]
    except Exception:
        return []


def scan_apps():
    apps, ids = [], set()
    for base in app_dirs():
        for f in sorted(base.rglob('*.desktop')):
            did = str(f.relative_to(base)).replace('/', '-')
            if did in ids:
                continue
            ids.add(did)
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(f, encoding='utf-8')
                s = cp['Desktop Entry']
            except Exception:
                continue
            if s.get('Type') != 'Application' or s.get('NoDisplay', '').lower() == 'true' or s.get('Hidden', '').lower() == 'true':
                continue
            only, notin = s.get('OnlyShowIn', ''), s.get('NotShowIn', '')
            if only and 'KDE' not in only.split(';'):
                continue
            if 'KDE' in notin.split(';'):
                continue
            name = localized(s, 'Name')
            if not name or did == 'local.spotlight.desktop':
                continue
            apps.append({'name': name, 'icon': s.get('Icon', 'application-x-executable'),
                         'generic': localized(s, 'GenericName'),
                         'keys': (localized(s, 'Keywords') + ' ' + s.get('Exec', '').split(' ')[0].split('/')[-1]).lower(),
                         'path': str(f), 'id': did, 'cat': app_category(s.get('Categories', ''))})
    apps.sort(key=lambda a: a['name'].casefold())
    return apps


# ---------------------------------------------------------------- recent files
mimedb = QMimeDatabase()


def recent_files(limit=40):
    out = []
    db = HOME / '.local/share/kactivitymanagerd/resources/database'
    try:
        c = sqlite3.connect(f'file:{db}?mode=ro', uri=True, timeout=1)
        rows = c.execute('select targettedResource, max(lastUpdate) m from ResourceScoreCache '
                         "where targettedResource like '/%' group by targettedResource order by m desc limit 200").fetchall()
        c.close()
    except Exception as e:
        print('recent db', e, flush=True); rows = []
    for path, _ in rows:
        p = Path(path)
        if not p.exists() or p.name.startswith('.'):
            continue
        mt = mimedb.mimeTypeForFile(str(p))
        icon = 'folder' if p.is_dir() else (mt.iconName() if mt.isValid() else 'text-x-generic')
        parent = str(p.parent).replace(str(HOME), '~', 1)
        out.append({'display': p.name or str(p), 'decoration': icon, 'subtext': parent,
                    'category': 'Son Kullanılanlar', 'payload': str(p)})
        if len(out) >= limit:
            break
    return out


# ---------------------------------------------------------------- actions
QDBUS = '/usr/lib64/qt6/bin/qdbus'
ACTIONS = [
    ('lock', 'Ekranı Kilitle', 'system-lock-screen', ['loginctl', 'lock-session']),
    ('sleep', 'Uyku', 'system-suspend', ['systemctl', 'suspend']),
    ('restart', 'Yeniden Başlat…', 'system-reboot', [QDBUS, 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptReboot']),
    ('shutdown', 'Kapat…', 'system-shutdown', [QDBUS, 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptShutDown']),
    ('logout', 'Oturumu Kapat…', 'system-log-out', [QDBUS, 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptLogout']),
    ('settings', 'Sistem Ayarları', 'preferences-system', ['kstart', 'systemsettings']),
    ('screenshot', 'Ekran Görüntüsü Al', 'spectacle', ['spectacle']),
    ('region', 'Bölge Ekran Görüntüsü', 'spectacle', ['spectacle', '-r']),
    ('terminal', 'Yeni Terminal Penceresi', 'utilities-terminal', ['konsole']),
    ('home', 'Ana Klasörü Aç', 'user-home', ['xdg-open', str(HOME)]),
    ('desktop', 'Masaüstünü Göster', 'user-desktop', [QDBUS, 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'Show Desktop']),
    ('overview', 'Genel Bakış', 'view-app-grid', [QDBUS, 'org.kde.kglobalaccel', '/component/kwin', 'invokeShortcut', 'Overview']),
    ('trash', 'Çöp Kutusunu Boşalt', 'user-trash-full', ['gio', 'trash', '--empty']),
    ('monitor', 'Sistem Monitörü', 'utilities-system-monitor', ['plasma-systemmonitor']),
]
ACTION_CMD = {a[0]: a[3] for a in ACTIONS}


@ClassInfo({'D-Bus Interface': 'local.Spotlight'})
class Bridge(QObject):
    def __init__(self):
        super().__init__()
        self._apps = None

    # ---- D-Bus API (kept compatible with the old implementation)
    @Slot()
    def display(self):
        root.opened()
        view.show(); view.raise_(); view.requestActivate()

    @Slot()
    def toggle(self):
        if view.isVisible():
            self.dismiss()
        else:
            self.display()

    @Slot()
    def dismiss(self):
        view.hide()

    @Slot(str)
    def query(self, text):
        self.display(); root.search(text)

    @Slot(result=bool)
    def visible(self):
        return view.isVisible()

    @Slot(result=int)
    def resultCount(self):
        return root.resultCount()

    @Slot(int)
    def setMode(self, m):
        self.display(); root.setMode(m)

    @Slot()
    def activateFirst(self):
        root.activateFirst()

    # ---- QML helpers
    @Slot(result='QVariantList')
    def apps(self):
        if self._apps is None:
            self._apps = scan_apps()
        return self._apps

    @Slot(result='QVariantList')
    def suggestedApps(self):
        apps = {a['id']: a for a in self.apps()}
        out = [apps[i] for i in suggested_ids() if i in apps]
        return out[:5]

    @Slot(result='QVariantList')
    def appCategories(self):
        have = {a['cat'] for a in self.apps()}
        return [c for c in CAT_ORDER if c in have]

    @Slot()
    def refreshApps(self):
        self._apps = None

    @Slot(result='QVariantList')
    def recentFiles(self):
        return recent_files()

    @Slot(result='QVariantList')
    def actions(self):
        return [{'display': n, 'decoration': i, 'subtext': 'Eylem', 'category': 'Eylemler', 'payload': k}
                for k, n, i, _ in ACTIONS]

    @Slot(result='QVariantList')
    def clipboard(self):
        k = QDBusInterface('org.kde.klipper', '/klipper', 'org.kde.klipper.klipper', bus)
        r = k.call('getClipboardHistoryMenu')
        items = r.arguments()[0] if r.arguments() else []
        out = []
        for i, t in enumerate(items or []):
            one = ' '.join(str(t).split())
            if not one:
                continue
            out.append({'display': one[:160], 'decoration': 'edit-paste', 'subtext': f'{len(str(t))} karakter',
                        'category': 'Pano Geçmişi', 'payload': str(t)})
        return out

    @Slot(str)
    def launchApp(self, path):
        spawn(['kstart', '--application', path])

    @Slot(str)
    def openPath(self, path):
        spawn(['xdg-open', path])

    @Slot(str)
    def runAction(self, key):
        if key in ACTION_CMD:
            spawn(ACTION_CMD[key])

    @Slot(str)
    def copyText(self, text):
        QDBusInterface('org.kde.klipper', '/klipper', 'org.kde.klipper.klipper', bus).call('setClipboardContents', text)
        QApplication.clipboard().setText(text)

    @Slot('QVariantList')
    def setShapes(self, shapes):
        global SHAPES
        SHAPES = shapes
        updateBlur()


_blur = None
_contrast = None
_lastRegion = None
try:
    lib = ctypes.CDLL('libKF6WindowSystem.so.6')
    _blur = getattr(lib, '_ZN14KWindowEffects16enableBlurBehindEP7QWindowbRK7QRegion')
    _blur.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_void_p]
    _contrast = getattr(lib, '_ZN14KWindowEffects24enableBackgroundContrastEP7QWindowbdddRK7QRegion')
    _contrast.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_void_p]
except Exception as e:
    print('blur unavailable', e, flush=True)


def updateBlur(*_):
    global _lastRegion
    region = QRegion()
    for s in SHAPES:
        try:
            x, y, w, h, r = [float(v) for v in s]
        except Exception:
            continue
        if w < 2 or h < 2:
            continue
        path = QPainterPath()
        path.addRoundedRect(x + 0.5, y + 0.5, w - 1, h - 1, r, r)
        region = region.united(QRegion(path.toFillPolygon().toPolygon()))
    if region == _lastRegion:
        return
    _lastRegion = region
    # only the glass shapes take mouse input; clicks elsewhere reach the windows below
    view.setMask(region)
    w = shiboken6.getCppPointer(view)[0]
    r = shiboken6.getCppPointer(region)[0]
    if _blur:
        _blur(w, True, r)
    if _contrast:
        # contrast, intensity, saturation  (1.0 = unchanged) -> vivid Liquid-Glass colours
        _contrast(w, True, 1.0, 1.0, 1.9, r)



bridge = Bridge()
SHAPES = []

view = QQuickView()
view.setColor(QColor('transparent'))
view.setFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
view.setTitle('Spotlight Search')
view.engine().addImportPath('/usr/lib64/qt6/qml')
view.rootContext().setContextProperty('bridge', bridge)
view.rootContext().setContextProperty('iconDir', QUrl.fromLocalFile(str(HERE / 'icons') + '/').toString())
view.setSource(QUrl.fromLocalFile(str(HERE / 'main.qml')))
if view.status() == QQuickView.Error:
    print([e.toString() for e in view.errors()], flush=True)
    sys.exit(1)
root = view.rootObject()
view.setResizeMode(QQuickView.SizeViewToRootObject)  # root has a fixed size -> no resize flicker

view.visibleChanged.connect(lambda v: (globals().__setitem__('_lastRegion', None), updateBlur()) if v else None)
bus.registerService('local.Spotlight')
bus.registerObject('/Search', bridge, QDBusConnection.ExportAllSlots)
view.activeChanged.connect(lambda: QTimer.singleShot(150, lambda: bridge.dismiss() if view.isVisible() and not view.isActive() else None))
# warm the app cache in the background of the event loop
QTimer.singleShot(500, bridge.apps)
sys.exit(app.exec())
