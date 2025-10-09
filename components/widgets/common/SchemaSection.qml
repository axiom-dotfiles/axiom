// SchemaSection.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

ColumnLayout {
  id: root
  required property string title
  property bool expanded: true
  property string description: ""
  default property alias content: contentContainer.data
  
  Layout.fillWidth: true
  spacing: Widget.spacing
  
  StyledContainer {
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height + (Widget.padding * 2)
    backgroundColor: headerArea.containsMouse ? Theme.backgroundHighlight : Theme.backgroundAlt
    
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.padding
      spacing: Widget.spacing
      
      StyledText {
        text: root.expanded ? "▼" : "▶"
        textColor: Theme.accent
        Layout.preferredWidth: implicitWidth
        
        Behavior on rotation {
          NumberAnimation {
            duration: Widget.animations ? Widget.animationDuration : 0
          }
        }
      }
      
      StyledText {
        text: root.title
        textSize: Appearance.fontSize + 2
        font.bold: true
        Layout.fillWidth: true
      }
    }
    
    MouseArea {
      id: headerArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.expanded = !root.expanded;
      }
    }
  }
  
  StyledText {
    visible: root.description !== "" && root.expanded
    text: root.description
    opacity: 0.7
    textSize: Appearance.fontSize - 1
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    Layout.leftMargin: Widget.padding
  }
  
  ColumnLayout {
    id: contentContainer
    visible: root.expanded
    Layout.fillWidth: true
    Layout.leftMargin: Widget.padding * 2
    spacing: Widget.spacing * 2
    
    Behavior on Layout.topMargin {
      NumberAnimation {
        duration: Widget.animations ? Widget.animationDuration : 0
      }
    }
  }
  
  Item {
    visible: root.expanded
    Layout.preferredHeight: Widget.spacing
  }
}

