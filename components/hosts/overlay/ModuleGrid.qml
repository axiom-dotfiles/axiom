pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

// A Custom page's or an edge menu's modules, each in its own place on a
// grid of half cards (GridPlacement). The grid is as big as its modules
// reach, at the card size of `grid`; `stretch` grows it into room.
Item {
  id: root

  // [{ type, properties, place: { x, y, w, h } }]
  required property var modules
  required property OverlayGrid grid
  // Room to grow into ({ width, height }, either optional), null for none
  property var stretch: null
  // Where the modules are shown, handed to each as `host` (see OverlaySlot)
  property var host: ({
      "kind": "overlay"
    })

  readonly property var bounds: GridPlacement.bounds(root.modules)
  readonly property var sizes: root.grid.sizes(root.bounds, root.stretch)

  implicitWidth: root.sizes.width
  implicitHeight: root.sizes.height

  // Logs modules that don't fit their place or overlap another
  readonly property string _checkKey: JSON.stringify((root.modules ?? []).map(module => [module?.type, module?.place]))
  on_CheckKeyChanged: root._check()
  Component.onCompleted: root._check()
  function _check() {
    const modules = root.modules ?? [];
    modules.forEach((module, i) => {
      const rect = GridPlacement.rectOf(module?.place);
      if (module?.type && !OverlayConfig.fits(module.type, rect))
        console.warn(`Overlay module ${module.type} doesn't fit a ${rect[2]}×${rect[3]} place`);
      if (!GridPlacement.canPlace(modules.slice(0, i), module?.place, -1))
        console.warn(`Overlay module ${module?.type} overlaps another`);
    });
  }

  // Keyed by count: edits update the modules in place
  Repeater {
    model: root.modules?.length ?? 0

    Item {
      id: slot
      required property int index
      readonly property var module: root.modules[slot.index]
      readonly property var place: slot.module?.place ?? {
        "x": 0,
        "y": 0,
        "w": 2,
        "h": 2
      }
      readonly property var r: GridPlacement.rectPx(slot.place, root.sizes)

      x: slot.r.x
      y: slot.r.y
      width: slot.r.width
      height: slot.r.height
      clip: true

      OverlaySlot {
        config: slot.module
        rect: GridPlacement.rectOf(slot.place)
        host: root.host
      }
    }
  }
}
