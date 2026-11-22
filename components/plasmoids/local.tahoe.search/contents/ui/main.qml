import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC
import org.kde.plasma.plasma5support as Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Spotlight"

    Support.DataSource {
        id: runner; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName); }
    }

    fullRepresentation: MouseArea {
        id: btn
        Layout.preferredWidth: height
        Layout.minimumWidth: height
        hoverEnabled: true
        onClicked: runner.connectSource("@HOME@/.local/bin/spotlight-search")
        Rectangle {
            anchors.centerIn: parent
            width: parent.height + 4; height: Math.min(parent.height - 6, 22)
            radius: height / 2
            color: btn.containsMouse ? "#22ffffff" : "transparent"
        }
        Image {
            anchors.centerIn: parent
            width: 15; height: 15
            sourceSize: Qt.size(32, 32)
            source: Qt.resolvedUrl("../icons/search.svg")
        }
    }
}
