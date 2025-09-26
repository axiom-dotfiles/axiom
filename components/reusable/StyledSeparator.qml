// qs/components/reusable/StyledSeparator.qml
pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Rectangle {
  property color separatorColor: Theme.accent
  property int separatorHeight: Appearance.borderWidth

  height: separatorHeight
  color: separatorColor
  radius: 0
}
