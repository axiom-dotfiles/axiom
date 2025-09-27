// qs/components/reusable/StyledText.qml
pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Text {
  property color textColor: Theme.foreground
  property string textFamily: Appearance.fontFamily
  property int textSize: Appearance.fontSize
  color: textColor
  font.family: textFamily
  font.pixelSize: textSize
}
