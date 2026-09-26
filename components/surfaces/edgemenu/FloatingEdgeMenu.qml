pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout

// A floating edge menu: an EdgePopout over the windows, growing out of the
// border or a solid bar on its edge. On a pill bar it attaches as a bar
// popout does: standing on a pill's far stroke when it fits within one,
// else growing from the bar's outer edge with the pills showing through.
// On a transparent bar there's nothing to grow out of, so it's a detached
// box where a bar popout's would be; so is one set a distance off the edge
// (edgeDistance).
EdgePopout {
  id: root

  required property var menu
  readonly property string menuId: root.menu?.id ?? ""
  // Pinned, or held open by the editor
  readonly property bool pinned: EdgeMenuManager.isHeld(root.menuId)
  readonly property bool wanted: EdgeMenuManager.openMenus[root.menuId] === true

  readonly property real edgeDistance: root.menu?.edgeDistance ?? 0

  // A transparent or pill bar on this edge (BarPanel), while it shows: a
  // floating bar hides under fullscreen windows
  readonly property var barPanel: {
    const panel = ShellManager.barOn(root.screen?.name ?? "", root.edge);
    return panel?.visible && panel.barConfig.background !== "solid" ? panel : null;
  }
  readonly property var barConfig: root.barPanel?.barConfig ?? null
  readonly property var container: root.barPanel?.container ?? null
  readonly property bool pillBar: root.barConfig?.pills ?? false
  readonly property bool attachedToPills: root.pillBar && root.edgeDistance === 0
  // Along the edge, bar-window coordinates are this window's plus the
  // shift. The bar window reaches onto the perpendicular strokes and this
  // one sits inside them, taken as the same at both ends (as BarPopouts
  // does for the perpendicular borders).
  readonly property real barShift: root.container ? (root.container.length - root.edgeLength) / 2 : 0
  readonly property var pills: root.pillBar ? (root.container?.pillRects ?? []) : []
  // A pill's far stroke, from the bar's outer edge
  readonly property real pillFoot: root.pillBar ? root.barPanel.barConfig.pillDepth - Appearance.borderWidth : 0
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
  readonly property var ownPill: root.attachedToPills ? root.pillAround(root.barBoxStart, root.barBoxEnd) : null
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

  // Where the window's attach edge goes, from the bar's outer edge: the
  // outer edge itself when merged, a pill's far stroke, or a transparent
  // bar's inner edge (a detached box sits a connector gap past it, as a
  // bar popout's does)
  readonly property real barAttachDepth: {
    if (root.barPanel === null || root.merged)
      return 0;
    return (root.pillBar ? root.pillFoot : root.barPanel.barConfig.extent) + root.edgeDistance;
  }

  // Where the windows start, from the bar's outer edge: past its reserved
  // space, or, reserving none, past the border (whose stroke a floating
  // bar's outer edge lies on)
  readonly property real barReach: {
    const zone = root.barPanel?.reservedZone ?? 0;
    return zone > 0 || !root.barConfig?.floating ? zone : Appearance.borderWidth;
  }

  edge: EdgeMenusConfig.edgeOf(root.menu)
  position: (root.menu?.position ?? 50) / 100
  detached: root.edgeDistance > 0 || (root.barPanel !== null && !root.pillBar)
  // The window would sit where the windows start, less a border width
  // (none when straight)
  edgeOffset: root.barPanel ? root.barAttachDepth - root.barReach + (root.straight ? 0 : Appearance.borderWidth) : root.edgeDistance
  // Without the border, a merged box runs straight off the screen edge
  straight: root.merged ? !Appearance.screenBorder : root.bareEdge
  // At 0px its ends join the perpendicular edges once it reaches them.
  // Fill cells grow to whatever room there is, so reach them always.
  joinEnds: root.edgeDistance === 0
  reachLength: root.contentItem ? (root.contentItem.anyFill ? Infinity : root.contentItem.naturalLength) : 0
  boxSnap: root.attachedToPills ? (start => root.pillSnap(start + root.barShift)) : null
  attachClearance: root.merged ? root.pillFoot : 0
  startFoot: root.merged && root.pills.some(p => p.start <= root.barBoxStart - Appearance.borderRadius && p.start + p.length >= root.barBoxStart) ? root.pillFoot : 0
  endFoot: root.merged && root.pills.some(p => p.start <= root.barBoxEnd && p.start + p.length >= root.barBoxEnd + Appearance.borderRadius) ? root.pillFoot : 0
  // The pills' interiors, a stroke plus a pixel inside their free ends
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
  contentPadding: root.menu?.padding ?? Widget.spacing
  fillColor: EdgeMenusConfig.colorsOf(root.menu).fill
  strokeColor: EdgeMenusConfig.colorsOf(root.menu).stroke
  triggerEnabled: root.menu?.openOnHover ?? false
  hoverDelay: root.menu?.openDelay ?? PopoutConfig.openDelay
  triggerWidth: root.menu?.triggerSize ?? PopoutConfig.edgeTriggerSize
  // 0: the menu's own length (from config until it's first loaded)
  triggerLength: (root.menu?.triggerLength ?? 0) > 0 ? root.menu.triggerLength : root.contentItem ? (root.vertical ? root.contentItem.implicitHeight : root.contentItem.implicitWidth) + root.contentPadding * 2 : EdgeMenusConfig.lengthOf(root.menu, root.vertical)
  dismissDelay: root.menu?.closeDelay ?? PopoutConfig.dismissDelay
  keyboardOnDemand: true
  closeOnClickOutside: (root.menu?.closeOnOutsideClick ?? false) && !root.pinned
  autoDismiss: (root.menu?.closeOnLeave ?? true) && !root.pinned
  onAutoDismissChanged: root.updateDismissTimer()

  // Follow EdgeMenuManager, and tell it when the popout closes by itself
  function _sync() {
    if (root.wanted && !root.isOpen)
      root.show({
        "anchorItem": EdgeMenuManager.anchors[root.menuId] ?? null
      });
    else if (!root.wanted && root.isOpen)
      root.hide();
  }
  onWantedChanged: _sync()
  onIsOpenChanged: {
    if (!root.isOpen && root.wanted && !root.hasPendingOpen)
      EdgeMenuManager.close(root.menuId);
    else if (root.isOpen && !root.wanted)
      EdgeMenuManager.open(root.menuId, null);
  }
  Component.onCompleted: {
    ShellManager.registerGrabPartner(root.window, root.screen?.name ?? "");
    Qt.callLater(root._sync);
  }
  Component.onDestruction: {
    ShellManager.unregisterGrabPartner(root.window);
    root._clearStretch();
  }

  content: Component {
    EdgeMenuBody {
      menu: root.menu
      vertical: root.vertical
      maxLength: root.maxBoxLength - root.contentPadding * 2
    }
  }
}
