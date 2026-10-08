pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Draws its children with `holes` (rects in its coordinates) cut out:
// a stroke left open where something joined to it carries on over it.
// No layer while there are none.
Item {
  id: root

  property var holes: []
  default property alias content: inner.data

  Item {
    id: inner
    anchors.fill: parent
    layer.enabled: root.holes.length > 0
    layer.effect: MultiEffect {
      maskEnabled: true
      maskInverted: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 0
    }
  }

  Item {
    id: mask
    anchors.fill: parent
    visible: false
    layer.enabled: root.holes.length > 0

    Repeater {
      model: root.holes.length

      Rectangle {
        required property int index
        readonly property rect hole: root.holes[index] ?? Qt.rect(0, 0, 0, 0)
        x: hole.x
        y: hole.y
        width: hole.width
        height: hole.height
        color: "black"
      }
    }
  }
}
