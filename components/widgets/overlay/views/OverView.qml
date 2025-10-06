pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts

Item {
  id: overlayColumn
  required property var screen
  
  implicitWidth: rowLayout.implicitWidth
  implicitHeight: rowLayout.implicitHeight
  
  RowLayout {
    id: rowLayout
    spacing: Menu.cardSpacing
    
    Repeater {
      model: Menu.columns
      delegate: ColumnLayout {
        spacing: Menu.cardSpacing
        
        Cell2x2 {
          topLeft: Rectangle {
            color: Theme.info
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          topRight: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomLeft: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomRight: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
        }
        
        Cell2x2 {
          topLeft: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          topRight: Rectangle {
            color: Theme.warning
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomLeft: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomRight: Rectangle {
            color: Theme.error
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
        }
      }
    }
  }
}
