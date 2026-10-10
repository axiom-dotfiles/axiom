pragma ComponentBehavior: Bound
import QtQuick

import qs.config

Rectangle {
  id: root

  // -- Configurable Appearance --
  property color backgroundColor: Theme.backgroundAlt
  property alias borderColor: root.border.color
  property alias borderWidth: root.border.width
  property alias borderRadius: root.radius
  // Filled solid, whatever the surface opacity
  property bool solid: false

  // -- Implementation --
  color: root.solid ? root.backgroundColor : Appearance.fill(root.backgroundColor)
  border.color: "transparent"
  border.width: Appearance.borderWidth
  radius: Widget.radius
}
