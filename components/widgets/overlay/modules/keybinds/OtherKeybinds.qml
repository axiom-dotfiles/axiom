// KeybindSection.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.widgets.common

Rectangle {
  id: root
  required property var keybinds
  color: Theme.background
  implicitWidth: Menu.cardUnit
  implicitHeight: 1440 - 100
  
  border.color: Theme.border
  border.width: Menu.cardBorderWidth

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Menu.cardPadding
    spacing: Menu.cardSpacing
    SchemaSection {
      title: "Other"
      expanded: true
      Layout.leftMargin: Widget.padding
      Layout.rightMargin: Widget.padding
      
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        
        Repeater {
          model: root.keybinds.OTHER
          
          KeybindPreview {
            required property var modelData
            keybind: modelData
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
