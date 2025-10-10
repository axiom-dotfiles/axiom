import QtQuick

import qs.config

Rectangle {
  id: swatch

  required property color swatchColor
  required property string swatchName
  required property string swatchSemantic

  anchors.fill: parent
  color: swatchColor
  radius: Appearance.borderRadius
  border.color: Theme.foreground
  border.width: Math.max(Menu.cardBorderWidth, 3)

  Text {
    id: label
    text: swatch.swatchName
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Menu.cardSpacing / 2
    color: (swatch.color === Theme.background || swatch.color === Theme.backgroundAlt) ? Theme.foreground : Theme.background
    font.pixelSize: Appearance.fontSize - 4
    font.bold: true
    z: 1
    opacity: 0.8
  }

  Text {
    id: semanticLabel
    text: swatch.swatchSemantic
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Menu.cardSpacing / 2
    color: (swatch.color === Theme.background || swatch.color === Theme.backgroundAlt) ? Theme.foreground : Theme.background
    font.pixelSize: Appearance.fontSize - 4
    font.bold: true
    z: 1
    opacity: 0.8
  }
}
