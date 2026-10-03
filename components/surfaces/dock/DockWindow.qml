pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout

// One dock (a DockEntry) on one screen: a strip along its edge, inside the
// bars and border, holding a box of app icons. Held off the edge
// (`detached`) it's a plain rounded box `gap` in from the frame lines on
// its edge and at its ends (Bar.detachedGaps); otherwise the box grows out
// of the border's (or a solid bar's) stroke as popouts do
// (AttachedSurface), or runs straight off a bare screen edge. The window
// is as deep as the magnified icons, and only the box (and icons grown
// out of it) take input. Always shown
// docks may reserve their strip; hover and intellihide docks slide in from
// the edge through an EdgeTrigger. Everything along the dock is laid out
// here (`starts`, `sizes`), and each DockItem places itself from that.
Scope {
  id: root

  required property ShellScreen screen
  required property var dock

  readonly property int edge: Bar.getLocationFromString(root.dock.edge)
  readonly property bool vertical: root.edge === Bar.Left || root.edge === Bar.Right
  readonly property string mode: root.dock.visibility

  // --- Sizes ---
  readonly property real base: root.dock.iconSize
  readonly property real peak: root.dock.magnify ? Math.max(root.dock.magnifiedSize, root.base) : root.base
  readonly property real pad: root.dock.padding
  readonly property real spacing: root.dock.spacing
  readonly property real thickness: root.base + root.pad * 2

  // --- Attaching to the edge ---
  readonly property string _edgeName: Bar.edgeName(root.edge)
  readonly property var _edgeBar: Bar.edgesFor(root.screen)[root._edgeName]
  // Held off the edge, and its gaps from the frame lines across its edge
  // and at its ends (what places it, so a change of `held` never reads
  // them before they follow)
  readonly property bool held: root.dock.detached
  readonly property var gaps: root.held ? Bar.detachedGaps(root.screen, root.edge, root.dock.gap, HyprlandManager.gapsOut) : null
  // How far past where the window starts on a screen edge (what's
  // reserved there) a frame line plus `gap` lies
  function _heldOffset(location, gap) {
    return Math.max(0, EdgeMenuManager.frameLineOn(root.screen, location) + gap - EdgeMenuManager.reservedOn(root.screen, location));
  }
  // Not held, the box joins the edge's stroke: the border's or a solid
  // bar's. Any other bar has none, so it stays a box against the window's
  // edge.
  readonly property bool attached: !root.held && (!root._edgeBar || root._edgeBar.joinable)
  // No border and no bar there: it runs straight off the screen edge
  readonly property bool straight: root.attached && Bar.screenEdgeOpen(root.screen, root.edge)
  readonly property int connectorGap: Appearance.borderRadius * 2
  // An attached window reaches onto the stroke it joins, as EdgePopout's
  readonly property real edgeMargin: root.attached && !root.straight ? -Appearance.borderWidth : 0
  // From the window's edge to the box
  readonly property real boxOffset: root.attached ? root.connectorGap / 2 : root.gaps ? root._heldOffset(root.edge, root.gaps.across) : 0
  // The window: the gap to the edge, the box, and room for icons to grow
  // (and for an attached surface's far side)
  readonly property real depth: root.boxOffset + root.thickness + Math.max(root.peak - root.base, root.attached ? root.connectorGap / 2 : 0) + 2

  // --- Items ---
  // Re-read on every window change; delegates are keyed by the joined
  // keys, so they only rebuild when the set of apps changes
  readonly property var items: DockManager.itemsFor(root.dock, root.screen)
  readonly property string _keysJoined: root.items.map(item => item.key).join("\n")
  readonly property var keys: root._keysJoined ? root._keysJoined.split("\n") : []
  readonly property int count: root.keys.length
  readonly property int pinnedCount: root.items.filter(item => item.pinned).length
  readonly property bool separator: root.dock.separator && root.dock.showRunning && root.pinnedCount > 0 && root.pinnedCount < root.count
  readonly property real lineWidth: Math.max(1, Appearance.borderWidth)
  readonly property real separatorLength: root.separator ? root.spacing + root.lineWidth : 0

  // --- Along the dock ---
  readonly property real length: root.vertical ? window.height : window.width
  readonly property real restLength: root.count * root.base + Math.max(0, root.count - 1) * root.spacing + root.separatorLength + root.pad * 2
  // The least room from the box to each end: held, its gaps from the
  // frame lines there; else a screen margin, and an attached box's fillets
  readonly property real startMargin: root.gaps ? root._heldOffset(root.vertical ? Bar.Top : Bar.Left, root.gaps.start) : root._freeMargin
  readonly property real endMargin: root.gaps ? root._heldOffset(root.vertical ? Bar.Bottom : Bar.Right, root.gaps.end) : root._freeMargin
  readonly property real _freeMargin: Appearance.screenMargin + (root.attached && !root.straight ? root.connectorGap : 0)
  // The box's centre at rest, kept within those
  readonly property real centre: {
    const wanted = root.length * root.dock.position / 100;
    if (root.restLength + root.startMargin + root.endMargin >= root.length)
      return (root.startMargin + root.length - root.endMargin) / 2;
    return Math.max(root.restLength / 2 + root.startMargin, Math.min(wanted, root.length - root.restLength / 2 - root.endMargin));
  }
  readonly property real restStart: root.centre - root.restLength / 2

  // Magnification: the pointer along the row as laid out at rest, and how
  // far the icons have grown towards it (animated in and out)
  property real pointer: -1
  property real magnifyAmount: root.dock.magnify && hover.hovered && root.dragIndex < 0 ? 1 : 0
  Behavior on magnifyAmount {
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Appearance.easing
    }
  }
  readonly property real _step: root.base + root.spacing
  readonly property var sizes: {
    let p = root.pointer - root.restStart - root.pad;
    if (root.separator && p > root.pinnedCount * root._step)
      p = Math.max(root.pinnedCount * root._step, p - root.separatorLength);
    const full = DockLayout.magnifiedSizes(root.count, root.pointer < 0 ? null : p, root.base, root.peak, root.dock.magnifyRange, root.spacing);
    return full.map(size => root.base + (size - root.base) * root.magnifyAmount);
  }
  readonly property real currentLength: root.sizes.reduce((sum, size) => sum + size, 0) + Math.max(0, root.count - 1) * root.spacing + root.separatorLength + root.pad * 2
  readonly property real boxStart: root.centre - root.currentLength / 2
  // Where each icon starts along the window
  readonly property var starts: {
    const starts = [];
    let at = root.boxStart + root.pad;
    for (let i = 0; i < root.count; i++) {
      if (root.separator && i === root.pinnedCount)
        at += root.separatorLength;
      starts.push(at);
      at += root.sizes[i] + root.spacing;
    }
    return starts;
  }
  readonly property real grown: Math.max(0, ...root.sizes) - root.base

  // --- Across the dock ---
  // How far it has slid in (0 hidden, 1 shown)
  property real shown: root.wantShown ? 1 : 0
  Behavior on shown {
    NumberAnimation {
      duration: Appearance.animNormal
      easing.type: Appearance.easing
    }
  }
  readonly property real slide: (1 - root.shown) * root.depth

  // The cross-axis position (window coordinates) of something `fromEdge`
  // in from the dock's edge and `size` deep
  function crossAt(fromEdge, size) {
    switch (root.edge) {
    case Bar.Bottom:
      return window.height - fromEdge - size + root.slide;
    case Bar.Right:
      return window.width - fromEdge - size + root.slide;
    }
    return fromEdge - root.slide;
  }

  // --- Showing and hiding ---
  readonly property bool fullscreen: HyprlandManager.hasFullscreen(root.screen?.name ?? "")
  readonly property bool hiddenByHand: !!DockManager.hidden[root.dock.id]
  // Opened by the trigger (after openDelay), a reveal, or the pointer on
  // the shown dock, until the pointer has been gone for closeDelay. Only
  // `latched` opens it: resting on the trigger doesn't, or openDelay would
  // be skipped, and a dock shown without latching would close at once.
  property bool latched: false
  // Whether the pointer has been on it since it latched: a reveal nobody
  // hovers (IPC, a bind) stays up a little longer than closeDelay
  property bool _touched: false
  // Something on the dock is in use
  property int dragIndex: -1
  readonly property bool menuOpen: menu.active
  readonly property bool engaged: hover.hovered || root.menuOpen || root.dragIndex >= 0
  // The pointer on the trigger while the dock is on screen (intellihide
  // showing it, or sliding out) holds it at once: openDelay is only for
  // opening a hidden dock
  readonly property bool _triggerHold: trigger.containsMouse && root.shown > 0
  readonly property bool _holding: root.engaged || root._triggerHold
  on_HoldingChanged: {
    if (root._holding) {
      root.latched = true;
      root._touched = true;
    }
  }
  // Keeps a latched dock open; the trigger counts, so a pointer resting on
  // the edge never lets it close
  readonly property bool pointerIn: root.engaged || trigger.containsMouse
  readonly property bool obscured: root.mode === "intellihide" && DockManager.obscured(root.screen, root._restRect())
  // The overlay on this screen puts it away, whatever its visibility, unless
  // it reserves its strip (hiding that would retile the windows under it)
  readonly property bool overlayOpen: ShellManager.surfaceOpenOn("overlay", root.screen)
  readonly property bool underOverlay: root.overlayOpen && !root.reserving
  // An edge OSD or floating edge menu on its edge puts it away too, a
  // reserving one included: that keeps its zone, so nothing retiles
  readonly property bool outranked: ShellManager.edgeOutranked(root.screen?.name ?? "", root._edgeName, "dock")
  readonly property bool away: root.underOverlay || root.outranked
  onAwayChanged: {
    if (root.away)
      root.conceal();
  }
  readonly property bool wantShown: {
    if (root.away)
      return false;
    if (root.mode === "always")
      return !root.hiddenByHand;
    return root.latched || root.engaged || (root.mode === "intellihide" && !root.obscured);
  }
  readonly property bool reserving: root.mode === "always" && root.dock.reserveSpace && !root.hiddenByHand && root.count > 0

  // The shown box on the monitor (its work area's origin being the
  // reserved zones' corner), for intellihide
  function _restRect() {
    const reserved = DockManager.reservedOf(root.screen);
    const along = root.restStart;
    const across = root.boxOffset + root.edgeMargin;
    const w = root.screen?.width ?? 0;
    const h = root.screen?.height ?? 0;
    switch (root.edge) {
    case Bar.Top:
      return Qt.rect(reserved[0] + along, reserved[1] + across, root.restLength, root.thickness);
    case Bar.Left:
      return Qt.rect(reserved[0] + across, reserved[1] + along, root.thickness, root.restLength);
    case Bar.Right:
      return Qt.rect(w - reserved[2] - across - root.thickness, reserved[1] + along, root.thickness, root.restLength);
    }
    return Qt.rect(reserved[0] + along, h - reserved[3] - across - root.thickness, root.restLength, root.thickness);
  }

  function reveal(byPointer) {
    // Put away, it would only latch to show once whatever outranks it goes
    if (root.away)
      return;
    root._touched = !!byPointer || root.engaged;
    root.latched = true;
    // Only restart a countdown that's due: restart() starts the timer even
    // while its binding says not to (the pointer on the dock or trigger)
    if (!root.pointerIn)
      closeTimer.restart();
  }

  function conceal() {
    root.latched = false;
    root.closeMenu();
  }

  Timer {
    id: closeTimer
    interval: root._touched ? root.dock.closeDelay : Math.max(root.dock.closeDelay, 1500)
    running: root.latched && !root.pointerIn
    onTriggered: root.latched = false
  }

  Connections {
    target: DockManager

    function onRevealRequested(id) {
      if (id === root.dock.id)
        root.reveal();
    }

    function onConcealRequested(id) {
      if (id === root.dock.id)
        root.conceal();
    }

    function onToggleRequested(id) {
      if (id !== root.dock.id)
        return;
      if (root.wantShown)
        root.conceal();
      else
        root.reveal();
    }
  }

  // --- Menus (hover: names and windows; right click: everything) ---
  property string menuKey: ""
  property bool menuFull: false
  readonly property int menuIndex: root.keys.indexOf(root.menuKey)

  function openMenu(key, full) {
    root.menuKey = key;
    root.menuFull = full;
  }

  function closeMenu() {
    root.menuKey = "";
    root.menuFull = false;
  }

  // Pointer along the window, kept after it leaves so icons shrink back
  // from where it was
  readonly property real _livePointer: root.vertical ? hover.point.position.y : hover.point.position.x
  on_LivePointerChanged: {
    if (hover.hovered)
      root.pointer = root._livePointer;
  }

  EdgeTrigger {
    id: trigger
    screen: root.screen
    visible: root.mode !== "always" && !root.fullscreen && !root.away && root.count > 0
    edge: root.edge
    // Placed along the work area (inside the reserved zones), as the dock is
    position: 0
    startInset: 0
    endInset: 0
    positionOffset: DockManager.reservedOf(root.screen)[root.vertical ? 1 : 0] + root.centre
    triggerWidth: root.dock.triggerSize
    triggerLength: root.restLength
    hoverDelay: root.dock.openDelay
    onTriggered: root.reveal(true)
  }

  PanelWindow {
    id: window

    screen: root.screen
    color: "transparent"
    visible: root.count > 0

    // Top, with its layer rule ordering it after the border and bars: it
    // sits inside them without shortening the bars on the other edges. A
    // fullscreen window covers it.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "axiom-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    // Hyprland counts the edge margin into it, so windows start at the box
    exclusiveZone: root.reserving ? root.boxOffset + root.thickness : 0
    // Windows retile around it without an event saying so
    onExclusiveZoneChanged: DockManager.refreshSoon()

    // What it takes off the work area (Hyprland counts the edge margin
    // in), for the EdgePopouts and border corners that reach past it
    readonly property real reserved: window.visible && exclusiveZone > 0 ? exclusiveZone + root.edgeMargin : 0
    // Where it's reported. The zone set last is kept, so moving the dock to
    // another edge (or renaming it) moves its zone instead of leaving the
    // old one behind, and destruction clears it even once `dock` is gone.
    readonly property var zoneKey: root.dock ? [root.screen?.name ?? "", root._edgeName, root.dock.id] : null
    property var _zoneSet: null
    function _publishZone() {
      const key = window.zoneKey;
      const old = window._zoneSet;
      if (old && (!key || old.join(":") !== key.join(":"))) {
        DockManager.setZone(old[0], old[1], old[2], 0);
        DockManager.refreshSoon();
      }
      if (key)
        DockManager.setZone(key[0], key[1], key[2], window.reserved);
      window._zoneSet = key;
    }
    onReservedChanged: window._publishZone()
    onZoneKeyChanged: window._publishZone()
    Component.onCompleted: window._publishZone()
    Component.onDestruction: {
      const old = window._zoneSet;
      if (old)
        DockManager.setZone(old[0], old[1], old[2], 0);
    }

    anchors {
      top: root.edge !== Bar.Bottom
      bottom: root.edge !== Bar.Top
      left: root.edge !== Bar.Right
      right: root.edge !== Bar.Left
    }
    implicitWidth: root.vertical ? root.depth : 0
    implicitHeight: root.vertical ? 0 : root.depth

    margins {
      top: root.edge === Bar.Top ? root.edgeMargin : 0
      bottom: root.edge === Bar.Bottom ? root.edgeMargin : 0
      left: root.edge === Bar.Left ? root.edgeMargin : 0
      right: root.edge === Bar.Right ? root.edgeMargin : 0
    }

    // The box and the icons grown out of it, and the gap to the edge (so
    // the pointer doesn't leave the dock on its way from the edge); nothing
    // while it's hidden
    mask: Region {
      item: inputArea
    }

    Item {
      id: inputArea
      readonly property real alongStart: root.boxStart
      readonly property real alongLength: root.shown > 0 ? root.currentLength : 0
      readonly property real crossDepth: root.shown > 0 ? root.boxOffset + root.thickness + root.grown : 0

      x: root.vertical ? root.crossAt(0, crossDepth) : alongStart
      y: root.vertical ? alongStart : root.crossAt(0, crossDepth)
      width: root.vertical ? crossDepth : alongLength
      height: root.vertical ? alongLength : crossDepth
    }

    Item {
      id: content
      anchors.fill: parent

      HoverHandler {
        id: hover
      }

      // The box, joined to the edge
      AttachedSurface {
        id: surface
        visible: root.attached
        x: root.vertical ? root.crossAt(0, width) : root.boxStart - startMargin
        y: root.vertical ? root.boxStart - startMargin : root.crossAt(0, height)
        width: implicitWidth
        height: implicitHeight

        edge: root.edge
        active: true
        straight: root.straight
        connectorGap: root.connectorGap
        boxWidth: root.vertical ? root.thickness : root.currentLength
        boxHeight: root.vertical ? root.currentLength : root.thickness
        fillColor: Theme.resolveColor(root.dock.backgroundColor)
        strokeColor: Theme.resolveColor(root.dock.borderColor)
      }

      // Or a box of its own
      Rectangle {
        visible: !root.attached
        x: root.vertical ? root.crossAt(root.boxOffset, root.thickness) : root.boxStart
        y: root.vertical ? root.boxStart : root.crossAt(root.boxOffset, root.thickness)
        width: root.vertical ? root.thickness : root.currentLength
        height: root.vertical ? root.currentLength : root.thickness
        radius: Math.min(Appearance.borderRadius, root.thickness / 2)
        color: Theme.resolveColor(root.dock.backgroundColor)
        border.color: Theme.resolveColor(root.dock.borderColor)
        border.width: Appearance.borderWidth
      }

      // Between the pinned apps and the others
      Rectangle {
        visible: root.separator
        readonly property real along: (root.starts[root.pinnedCount] ?? 0) - root.spacing - root.lineWidth
        readonly property real across: root.thickness - root.pad

        x: root.vertical ? root.crossAt(root.boxOffset + root.pad / 2, across) : along
        y: root.vertical ? along : root.crossAt(root.boxOffset + root.pad / 2, across)
        width: root.vertical ? across : root.lineWidth
        height: root.vertical ? root.lineWidth : across
        color: Theme.resolveColor(root.dock.borderColor)
        opacity: 0.5
      }

      Repeater {
        id: repeater
        model: root.keys

        delegate: DockItem {
          dockWindow: root
        }
      }
    }
  }

  DockMenu {
    id: menu
    dockWindow: root
    anchorItem: root.menuIndex >= 0 ? repeater.itemAt(root.menuIndex) as DockItem : null
    grabWindow: window
  }
}
