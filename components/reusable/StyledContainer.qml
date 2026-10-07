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

  // -- Implementation --
  color: Appearance.fill(backgroundColor)
  border.color: "transparent"
  border.width: Appearance.borderWidth
  radius: Widget.radius
}
