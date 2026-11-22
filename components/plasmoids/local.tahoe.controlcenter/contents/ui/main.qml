import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Support
import org.kde.plasma.workspace.dbus as DBus

// Menu bar button: toggles the floating Tahoe Control Center window (~/.local/share/tahoe-cc)
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Denetim Merkezi"

    // fallback only: starts the service when it is not running yet
    Support.DataSource {
        id: exec; engine: "executable"; connectedSources: []
        onNewData: (src, data) => disconnectSource(src)
    }
    property bool ccOpen: false
    function call(member, resolve, reject) {
        DBus.SessionBus.asyncCall({ service: "local.TahoeCC", path: "/CC", iface: "local.TahoeCC", member: member, arguments: [] },
                                  resolve || (() => {}), reject || (() => {}))
    }
    function toggle() {
        call("toggle", () => pollFast.restart(), () => exec.connectSource("@HOME@/.local/bin/tahoe-cc"))
    }
    function poll() { call("visible", v => root.ccOpen = v === true || (v && v.value === true), () => root.ccOpen = false) }
    // cheap D-Bus poll so the menu bar pill follows the window state
    Timer { interval: 400; repeat: true; running: true; onTriggered: root.poll() }
    Timer { id: pollFast; interval: 60; onTriggered: root.poll() }

    fullRepresentation: MouseArea {
        id: btn
        Layout.preferredWidth: height
        Layout.minimumWidth: height
        hoverEnabled: true
        onClicked: root.toggle()
        Rectangle {   // Tahoe highlights the menu bar icon with a pill while open
            anchors.centerIn: parent
            width: parent.height + 4; height: parent.height - 6
            radius: height / 2
            color: root.ccOpen ? "#40ffffff" : (btn.containsMouse ? "#22ffffff" : "transparent")
        }
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Qt.resolvedUrl("../icons/controlcenter.svg")
        }
    }
}
