pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// properties: { color: base00-base0F (or any name Theme.resolveColor accepts), label }
Card {
  id: root

  // Whichever of the theme's foreground and background reads on the swatch
  readonly property bool _foregroundIsLight: !Utils.isColorDark(Theme.foreground)
  readonly property color labelColor: Utils.isColorDark(root.color) === root._foregroundIsLight ? Theme.foreground : Theme.background

  color: Theme.resolveColor(root.properties.color)
  border.width: Math.max(Appearance.borderWidth, 3)

  component SwatchLabel: StyledText {
    anchors.horizontalCenter: parent.horizontalCenter
    textColor: root.labelColor
    textSize: Appearance.fontSize - 4
    font.bold: true
    opacity: 0.8
  }

  SwatchLabel {
    anchors.top: parent.top
    anchors.topMargin: OverlayConfig.cardSpacing / 2
    text: root.properties.label
  }

  SwatchLabel {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: OverlayConfig.cardSpacing / 2
    text: root.properties.color
  }
}
