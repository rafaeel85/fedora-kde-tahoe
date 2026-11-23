import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC
import org.kde.plasma.plasma5support as Support
PlasmoidItem {
 id: root
 Plasmoid.status: popup.visible ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus
 preferredRepresentation: fullRepresentation
 toolTipMainText: "Masaüstü menyusu"
 property var items: []
 readonly property string qdbus: "@QTBINS@/qdbus "
 readonly property var menus: ({
 "File": [{label:"Home",command:"dolphin @HOME@"},{label:"Documents",command:"dolphin @HOME@/Documents"},{label:"Terminal",command:"konsole"}],
 "Edit": [{label:"Clipboard history",command:qdbus+"org.kde.klipper /klipper org.kde.klipper.klipper.showKlipperPopupMenu"},{label:"Edit desktop and panels",command:qdbus+"org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.editMode true"}],
 "View": [{label:"Show desktop",command:qdbus+"org.kde.KWin /KWin org.kde.KWin.showDesktop true"},{label:"Show windows",command:qdbus+"org.kde.KWin /KWin org.kde.KWin.showDesktop false"}],
 "Settings": [{label:"System Settings",command:"@HOME@/.local/bin/systemsettings-stable"}],
 "Help": [{label:"KDE Help Center",command:"khelpcenter"}]
 })
 Support.DataSource {
  id: runner; engine: "executable"; connectedSources: []
  onNewData: function(sourceName,data) {console.log("DesktopMenu result",sourceName,data["exit code"],data.stderr);disconnectSource(sourceName);}
 }
 function run(command) {popup.visible=false;runner.connectSource(command);}
 function openMenu(name,button) {popup.visible=false;items=menus[name];popup.visualParent=button;popup.visible=true;}
 PlasmaCore.Dialog {
  id: popup
  location: PlasmaCore.Types.TopEdge
  type: PlasmaCore.Dialog.PopupMenu
  hideOnWindowDeactivate: true
  flags: Qt.WindowStaysOnTopHint
  mainItem: Column {
   width: 270
   height: root.items.length * 36
   Repeater {
    model: root.items
    PC.ItemDelegate {
     required property var modelData
     width: 270
     height: 36
     text: modelData.label
     Accessible.role: Accessible.Button
     Accessible.name: modelData.label
     Accessible.onPressAction: clicked()
     onClicked: root.run(modelData.command)
    }
   }
  }
 }
 fullRepresentation: RowLayout {
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.minimumHeight: implicitHeight
  spacing: 0
  Repeater {
   model: ["File","Edit","View","Settings","Help","Ara"]
   PC.ToolButton {
    required property string modelData
    text: modelData
    focusPolicy: Qt.NoFocus
    onClicked: {if(modelData==="Ara")root.run("@HOME@/.local/bin/spotlight-search");else root.openMenu(modelData,this);}
   }
  }
 }
}
