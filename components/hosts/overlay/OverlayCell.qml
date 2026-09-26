pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// One cell of a column: the layout named by `layout` (OverlayConfig.layouts)
// split into slots, each hosting the module configured for it.
Item {
  id: root

  // { layout, slots: { <slotName>: { type, properties } } }
  required property var cellConfig
  required property OverlayGrid grid
  // Where the modules are shown (see OverlaySlot)
  property var host: ({
      "kind": "overlay"
    })

  readonly property var layout: {
    const layout = OverlayConfig.layouts[root.cellConfig.layout];
    if (!layout)
      console.warn("Unknown overlay cell layout:", root.cellConfig.layout);
    return layout ?? {
      "cols": 0,
      "rows": 0,
      "slots": {}
    };
  }
  readonly property var slots: root.cellConfig.slots || {}

  onSlotsChanged: {
    const unknown = Object.keys(root.slots).filter(name => !(name in root.layout.slots));
    if (unknown.length > 0)
      console.warn(`Overlay cell layout ${root.cellConfig.layout} has no slot(s): ${unknown.join(", ")}`);
    Object.keys(root.slots).filter(name => name in root.layout.slots).forEach(name => {
      const type = root.slots[name]?.type;
      if (type && !OverlayConfig.fits(type, root.layout.slots[name]))
        console.warn(`Overlay module ${type} doesn't fit the ${OverlayConfig.slotShape(root.layout.slots[name])} ${name} slot of ${root.cellConfig.layout}`);
    });
  }

  implicitWidth: root.grid.span(root.layout.cols)
  implicitHeight: root.grid.span(root.layout.rows)
  // One half unit at the cell's real size: a fill cell (see
  // OverlayConfig.columnFlow) is bigger than its layout, and its slots
  // grow with it
  readonly property real halfWidth: root.layout.cols > 0 ? (root.width - (root.layout.cols - 1) * OverlayConfig.cardSpacing) / root.layout.cols : 0
  readonly property real halfHeight: root.layout.rows > 0 ? (root.height - (root.layout.rows - 1) * OverlayConfig.cardSpacing) / root.layout.rows : 0

  Repeater {
    model: Object.keys(root.layout.slots)

    Item {
      id: slot
      required property string modelData
      readonly property var rect: root.layout.slots[slot.modelData]

      x: slot.rect[0] * (root.halfWidth + OverlayConfig.cardSpacing)
      y: slot.rect[1] * (root.halfHeight + OverlayConfig.cardSpacing)
      width: slot.rect[2] * root.halfWidth + (slot.rect[2] - 1) * OverlayConfig.cardSpacing
      height: slot.rect[3] * root.halfHeight + (slot.rect[3] - 1) * OverlayConfig.cardSpacing
      clip: true

      OverlaySlot {
        config: root.slots[slot.modelData]
        rect: slot.rect
        host: root.host
      }
    }
  }
}
