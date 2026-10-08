pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods
import qs.components.reusable

// A Custom page's, an edge menu's or the lock screen's modules, each in its
// own place on a grid of quarter cards (GridPlacement). The grid is as big
// as its modules reach (or its `extent`), at the card size of `grid`;
// `stretch` grows it into room.
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

  // The least the grid spans ({ cols, rows }) whatever its modules reach
  // (a lock screen's grid), null for just the modules
  property var extent: null

  readonly property var bounds: {
    const reach = GridPlacement.bounds(root.modules);
    return root.extent ? {
      "cols": Math.max(reach.cols, root.extent.cols),
      "rows": Math.max(reach.rows, root.extent.rows)
    } : reach;
  }
  readonly property var sizes: root.grid.sizes(root.bounds, root.stretch)

  // A module's detail grown over the others (ExpandedModule): { type,
  // properties, from: [x, y, w, h] px in the grid }, null for none. Only on
  // overlay pages and edge menus, and only types allowed on the host
  // (`x-hosts`)
  property var expanded: null
  readonly property bool expandable: root.host?.kind === "overlay" || root.host?.kind === "edgeMenu"
  function canExpand(type) {
    return root.expandable && OverlayConfig.moduleInfo(type) !== null && OverlayConfig.allowedIn(type, root.host.kind);
  }
  function expand(type, properties, from) {
    if (!root.canExpand(type))
      return;
    const at = from ? from.mapToItem(root, 0, 0) : Qt.point(0, 0);
    root.expanded = {
      "type": type,
      "properties": properties ?? {},
      "from": [at.x, at.y, from?.width ?? root.width, from?.height ?? root.height]
    };
  }
  // Shrinks the detail back into where it came from, then drops it
  function collapse() {
    expandedLayer.collapse();
  }

  implicitWidth: root.sizes.width
  implicitHeight: root.sizes.height

  // Logs modules that overlap another
  readonly property string _checkKey: JSON.stringify((root.modules ?? []).map(module => [module?.type, module?.place]))
  on_CheckKeyChanged: root._check()
  Component.onCompleted: root._check()
  function _check() {
    const modules = root.modules ?? [];
    modules.forEach((module, i) => {
      if (!GridPlacement.canPlace(modules.slice(0, i), module?.place, -1))
        console.warn(`Overlay module ${module?.type} overlaps another`);
    });
  }

  // The modules, faded out (a translucent box would show them) and out of
  // reach under an expanded detail
  Item {
    anchors.fill: parent
    enabled: root.expanded === null
    opacity: expandedLayer.shown ? 0 : 1
    Glide on opacity {
      duration: Appearance.animNormal
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
          "w": 4,
          "h": 4
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
          expander: root.expandable ? root : null
        }
      }
    }
  }

  ExpandedModule {
    id: expandedLayer
    anchors.fill: parent
    request: root.expanded
    host: root.host
    slotRect: [0, 0, root.bounds.cols, root.bounds.rows]
    onClosed: root.expanded = null
  }
}
