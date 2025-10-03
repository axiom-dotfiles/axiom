// qs/components/reusable/StyledSwitch.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.config

Switch {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  // null
  
  // -- Configurable Appearance --
  // null
  
  // -- Implementation --
  implicitWidth: 50
  implicitHeight: 26
  
  indicator: Rectangle {
    x: component.checked ? component.width - width - 2 : 2
    y: 2
    width: component.height - 4
    height: component.height - 4
    radius: (component.height - 4) / 2
    color: Theme.foreground
    
    Behavior on x {
      NumberAnimation {
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }
  }
  
  background: Rectangle {
    implicitWidth: 50
    implicitHeight: 26
    radius: height / 2
    color: component.checked ? Theme.accent : Theme.backgroundHighlight
    border.color: Theme.border
    border.width: Appearance.borderWidth
    
    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }
  }
}
