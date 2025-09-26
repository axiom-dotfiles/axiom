// qs/components/reusable/StyledContainer.qml
pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Rectangle {
  property color containerColor: Theme.backgroundAlt
  property color containerBorderColor: "transparent"
  property int containerBorderWidth: 1
  property real containerRadius: Appearance.borderRadius

  color: containerColor
  border.color: containerBorderColor
  border.width: containerBorderWidth
  radius: containerRadius
}
