// qs/components/reusable/StyledIconButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components.reusable

ToolButton {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  property string iconText: ""
  property string tooltipText: ""
  
  // -- Configurable Appearance --
  property int iconSize: Appearance.fontSize
  property color iconColor: Theme.foreground
  property color backgroundColor: "transparent"
  property color hoverColor: Theme.backgroundHighlight
  property color pressColor: Theme.backgroundAlt
  property color borderColor: "transparent"
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Appearance.borderRadius
  
  // -- Implementation --
  Layout.fillHeight: true
  Layout.fillWidth: true
  Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
  
  contentItem: Text {
    text: component.iconText
    font.family: Appearance.fontFamily
    font.pixelSize: component.iconSize
    color: component.iconColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  
  background: Rectangle {
    color: component.pressed ? component.pressColor : (component.hovered ? component.hoverColor : component.backgroundColor)
    border.color: component.borderColor
    border.width: component.borderWidth
    radius: component.borderRadius
    
    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }
  }
}
