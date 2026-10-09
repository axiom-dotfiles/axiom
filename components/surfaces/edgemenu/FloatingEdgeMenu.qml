pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout

// A floating edge menu: an EdgePopout over the windows, growing out of the
// border or a solid bar on its edge, and meeting any other bar there as a
// bar popout does (EdgePlacement): out of a pill or a floating bar's
// island, or a detached box past a transparent bar. One held off the edge
// (`detached`) is an island: `gap`
// in from the frame lines on its edge and at both ends
// (BarManager.detachedGaps), so it lines up with a floating bar's islands, or
// with the windows.
EdgePopout {
  id: root

  required property var menu
  readonly property string menuId: root.menu.id

  // Held off the edge, its gaps from the frame lines across its edge and
  // at its ends (EdgePopout.gaps)
  held: root.menu.detached
  gap: root.menu.gap

  // Closes what it covers below it (PopoutManager); pinned, it ranks
  // lowest, and pinned or previewing it gives way and comes back
  claimKey: "menu:" + root.menuId
  claimKind: "menu"
  pinned: EdgeMenuManager.pinnedMenus[root.menuId] === true
  resident: sync.held

  // Along the edge, on the menu's lattice (GridPlacement.menuAlong),
  // in screen px: this window's edge coordinates start past what's
  // reserved on the perpendicular edge at its start
  readonly property real screenLength: root.vertical ? root.screen.height : root.screen.width
  readonly property real alongOrigin: root.reservedOn(root.startSide)
  // The least room from the modules to the screen's ends: what's reserved
  // there, the box's inset and its padding
  readonly property real startPad: root.alongOrigin + root.startInset + root.contentPadding
  readonly property real endPad: root.reservedOn(root.endSide) + root.endInset + root.contentPadding
  // From config, so the hover strip lines up before the body has loaded
  // Its card size (EdgeMenuManager.cardUnitOf)
  readonly property int unit: EdgeMenuManager.cardUnitOf(root.menu)
  readonly property real gridLength: EdgeMenusConfig.gridLengthOf(root.menu, root.vertical, root.unit)
  readonly property real modulesStart: GridPlacement.menuAlong(root.menu, root.screenLength, root.unit, root.startPad, root.endPad)

  // Where the modules can sit, for the layouts editor (EdgeMenuManager.frames)
  readonly property var frame: ({
      "screen": root.screen?.name ?? "",
      "startPad": root.startPad,
      "endPad": root.endPad,
      "across": root.attachAt + root.contentPadding + root.attachClearance,
      "before": Math.max(0, root.attachBase),
      "after": root.contentPadding,
      "reserves": false
    })

  edge: EdgeMenusConfig.edgeOf(root.menu)
  // The box's centre, so it starts where the modules should, less its
  // padding. From its natural length (the joins at the ends depend on
  // where it is); one filling its edge joins both and needs none.
  position: 0
  positionOffset: root.modulesStart - root.alongOrigin - root.contentPadding + (isFinite(root._naturalBox) ? root._naturalBox / 2 : 0)
  // Not held, its ends join the perpendicular edges once it reaches them.
  // Fill cells grow to whatever room there is, so reach them always.
  joinEnds: !root.held
  reachLength: root._body ? (root._body.fillsEdge ? Infinity : root._body.naturalLength) : 0
  // Growing modules make a top or bottom menu deeper: room for the most
  maxContentDepth: !root.vertical && root._body ? root._body.maxGrownHeight : 0
  // Room for its submenus' stretch from the start (EdgePopout.roomForSubmenus):
  // from config, as the body loads with the window
  roomForSubmenus: root.menu.modules.some(module => module?.type === "Submenu")
  // Read through a var: EdgeMenuBody's members, on EdgePopout's Item
  readonly property var _body: root.contentItem
  contentPadding: Appearance.borderWidth + EdgeMenusConfig.paddingOf(root.menu)
  fillColor: EdgeMenusConfig.colorsOf(root.menu).fill
  strokeColor: EdgeMenusConfig.colorsOf(root.menu).stroke
  triggerEnabled: root.menu.openOnHover
  hoverDelay: root.menu.openDelay
  triggerWidth: root.menu.triggerSize
  triggerLength: sync.triggerLength(root.contentItem, root.vertical, root.contentPadding)
  // On the modules, in screen px (the box's own position is in this
  // window's coordinates, which start past the perpendicular edges')
  triggerCentre: root.menu.length === "edge" ? (root.startPad + root.screenLength - root.endPad) / 2 : root.modulesStart + root.gridLength / 2
  dismissDelay: root.menu.closeDelay
  keyboardOnDemand: true
  closeOnClickOutside: root.menu.closeOnOutsideClick && !sync.held
  // Over the overlay its grab (which lets input through to the menu) is
  // the one: a grab of its own would clear it, closing the overlay
  grabEnabled: !root.overlayOpen
  autoDismiss: sync.autoDismiss

  EdgeMenuSync {
    id: sync
    host: root
    menu: root.menu
    screen: root.screen
    window: root.window
    triggerWindow: root.triggerWindow
    frame: root.frame
    onWarpRequested: {
      const box = root.boxInWindow;
      HyprlandManager.warpCursorToLayer(root.layerNamespace, root.screen?.name ?? "", root.window.width, root.window.height, box.x + box.width / 2, box.y + box.height / 2);
    }
  }

  content: Component {
    EdgeMenuBody {
      menu: root.menu
      vertical: root.vertical
      maxLength: root.maxBoxLength - root.contentPadding * 2
    }
  }
}
