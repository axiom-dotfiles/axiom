// /components/reusable/StyledContainer.qml
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
  property alias backgroundColor: component.color
  property alias borderColor: component.border.color
  property alias borderWidth: component.border.width
  property alias borderRadius: component.radius

  // -- Implementation --
  color: Theme.backgroundAlt
  border.color: "transparent"
  border.width: Appearance.borderWidth
  radius: Appearance.borderRadius
}
