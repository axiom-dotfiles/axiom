pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// A small drawing of a cell layout's slots (OverlayConfig.layouts), in
// proportion: `step` pixels per half unit, so a Wide is twice a Single
Item {
  id: root

  required property string layout
  property real step: 12
  property real gap: 2
  property bool selected: false
  property color slotColor: root.selected ? Theme.accent : Theme.backgroundHighlight

  readonly property var layoutData: OverlayConfig.layouts[root.layout] ?? {
    "cols": 2,
    "rows": 2,
    "slots": {}
  }

  implicitWidth: root.layoutData.cols * root.step
  implicitHeight: root.layoutData.rows * root.step

  Repeater {
    model: Object.keys(root.layoutData.slots)

    Rectangle {
      required property string modelData
      readonly property var rect: root.layoutData.slots[modelData]
      x: rect[0] * root.step + root.gap / 2
      y: rect[1] * root.step + root.gap / 2
      width: rect[2] * root.step - root.gap
      height: rect[3] * root.step - root.gap
      radius: Math.min(Widget.radius / 2, 3)
      color: root.slotColor
      border.color: root.selected ? Theme.accent : Theme.border
      border.width: 1
    }
  }
}
