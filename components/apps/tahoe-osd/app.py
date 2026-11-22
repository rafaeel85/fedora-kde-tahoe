#!/usr/bin/env python3
"""macOS Tahoe style OSD (volume / brightness / text). Mirrors plasmashell's
org.kde.osdService signals; plasmashell's own OSD window is hidden by the KWin script."""
import sys, ctypes
from pathlib import Path
from PySide6.QtCore import QObject, Slot, QUrl, Qt
from PySide6.QtGui import QColor, QRegion, QPainterPath, QFont
from PySide6.QtQuick import QQuickView
from PySide6.QtDBus import QDBusConnection, QDBusMessage
from PySide6.QtWidgets import QApplication
import shiboken6

HERE = Path(__file__).resolve().parent
app = QApplication(sys.argv)
app.setDesktopFileName('local.tahoeosd')
app.setApplicationName('Tahoe OSD')
app.setQuitOnLastWindowClosed(False)
app.setFont(QFont('Inter', 10))

lib = ctypes.CDLL('libKF6WindowSystem.so.6')
_blur = getattr(lib, '_ZN14KWindowEffects16enableBlurBehindEP7QWindowbRK7QRegion')
_blur.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_void_p]
_contrast = getattr(lib, '_ZN14KWindowEffects24enableBackgroundContrastEP7QWindowbdddRK7QRegion')
_contrast.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_void_p]


class Bridge(QObject):
    @Slot('QVariantList')
    def setShapes(self, shapes):
        region = QRegion()
        for s in shapes:
            x, y, w, h, r = [float(v) for v in s]
            p = QPainterPath()
            p.addRoundedRect(x + 0.5, y + 0.5, w - 1, h - 1, r, r)
            region = region.united(QRegion(p.toFillPolygon().toPolygon()))
        if region.isEmpty():
            return
        wp, rp = shiboken6.getCppPointer(view)[0], shiboken6.getCppPointer(region)[0]
        _blur(wp, True, rp)
        _contrast(wp, True, 1.0, 1.08, 1.8, rp)

    @Slot(bool)
    def setShown(self, shown):
        if shown and not view.isVisible():
            view.show()
        elif not shown and view.isVisible():
            view.hide()


def cc_open():
    """No HUD while the Control Center is open (its own sliders already show the value, like macOS)."""
    msg = QDBusMessage.createMethodCall('local.TahoeCC', '/CC', 'local.TahoeCC', 'visible')
    reply = QDBusConnection.sessionBus().call(msg, timeout=150)
    args = reply.arguments() if reply.type() == QDBusMessage.ReplyMessage else []
    return bool(args and args[0])


class Listener(QObject):
    @Slot(str, int, int, str)
    def osdProgress(self, icon, percent, maximum, extra):
        if cc_open():
            return
        root.progress(icon, percent, maximum, extra)

    @Slot(str, str)
    def osdText(self, icon, text):
        root.text(icon, text)


bridge = Bridge()
view = QQuickView()
view.setColor(QColor('transparent'))
view.setFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
              | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput)
view.setTitle('tahoe-osd')
view.rootContext().setContextProperty('bridge', bridge)
view.setSource(QUrl.fromLocalFile(str(HERE / 'main.qml')))
if view.status() == QQuickView.Error:
    print([e.toString() for e in view.errors()], flush=True)
    sys.exit(1)
root = view.rootObject()
view.setResizeMode(QQuickView.SizeViewToRootObject)

listener = Listener()
bus = QDBusConnection.sessionBus()
ok1 = bus.connect('', '/org/kde/osdService', 'org.kde.osdService', 'osdProgress', listener, '1osdProgress(QString,int,int,QString)')
ok2 = bus.connect('', '/org/kde/osdService', 'org.kde.osdService', 'osdText', listener, '1osdText(QString,QString)')
print('dbus connect', ok1, ok2, flush=True)
sys.exit(app.exec())
