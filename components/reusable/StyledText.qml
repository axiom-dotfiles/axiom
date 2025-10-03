// qs/components/reusable/StyledText.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Text {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  // null
  
  // -- Configurable Appearance --
  property color textColor: Theme.foreground
  property string textFamily: Appearance.fontFamily
  property int textSize: Appearance.fontSize
  
  // -- Implementation --
  color: textColor
  font.family: textFamily
  font.pixelSize: textSize
}
