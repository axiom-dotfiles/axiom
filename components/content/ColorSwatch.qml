pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.content.base

// properties: { color: base00-base0F (or any name Theme.resolveColor accepts), label }
Card {
  id: root

  color: Theme.resolveColor(root.properties.color)
  border.width: Math.max(Appearance.borderWidth, 3)

  Text {
    id: label
    text: root.properties.color
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: OverlayConfig.cardSpacing / 2
    color: (root.color === Theme.background || root.color === Theme.backgroundAlt) ? Theme.foreground : Theme.background
    font.pixelSize: Appearance.fontSize - 4
    font.bold: true
    z: 1
    opacity: 0.8
  }

  Text {
    id: semanticLabel
    text: root.properties.label
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: OverlayConfig.cardSpacing / 2
    color: (root.color === Theme.background || root.color === Theme.backgroundAlt) ? Theme.foreground : Theme.background
    font.pixelSize: Appearance.fontSize - 4
    font.bold: true
    z: 1
    opacity: 0.8
  }
}
