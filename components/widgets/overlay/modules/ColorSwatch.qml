import QtQuick

import qs.config

Rectangle {
  id: swatch

  required property color swatchColor
  required property string swatchName

  anchors.fill: parent
  color: swatchColor
  radius: Appearance.borderRadius
  // border.color: Theme.border
  // border.width: Appearance.borderWidth

  Text {
    id: label
    text: swatch.swatchName
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Menu.cardSpacing
    color: (swatch.color === Theme.background || swatch.color === Theme.backgroundAlt) ? Theme.foreground : Theme.background
    font.pixelSize: Appearance.fontSize - 4
    font.bold: true
    z: 1
    opacity: 0.8
  }
}
