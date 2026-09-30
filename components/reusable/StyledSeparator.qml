pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Rectangle {
  id: root

  // -- Configurable Appearance --
  property alias separatorColor: root.color
  property alias separatorHeight: root.height

  // -- Implementation --
  height: Appearance.borderWidth
  color: Theme.accent
  radius: Widget.radius
}
