pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout

// A floating edge menu: an EdgePopout over the windows, growing out of the
// border or a solid bar on its edge. On a pill bar it attaches as a bar
// popout does: standing on a pill's far stroke when it fits within one,
// else growing from the bar's outer edge with the pills showing through.
// A floating bar's islands are met as pills held further in: the box
// always grows from the bar's outer edge, filling around them.
// On a transparent bar there's nothing to grow out of, so it's a detached
// box where a bar popout's would be. One held off the edge (`detached`) is
// an island: `gap` in from the frame lines on its edge and at both ends
// (Bar.detachedGaps), so it lines up with a floating bar's islands, or
// with the windows.
EdgePopout {
  id: root

  required property var menu
  readonly property string menuId: root.menu.id

  // Held off the edge, and its gaps from the frame lines across its edge
  // and at its ends (what places it, so a change of `held` never reads
  // them before they follow)
  readonly property bool held: root.menu.detached
  readonly property var gaps: root.held ? Bar.detachedGaps(root.screen, root.edge, root.menu.gap, HyprlandManager.gapsOut) : null

  // While the overlay is open on its screen it draws over the overlay
  // (HyprlandManager.layerRulesLua), so a detached box doesn't slide out
  // from under its bar, a layer the overlay covers (as BarPopouts.underBar).
  // Followed only while closed: the namespace changes with it.
  readonly property bool overlayOpen: ShellManager.surfaceOpenOn("overlay", root.screen)
  property bool _overOverlay: false
  function _followOverlay() {
    if (!root.occupied)
      root._overOverlay = root.overlayOpen;
  }
  onOverlayOpenChanged: root._followOverlay()
  onOccupiedChanged: root._followOverlay()

  // Gives way to nothing, and puts an OSD or dock on its edge away
  // (ShellManager.edgeOutranked)
  readonly property var _claim: root.isOpen ? ({
      "screen": root.screen?.name ?? "",
      "edge": Bar.edgeName(root.edge),
      "kind": "menu"
    }) : null
  on_ClaimChanged: ShellManager.setEdgeClaim(root, root._claim)

  // What's reserved along a screen edge (a Bar.Location), which this
  // window sits inside: the border, a bar, integrated menus. Docks are
  // left out: the window reaches past them.
  function reservedOn(location) {
    return EdgeMenuManager.reservedOn(root.screen, location);
  }

  // Along the edge, on the menu's lattice (GridPlacement.menuAlong),
  // in screen px: this window's edge coordinates start past what's
  // reserved on the perpendicular edge at its start
  readonly property real screenLength: root.vertical ? root.screen.height : root.screen.width
  readonly property int startSide: root.vertical ? Bar.Top : Bar.Left
  readonly property int endSide: root.vertical ? Bar.Bottom : Bar.Right
  readonly property real alongOrigin: root.reservedOn(root.startSide)
  // Held, the box keeps its gaps from the frame lines at its ends (in
  // this window's edge coordinates); else room for its fillets
  startInset: root.gaps ? Math.max(0, EdgeMenuManager.frameLineOn(root.screen, root.startSide) + root.gaps.start - root.alongOrigin) : root.filletMargin
  endInset: root.gaps ? Math.max(0, EdgeMenuManager.frameLineOn(root.screen, root.endSide) + root.gaps.end - root.reservedOn(root.endSide)) : root.filletMargin
  // The least room from the modules to the screen's ends: what's reserved
  // there, the box's inset and its padding
  readonly property real startPad: root.alongOrigin + root.startInset + root.contentPadding
  readonly property real endPad: root.reservedOn(root.endSide) + root.endInset + root.contentPadding
  // From config, so the hover strip lines up before the body has loaded
  // Its card size (EdgeMenuManager.cardUnitOf)
  readonly property int unit: EdgeMenuManager.cardUnitOf(root.menu)
  readonly property real gridLength: EdgeMenusConfig.gridLengthOf(root.menu, root.vertical, root.unit)
  readonly property real modulesStart: GridPlacement.menuAlong(root.menu, root.screenLength, root.unit, root.startPad, root.endPad)

  // Across the edge, in px from the screen edge
  readonly property real reservedBefore: root.reservedOn(root.edge)

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

  // A bar other than a solid one on this edge (BarPanel), while it shows:
  // a bar inside the border hides under fullscreen windows
  readonly property var barPanel: {
    const panel = ShellManager.barOn(root.screen?.name ?? "", root.edge);
    return panel?.visible && !panel.barConfig.solid ? panel : null;
  }
  readonly property var barConfig: root.barPanel?.barConfig ?? null
  readonly property var container: root.barPanel?.container ?? null
  // A floating bar's islands are read as pills (BarContainer.pillRects)
  readonly property bool island: root.barConfig?.island ?? false
  readonly property bool pillBar: (root.barConfig?.pills ?? false) || root.island
  readonly property bool attachedToPills: root.pillBar && !root.held
  // Along the edge, bar-window coordinates are this window's plus the
  // shift. The bar window reaches onto the perpendicular strokes and this
  // one sits inside them, taken as the same at both ends (as BarPopouts
  // does for the perpendicular borders).
  readonly property real barShift: root.container ? (root.container.length - root.edgeLength) / 2 : 0
  readonly property var pills: root.pillBar ? (root.container?.pillRects ?? []) : []
  // A pill's (or island's) far stroke, from the bar's outer edge
  readonly property real pillFoot: root.pillBar ? (root.island ? root.barConfig.extent : root.barConfig.pillDepth) - Appearance.borderWidth : 0
  readonly property real barBoxStart: root.boxStart + root.barShift
  readonly property real barBoxEnd: root.barBoxStart + root.boxLength
  readonly property real barSurfaceStart: root.surfaceStart + root.barShift

  // The pill a box from `start` to `end` (bar coordinates) fits within
  function pillAround(start, end) {
    const index = root.pills.findIndex(p => p.start <= start && end <= p.start + p.length);
    return index < 0 ? null : Object.assign({
      "index": index
    }, root.pills[index]);
  }
  // Never an island: the box grows from the edge past those too, so it
  // reads the same as on pills, only further out
  readonly property var ownPill: root.attachedToPills && !root.island ? root.pillAround(root.barBoxStart, root.barBoxEnd) : null
  // Not within a pill: grow from the bar's outer edge, deeper by the pills
  // so the content clears them, with every pill reached showing through a
  // notch (as BarPopouts.mergeWithPill)
  readonly property bool merged: root.attachedToPills && root.ownPill === null
  readonly property var mergedPills: {
    if (!root.merged)
      return [];
    const from = root.barSurfaceStart, to = from + root.surfaceLength;
    return root.pills.filter(p => p.start < to && p.start + p.length > from);
  }
  // A merged box whose side wall falls just short of a pill's stroke is
  // shifted onto it (see BarPopouts.pillSnap)
  function pillSnap(start) {
    const end = start + root.boxLength;
    if (root.pillAround(start, end) !== null)
      return 0;
    const bw = Appearance.borderWidth, r = Appearance.borderRadius;
    for (const p of root.pills) {
      const toEnd = p.start + bw - end;
      if (toEnd > 0 && toEnd <= root.connectorGap && p.start + p.length >= end + toEnd + r)
        return toEnd;
      const toStart = start - (p.start + p.length - bw);
      if (toStart > 0 && toStart <= root.connectorGap && p.start <= start - toStart - r)
        return -toStart;
    }
    return 0;
  }
  // Standing on a pill whose straight stroke is too short for the box's
  // fillets, the pill stretches to carry them while the menu shows
  readonly property var pillStretch: {
    const p = root.ownPill;
    // Not while the content loads or unloads: the box is a placeholder then
    if (!root.occupied || root.contentItem === null || p === null)
      return null;
    const r = Appearance.borderRadius;
    const start = p.joinStart ? p.start : Math.min(p.start, root.barSurfaceStart - r);
    const end = p.joinEnd ? p.start + p.length : Math.max(p.start + p.length, root.barSurfaceStart + root.surfaceLength + r);
    if (start === p.start && end === p.start + p.length)
      return null;
    return {
      "index": p.index,
      "start": start,
      "end": end
    };
  }
  // Written and cleared by hand, tagged with this menu, rather than by a
  // Binding: its restore on deactivation brought back a stale stretch
  property var _stretchTarget: null
  function _clearStretch() {
    try {
      if (root._stretchTarget?.edgeMenuStretch?.owner === root.menuId)
        root._stretchTarget.edgeMenuStretch = null;
    } catch (e) {
      // The bar went first (a reload)
    }
    root._stretchTarget = null;
  }
  function _pushStretch() {
    const target = root.pillStretch ? root.container : null;
    if (root._stretchTarget !== target)
      root._clearStretch();
    if (!target)
      return;
    root._stretchTarget = target;
    target.edgeMenuStretch = Object.assign({
      "owner": root.menuId
    }, root.pillStretch);
  }
  onPillStretchChanged: root._pushStretch()
  onContainerChanged: root._pushStretch()

  // Across the edge, in px from the screen edge. The bar's outer edge: on
  // the border's stroke inside the border, its frame line less its extent.
  readonly property real barOuter: root.barConfig ? EdgeMenuManager.frameLineOn(root.screen, root.edge) - root.barConfig.extent : 0
  // Where the window's attach edge goes by default: on the stroke of what
  // reserves the edge (none when straight)
  readonly property real attachBase: root.reservedBefore - (root.straight ? 0 : Appearance.borderWidth)
  // Where it goes: held, a connector gap short of where the box goes (a
  // detached box sits that far past its attach edge); else from a bar's
  // outer edge, the outer edge itself when merged, a pill's far stroke,
  // or a transparent bar's inner edge (the box a connector gap past it,
  // as a bar popout's is), or by default
  readonly property real attachAt: {
    if (root.gaps)
      return EdgeMenuManager.frameLineOn(root.screen, root.edge) + root.gaps.across - root.connectorGap / 2;
    if (root.barConfig === null)
      return root.attachBase;
    return root.barOuter + (root.merged ? 0 : root.pillBar ? root.pillFoot : root.barConfig.extent);
  }

  edge: EdgeMenusConfig.edgeOf(root.menu)
  // The box's centre, so it starts where the modules should, less its
  // padding. From its natural length (the joins at the ends depend on
  // where it is); one filling its edge joins both and needs none.
  position: 0
  positionOffset: root.modulesStart - root.alongOrigin - root.contentPadding + (isFinite(root._naturalBox) ? root._naturalBox / 2 : 0)
  detached: root.held || (root.barPanel !== null && !root.pillBar)
  edgeOffset: root.attachAt - root.attachBase
  // A detached box slides in from under what's on its edge: from a bar's
  // outer edge (past the border stroke it lies on inside the border), else
  // from the border's or a solid bar's stroke, or the bare screen edge
  slideDistance: root._overOverlay ? 0 : root.attachAt - (root.barConfig ? root.barOuter + (root.barConfig.insideBorder ? Appearance.borderWidth : 0) : root.attachBase)
  // Without the border, a merged box runs straight off the screen edge
  straight: root.merged ? !Appearance.screenBorder : root.bareEdge
  // Not held, its ends join the perpendicular edges once it reaches them.
  // Fill cells grow to whatever room there is, so reach them always.
  joinEnds: !root.held
  reachLength: root.contentItem ? (root.contentItem.fillsEdge ? Infinity : root.contentItem.naturalLength) : 0
  boxSnap: root.attachedToPills && !root.island ? (start => root.pillSnap(start + root.barShift)) : null
  attachClearance: root.merged ? root.pillFoot : 0
  startFoot: root.merged && root.pills.some(p => p.start <= root.barBoxStart - Appearance.borderRadius && p.start + p.length >= root.barBoxStart) ? root.pillFoot : 0
  endFoot: root.merged && root.pills.some(p => p.start <= root.barBoxEnd && p.start + p.length >= root.barBoxEnd + Appearance.borderRadius) ? root.pillFoot : 0
  // The pills' interiors, a stroke plus a pixel inside their free ends
  // (and an island's sides, see notchStart)
  notches: root.mergedPills.map(p => {
    const inset = Appearance.borderWidth + 1;
    const from = p.start + (p.joinStart ? 0 : inset);
    const to = p.start + p.length - (p.joinEnd ? 0 : inset);
    return {
      "start": from - root.barSurfaceStart,
      "length": Math.max(0, to - from),
      "roundStart": !p.joinStart && from > root.barSurfaceStart,
      "roundEnd": !p.joinEnd && to < root.barSurfaceStart + root.surfaceLength
    };
  })
  notchDepth: root.pillFoot - 1
  // An island's outer stroke sits floatGap in from the edge: the box fills
  // up to it, as it meets a pill's stroke on the edge
  notchStart: root.merged && root.island ? root.barConfig.islandStart + Appearance.borderWidth + 1 : 0
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
  Component.onDestruction: {
    root._clearStretch();
    ShellManager.setEdgeClaim(root, null);
  }

  content: Component {
    EdgeMenuBody {
      menu: root.menu
      vertical: root.vertical
      maxLength: root.maxBoxLength - root.contentPadding * 2
    }
  }
}
