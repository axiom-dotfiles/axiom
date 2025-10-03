// qs/components/reusable/StyledSeparator.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Rectangle {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  // null
  
  // -- Configurable Appearance --
  property alias separatorColor: component.color
  property alias separatorHeight: component.height
  
  // -- Implementation --
  height: Appearance.borderWidth
  color: Theme.accent
  radius: Appearance.borderRadius
}
