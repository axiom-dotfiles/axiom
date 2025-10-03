// qs/components/reusable/StyledTabButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

TabButton {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  // null
  
  // -- Configurable Appearance --
  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt
  
  // -- Implementation --
  Layout.fillWidth: true
  Layout.fillHeight: true
  
  contentItem: Text {
    text: component.text
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 2
    color: component.checked ? component.activeColor : component.inactiveColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  
  background: Rectangle {
    color: component.checked ? Theme.backgroundHighlight : "transparent"
    radius: Appearance.borderRadius
    
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.8
      height: 2
      color: component.activeColor
      visible: component.checked
      radius: 1
      
      Behavior on width {
        NumberAnimation {
          duration: 150
        }
      }
    }
    
    Behavior on width {
      NumberAnimation {
        duration: 150
      }
    }
    
    Behavior on height {
      NumberAnimation {
        duration: 150
      }
    }
  }
}
