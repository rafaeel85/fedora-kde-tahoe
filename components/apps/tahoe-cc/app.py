#!/usr/bin/env python3
"""macOS Tahoe style Control Center window (floating glass modules). D-Bus: local.TahoeCC /CC"""
import sys, ctypes, subprocess, time
from pathlib import Path
from PySide6.QtCore import QObject, Slot, Signal, ClassInfo, QUrl, QTimer, Qt, QProcess
from PySide6.QtGui import QColor, QRegion, QPainterPath, QFont
from PySide6.QtQuick import QQuickView
from PySide6.QtDBus import QDBusConnection, QDBusInterface, QDBusMessage
from PySide6.QtWidgets import QApplication
import shiboken6

HERE = Path(__file__).resolve().parent
app = QApplication(sys.argv)
app.setDesktopFileName('local.tahoecc')
app.setApplicationName('Denetim Merkezi')
app.setQuitOnLastWindowClosed(False)
app.setQuitLockEnabled(False)
app.setFont(QFont('Inter', 10))

bus = QDBusConnection.sessionBus()
if bus.interface().isServiceRegistered('local.TahoeCC').value():
    QDBusInterface('local.TahoeCC', '/CC', 'local.TahoeCC', bus).call('toggle')
    sys.exit(0)

lib = ctypes.CDLL('libKF6WindowSystem.so.6')
_blur = getattr(lib, '_ZN14KWindowEffects16enableBlurBehindEP7QWindowbRK7QRegion')
_blur.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_void_p]
_contrast = getattr(lib, '_ZN14KWindowEffects24enableBackgroundContrastEP7QWindowbdddRK7QRegion')
_contrast.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_void_p]
_last = None


def apply_shapes(shapes):
    global _last
    region = QRegion()
    for s in shapes:
        x, y, w, h, r = [float(v) for v in s]
        if w < 2 or h < 2:
            continue
        p = QPainterPath()
        p.addRoundedRect(x + 0.5, y + 0.5, w - 1, h - 1, r, r)
        region = region.united(QRegion(p.toFillPolygon().toPolygon()))
    if region.isEmpty() or region == _last:   # an empty region would blur the whole window
        return
    _last = region
    view.setMask(region)
    w, r = shiboken6.getCppPointer(view)[0], shiboken6.getCppPointer(region)[0]
    _blur(w, True, r)
    _contrast(w, True, 1.0, 1.08, 1.8, r)


@ClassInfo({'D-Bus Interface': 'local.TahoeCC'})
class Bridge(QObject):
    hiddenAt = 0.0
    outputReady = Signal(str, str)      # key, stdout  (async command results for QML)

    @Slot()
    def toggle(self):
        if view.isVisible():
            self.dismiss()
        elif time.monotonic() - Bridge.hiddenAt > 0.35:   # the menu click that just closed us
            self.display()

    @Slot()
    def display(self):
        global _last
        _last = None
        # only one menu-bar popup at a time: close any open Tahoe menu right away
        bus.asyncCall(QDBusMessage.createMethodCall('local.TahoeMenus', '/Menus', 'local.TahoeMenus', 'dismiss'))
        root.opened()
        view.show(); view.raise_(); view.requestActivate()

    @Slot()
    def dismiss(self):
        if view.isVisible():
            view.hide()
            Bridge.hiddenAt = time.monotonic()

    @Slot(result=bool)
    def visible(self):
        return view.isVisible()

    @Slot(str)
    def run(self, cmd):
        subprocess.Popen(['sh', '-c', cmd], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @Slot(str, str)
    def outputAsync(self, key, cmd):
        # never block the GUI thread (a blocking nmcli call stalled the window for >1 s)
        proc = QProcess(self)
        proc.finished.connect(lambda *_: (self.outputReady.emit(key, bytes(proc.readAllStandardOutput()).decode(errors='replace')), proc.deleteLater()))
        proc.start('sh', ['-c', cmd])

    @Slot('QVariantList')
    def setShapes(self, shapes):
        if view.isVisible():
            apply_shapes(shapes)


bridge = Bridge()
view = QQuickView()
view.setColor(QColor('transparent'))
view.setFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
view.setTitle('Denetim Merkezi')
view.engine().addImportPath('@QTQML@')
view.rootContext().setContextProperty('bridge', bridge)
view.setSource(QUrl.fromLocalFile(str(HERE / 'main.qml')))
if view.status() == QQuickView.Error:
    print([e.toString() for e in view.errors()], flush=True)
    sys.exit(1)
root = view.rootObject()
view.setResizeMode(QQuickView.SizeViewToRootObject)


bus.registerService('local.TahoeCC')
bus.registerObject('/CC', bridge, QDBusConnection.ExportAllSlots)
view.activeChanged.connect(lambda: QTimer.singleShot(120, lambda: bridge.dismiss() if view.isVisible() and not view.isActive() else None))
view.visibleChanged.connect(lambda v: root.pushShapes() if v else None)
sys.exit(app.exec())
