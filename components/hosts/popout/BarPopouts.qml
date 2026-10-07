pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.services
import qs.config
import qs.components.methods
// Imported (though loaded by URL) so qs scans the content types
import qs.components.content // qmllint disable unused-imports
import qs.components.reusable

/**
 * Popout wrapper for bar widgets
 * Handles positioning, animation, and content loading for popouts that emerge from the bar.
 * Opened from a widget under or beside the open box, it switches in place
 * (canSwitchTo): the box glides to the new widget and resizes while the
 * old content, held as a still, fades out over the new.
 * Open/close/queue state and dismiss timing live in PopoutWrapperBase — this
 * file only adds what's specific to bar popouts: which content type to
 * load, where to position it, and how to animate it in/out.
 */
PopoutWrapperBase {
  id: root

  required property ShellScreen screen
  required property var barConfig
  required property QtObject panel

  // The window showing the popout: on a transparent bar, a layer surface
  // of its own under the bar (a popup always draws over its parent), so a
  // detached box slides out from beneath the bar rather than out of thin
  // air at its invisible inner edge. Else a popup of the bar, which also
  // draws over the overlay: while that's open here, the box shows from
  // the popup instead, without sliding (the under-bar layer is ordered
  // under the overlay, see HyprlandManager's layer rules).
  readonly property bool underBar: root.barConfig.background === "transparent" && !ShellManager.surfaceOpenOn("overlay", root.screen)
  readonly property var popupWindow: root.underBar ? underWindow : mainPopup
  // Content box in popupWindow coordinates (see AttachedSurface.boxRect)
  readonly property rect boxRect: Qt.rect(surface.x + surface.boxRect.x, surface.y + surface.boxRect.y, surface.boxRect.width, surface.boxRect.height)

  // Which side the tray's submenus open to
  readonly property bool openToLeft: root.barConfig.right || mainPopup.isOnRightHalfOfScreen

  // ---- Tray submenus (TraySubmenuWrapper) ----
  // An open submenu, beside the box, asks it (the content's sideStretch:
  // { top, bottom, squareTop, squareBottom }) to reach past its top or
  // bottom to carry one longer than its side, and to square its corner
  // where one runs flush to its end, as a pill or island does for a popout
  // (EdgeAttach.place). Along y in both orientations: submenus open to the
  // left or right.
  readonly property var _sideStretch: root.occupied ? (root._content?.sideStretch ?? null) : null
  property real shownStretchTop: root._sideStretch?.top ?? 0
  property real shownStretchBottom: root._sideStretch?.bottom ?? 0
  Glide on shownStretchTop {
    enabled: still.settled
  }
  Glide on shownStretchBottom {
    enabled: still.settled
  }
  readonly property real _stretchAcross: root.barConfig.vertical ? 0 : (root._sideStretch?.top ?? 0) + (root._sideStretch?.bottom ?? 0)
  readonly property real _shownStretchAcross: root.barConfig.vertical ? 0 : root.shownStretchTop + root.shownStretchBottom
  // The box at rest, without a submenu's stretch: what submenus attach to,
  // in popupWindow coordinates
  readonly property rect attachBox: Qt.rect(root.boxRect.x, root.boxRect.y + root.shownStretchTop, root.boxRect.width, root.boxRect.height - root.shownStretchTop - root.shownStretchBottom)
  // At the bar side of a horizontal bar's box, a submenu with no room for
  // its fillet joins the stroke the box grows from, as a popout joins the
  // perpendicular border: a solid bar's, a pill's or island's far stroke
  // (stretched to carry it, see pillStretch), or the border at the outer
  // edge (merged). A detached box's ends there instead, flush to the box.
  readonly property bool _sideJoins: !root.barConfig.vertical && !mainPopup.detached
  readonly property bool sideJoinTop: root._sideJoins && root.barConfig.top
  readonly property bool sideJoinBottom: root._sideJoins && root.barConfig.bottom
  // The stroke it joins, its outer edge (the surface's attach edge), as y
  // in popupWindow coordinates; a bare screen edge is joined straight
  readonly property real sideJoinLine: root.barConfig.bottom ? surface.y + surface.height - surface.backfill : surface.y + surface.backfill
  readonly property bool sideStraightJoin: root.mergeWithPill && !Appearance.screenBorder
  // The backfill row the box takes past its attach edge (on a pill or
  // island), which a joined submenu covers beside it
  readonly property real sideJoinBackfill: surface.backfill
  // How far along it (x in popupWindow coordinates) that stroke reaches
  // without a submenu: the pill or island as the box stretches it, else
  // the bar's ends. A joined submenu whose fillet (and the corner past it)
  // lands within keeps it; any other runs straight up into the pill or
  // island's end, stretched to its wall and squared (pillStretch), as a
  // bar popout runs flush into one.
  readonly property real sideJoinFrom: (root.anchorPill !== null && !root.mergeWithPill ? (root.place.stretch?.start ?? root.anchorPill.start) : mainPopup.strokeStart) - mainPopup.windowFrom
  readonly property real sideJoinTo: (root.anchorPill !== null && !root.mergeWithPill ? (root.place.stretch?.end ?? root.anchorPill.start + root.anchorPill.length) : mainPopup.strokeEnd) - mainPopup.windowFrom
  // The ends of the side submenus open on that one may run flush to: the
  // far edge's, not a joined end, and on a horizontal bar its bar side's
  // where nothing's joined there
  readonly property bool sideFreeTop: root.barConfig.vertical ? !root.place.joinStart : root.barConfig.bottom || !root._sideJoins
  readonly property bool sideFreeBottom: root.barConfig.vertical ? !root.place.joinEnd : root.barConfig.top || !root._sideJoins
  // A submenu longer than the side hangs past its far end: up on a bottom
  // bar
  readonly property bool sideGrowsUp: root.barConfig.bottom
  // The box's corners a submenu squares: on a vertical bar its far edge's
  // top and bottom (AttachedSurface's start/end), on a horizontal one
  // those of the side it opens on, the far one, or a detached box's near
  // one at its bar side
  readonly property bool _squareTop: root._sideStretch?.squareTop ?? false
  readonly property bool _squareBottom: root._sideStretch?.squareBottom ?? false
  readonly property bool _squareFar: root.barConfig.top ? root._squareBottom : root._squareTop
  readonly property bool _squareNear: !root.barConfig.vertical && (root.barConfig.top ? root._squareTop : root._squareBottom)
  readonly property bool squareStartCorner: root.barConfig.vertical ? root._squareTop : root.openToLeft && root._squareFar
  readonly property bool squareEndCorner: root.barConfig.vertical ? root._squareBottom : !root.openToLeft && root._squareFar
  // Joined at the bar side, the stroke the box's wall there ran flush into
  // carries on past it, under the submenu
  readonly property bool _sideJoined: !root.barConfig.vertical && (root._sideStretch?.joined ?? false)
  readonly property bool squareStartNear: root.openToLeft && root._squareNear
  readonly property bool squareEndNear: !root.openToLeft && root._squareNear
  // Where the popout's window is on screen, for a submenu's (its popup)
  // blur: null until the bar's is known
  readonly property var popupScreenOrigin: surface.barOrigin ? Qt.point(surface.barOrigin.x + mainPopup.barX - surface.x, surface.barOrigin.y + mainPopup.barY - surface.y) : null
  // The stroke a submenu covers on the box's side, left open (in
  // popupWindow coordinates), as its fill no longer hides it
  property var submenuHole: null
  // ---- end tray submenus ----

  // content/<name>.qml, loaded by URL like bar widgets and overlay modules:
  // a new popout is just a file there plus a PopoutAnchor naming it. The
  // name travels inside the payload (`name`, see PopoutAnchor.qml) rather
  // than as a separate argument, so this file never needs to override
  // openPopout/safeOpenPopout from the base.
  function _loadContent() {
    root._payloadApplied = false;
    const name = root.currentData?.name ?? "";
    if (loader.active && name !== "") {
      const url = Qt.resolvedUrl("../../content/" + name + ".qml");
      // The same type for another widget (a switch in place) is built anew
      if (loader.source.toString() === url.toString())
        loader.source = "";
      loader.setSource(url, {
        "wrapper": root
      });
    } else if (!loader.active)
      // Cleared, so reactivating doesn't first rebuild the previous popout
      loader.source = "";
  }

  currentItem: loader.item ?? null
  // Loaded, and done fetching anything it must show before mapping (the
  // tray menu's contentReady); content without the property is ready
  // The Loader reports Ready before its onLoaded hands the content its
  // payload (the widget's data, which can size it), so it waits for that
  readonly property bool contentReady: loader.status === Loader.Ready && root._payloadApplied && (root.currentItem?.contentReady ?? true)
  property bool _payloadApplied: false

  // Content with a text field up asks for the keyboard (Panel's
  // wantsKeyboardFocus): a focus grab over the popout and its bar, which a
  // click outside clears (the content's focusLost())
  readonly property bool wantsKeyboardFocus: root.popupWindow.visible && (root.currentItem?.wantsKeyboardFocus ?? false)

  HyprlandFocusGrab {
    windows: [root.popupWindow, root.panel].concat(ShellManager.modalWindows)
    active: root.wantsKeyboardFocus
    onCleared: root.currentItem?.focusLost?.()
  }

  // Positioners (Row, Column, Grid, Flow) lay out on their window's
  // polish, which a window not yet mapped never runs: until then their
  // implicit size is 0, so content built from them (the workspace grid)
  // would map too small and grow a frame later. On a bottom or right bar
  // the popup then has to move as well, which the compositor doesn't
  // always follow, leaving it off the screen. So the loaded content is
  // laid out at once, innermost first.
  function _layOut(item) {
    for (const child of item.children)
      root._layOut(child);
    if (typeof item.forceLayout === "function")
      item.forceLayout();
  }

  // Gap between bar and main content (connector thickness)
  property int connectorGap: Appearance.borderRadius * 2

  // The bar's BarContainer. Its layoutUpdated signal re-anchors an open
  // popout, so it stays attached to a widget that moves or resizes.
  property var layoutSource: null

  // Where the anchor widget currently is, in bar-window coordinates. Read
  // live from currentData.anchorItem; the anchorX/anchorY snapshot in the
  // payload is only the fallback for callers that don't pass an item.
  property rect anchorRect: Qt.rect(0, 0, 0, 0)

  function updateAnchorRect() {
    const data = root.currentData;
    if (!data)
      return;
    const item = data.anchorItem;
    if (item) {
      try {
        const pos = item.mapToItem(null, 0, 0);
        root.anchorRect = Qt.rect(pos.x, pos.y, item.width, item.height);
        return;
      } catch (e) {
        // Anchor was destroyed (e.g. the bar rebuilt on a config reload)
      }
    }
    root.anchorRect = Qt.rect(data.anchorX ?? 0, data.anchorY ?? 0, data.anchorWidth ?? 0, data.anchorHeight ?? 0);
  }

  // Every payload loads afresh: a switch in place may bring the same
  // content type with another widget's data
  onCurrentDataChanged: {
    updateAnchorRect();
    _loadContent();
  }

  // ---- Switching in place ----
  // A widget under the box, or within a connector gap of it, along the bar
  canSwitchTo: (anchor, data) => {
    const item = data?.anchorItem;
    if (anchor !== root.currentAnchor || !still.showing || !item)
      return false;
    const pos = item.mapToItem(null, 0, 0);
    const from = root.barConfig.vertical ? pos.y : pos.x;
    const to = from + (root.barConfig.vertical ? item.height : item.width);
    return from <= mainPopup.boxEnd + root.connectorGap && to >= mainPopup.boxStart - root.connectorGap;
  }
  // The old content held as a still where it is along the bar
  // (SwitchStill), then the new payload opened under it
  prepareSwitch: done => still.prepare(root.currentItem, done)
  // ---- end switching in place ----

  // On a pill bar: its pills ({ start, length, joinStart, joinEnd } along
  // the bar). A floating bar's islands are read the same way. Where the
  // box goes along the bar, and how it meets them, is EdgeAttach.place's
  // (shared with edge popouts and docks): growing out of the anchor's
  // pill or island, stretching it to carry the box. Only a pill bar
  // showing no pills leaves it to grow from the bar's outer edge (merged),
  // its box as deep as the pills would be.
  readonly property bool island: root.barConfig.island
  readonly property var pills: root.barConfig.pills || root.island ? (root.layoutSource?.pillRects ?? []) : []
  readonly property real anchorCentre: root.barConfig.vertical ? root.anchorRect.y + root.anchorRect.height / 2 : root.anchorRect.x + root.anchorRect.width / 2
  readonly property var place: EdgeAttach.place({
    "pills": root.pills,
    "pillBar": root.barConfig.pills,
    "island": root.island,
    "merge": root.barConfig.pillMerge,
    "centre": root.anchorCentre,
    "aligned": mainPopup.alignedBoxStart,
    "length": mainPopup.boxLength,
    "joinStart": mainPopup.joins.joinStart,
    "joinEnd": mainPopup.joins.joinEnd,
    "joinFrom": mainPopup.strokeStart,
    "joinTo": mainPopup.strokeEnd,
    "lo": mainPopup.minAlong + mainPopup.filletMargin,
    "hi": mainPopup.maxAlong - mainPopup.filletMargin,
    "islandFrom": mainPopup.islandStart,
    "islandTo": mainPopup.islandEnd,
    "straight": false,
    "straightMerged": !Appearance.screenBorder,
    "nudge": true,
    "gap": root.connectorGap,
    "stroke": Appearance.borderWidth,
    "radius": Appearance.borderRadius
  })
  readonly property var anchorPill: root.place.pill
  readonly property bool mergeWithPill: root.place.mode === "merged"
  // A pill's (or island's) far stroke, from the bar's outer edge
  readonly property real pillFoot: (root.island ? root.barConfig.extent : root.barConfig.pillDepth) - Appearance.borderWidth
  // The pill (or island) stretched to carry the box's fillets while it shows
  // and to a joined tray submenu's outer wall where its fillet doesn't
  // land on it (sideStretch.joinReach, x in the popup; kept within the ends
  // it may reach), squared there for the wall to run straight up into
  readonly property var pillStretch: {
    const own = root.place.stretch;
    const pill = root.anchorPill;
    const reach = root._sideStretch?.joinReach ?? null;
    if (pill === null || root.mergeWithPill || reach === null)
      return own;
    const at = Math.max(mainPopup.strokeStart, Math.min(reach + mainPopup.windowFrom, mainPopup.strokeEnd));
    const start = own ? own.start : pill.start;
    const end = own ? own.end : pill.start + pill.length;
    return {
      "index": pill.index,
      "start": Math.min(start, at),
      "end": Math.max(end, at),
      "squareStart": at < start || ((own?.squareStart ?? false) && at === start),
      "squareEnd": at > end || ((own?.squareEnd ?? false) && at === end)
    };
  }
  PillStretch {
    container: root.layoutSource
    owner: "barPopout"
    stretch: root.occupied ? root.pillStretch : null
    opening: root._opening
  }
  // Over a pill's or island's far stroke, the stroke is left open under
  // a translucent box (BarContainer.openings): the box's surface along the
  // bar, fillets included
  readonly property var _opening: root.occupied && root.popupWindow.visible && Appearance.translucent && root.anchorPill !== null && !root.mergeWithPill ? {
    "start": mainPopup.shownAlongPos,
    "end": mainPopup.shownAlongPos + surface.alongLength
  } : null

  // How far past the bar's outer edge a merged popout's content starts:
  // where a pill's far stroke would be, with the border on or off
  readonly property real pillClearance: mergeWithPill ? root.pillFoot : 0
  // Where the popout attaches, measured from the bar's outer edge: the
  // outer edge itself when merged, a pill's far stroke, the bar's own
  // inner stroke (solid, border off), or the bar's inner edge (where the
  // border strip's stroke starts; a transparent bar's detached box no
  // nearer than the windows, see Bar.detachedPush)
  readonly property real attachAt: mergeWithPill ? 0 : anchorPill !== null || root.island ? pillFoot : root.barConfig.extent - (root.barConfig.innerStroke ? Appearance.borderWidth : 0) + Bar.detachedPush(root.barConfig, HyprlandManager.gapsOut[Bar.edgeName(root.barConfig.location)] ?? 0, root.connectorGap)
  // Read through a var: screenOrigin is BarPanel's, not QtObject's
  readonly property var _panel: root.panel
  // The bar window's thickness (more than the bar's extent with pills)
  readonly property real panelThickness: root.panel?.thickness ?? root.barConfig.extent
  // Where the under-bar window starts, from the bar's outer edge: past the
  // border stroke the outer edge of a bar inside the border lies on
  readonly property real underStart: root.barConfig.insideBorder ? Appearance.borderWidth : 0
  // Where the windows start, from the bar's outer edge: past its reserved
  // space, or, reserving none, past the border (see FloatingEdgeMenu)
  readonly property real barReach: {
    const zone = root.panel?.reservedZone ?? 0;
    return zone > 0 || !root.barConfig.insideBorder ? zone : Appearance.borderWidth;
  }
  // Where the surface starts, from the bar's outer edge: a detached box's
  // reaches back to the under-bar window's edge, to slide in from there
  readonly property real surfaceFrom: surface.detached && root.underBar ? root.underStart : root.attachAt

  // Resizing a window while it shows is a round trip to the compositor
  // (a popup's reposition, a layer surface's configure), so the outline
  // lagged content that changes size (the calendar's editor). So the
  // windows never follow the content: along the bar the popup spans the
  // whole bar, and across it both keep the most room the box has needed
  // since the popout opened, or that its content declares it can take
  // (Panel.maxImplicitHeight/Width), with the surface on the bar side of
  // that room. Content resizing changes only the scene, and the box
  // animates to its new size (and place along the bar) in it.
  readonly property real targetBoxWidth: mainPopup.contentWidth + surface.contentInset * 2 + (root.barConfig.vertical ? root.pillClearance : mainPopup.boxGrow)
  readonly property real targetBoxHeight: mainPopup.contentHeight + surface.contentInset * 2 + (root.barConfig.vertical ? mainPopup.boxGrow : root.pillClearance)
  // What's drawn: the targets, animated once the popout shows
  property real shownBoxWidth: still.holding ? still.held.width : root.targetBoxWidth
  property real shownBoxHeight: still.holding ? still.held.height : root.targetBoxHeight
  property real shownBoxStart: still.holding ? still.held.start : mainPopup.boxStart
  // Where the box is drawn along the bar: on a vertical bar, reaching up
  // past its start for a submenu (shownStretchTop)
  readonly property real drawnBoxStart: root.shownBoxStart - (root.barConfig.vertical ? root.shownStretchTop : 0)
  Glide on shownBoxWidth {
    enabled: still.settled
  }
  Glide on shownBoxHeight {
    enabled: still.settled
  }
  Glide on shownBoxStart {
    enabled: still.settled
  }

  // (a submenu's stretch included, so the window keeps room for it too)
  readonly property real _boxAcross: root.barConfig.vertical ? root.targetBoxWidth : root.targetBoxHeight + root._stretchAcross
  readonly property real _shownBoxAcross: root.barConfig.vertical ? root.shownBoxWidth : root.shownBoxHeight + root._shownStretchAcross
  // Read through a var: content declares it on Panel, not Item
  readonly property var _content: root.currentItem
  readonly property real _declaredAcross: {
    const item = root._content;
    const declared = root.barConfig.vertical ? item?.maxImplicitWidth ?? 0 : item?.maxImplicitHeight ?? 0;
    const content = root.barConfig.vertical ? mainPopup.contentWidth : mainPopup.contentHeight;
    return root._boxAcross + Math.max(0, declared - content);
  }
  property real _peakAcross: 0
  function _notePeak() {
    if (root.occupied && root.contentReady)
      root._peakAcross = Math.max(root._peakAcross, root._boxAcross);
  }
  on_BoxAcrossChanged: _notePeak()
  onContentReadyChanged: _notePeak()
  onOccupiedChanged: {
    if (!root.occupied)
      root._peakAcross = 0;
  }
  // The room past the drawn box, on the side away from the bar: the
  // window's depth stays put while the box animates within it
  // (and room for the shadow or glow the surface casts, see SurfaceShadow)
  readonly property real spareAcross: Math.max(0, Math.max(root._peakAcross, root._declaredAcross, root._boxAcross) - root._shownBoxAcross) + BarStyle.shadowReach
  // On a bottom or right bar the room lies before the surface
  readonly property bool spareBefore: root.barConfig.vertical ? root.barConfig.right : root.barConfig.bottom

  Connections {
    target: root.layoutSource
    // Positions settle through bindings after the signal, so read them once
    // they have. A pinned popout stays where it opened.
    function onLayoutUpdated() {
      if (root.occupied && !root.currentData?.pinned)
        Qt.callLater(root.updateAnchorRect);
    }
  }

  Component.onDestruction: {
    ShellManager.unregisterGrabPartner(mainPopup);
    ShellManager.unregisterGrabPartner(underWindow);
  }

  // The overlay's focus grab lets input through to the popout (see
  // ShellManager.grabPartners)
  function _registerGrabPartners() {
    ShellManager.registerGrabPartner(mainPopup, root.screen?.name);
    ShellManager.registerGrabPartner(underWindow, root.screen?.name);
  }
  Component.onCompleted: _registerGrabPartners()
  onScreenChanged: _registerGrabPartners()

  PopupWindow {
    id: mainPopup
    visible: !root.underBar && still.showing && !ShellManager.captureFrozen
    color: "transparent"

    // Content dimensions
    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100
    readonly property bool isOnRightHalfOfScreen: root.anchorRect.x > (root.screen.width / 2)

    // Along-bar clamp range, in bar-window coordinates. The perpendicular
    // screen borders may sit inside the bar window (bar mapped first) or
    // outside it, so derive where their inner edge falls from how much of
    // the screen the window spans. The surface (fillets included) keeps a
    // screen margin clear of that edge, so the fillets never run into the
    // border's inner corner — the same gap EdgePopout leaves.
    readonly property real panelLength: {
      const mapped = root.barConfig.vertical ? root.panel.height : root.panel.width;
      return mapped > 0 ? mapped : (root.barConfig.vertical ? root.screen.height : root.screen.width);
    }
    readonly property real frameWidth: Appearance.screenBorder ? Appearance.screenMargin : 0
    // Integrated edge menus on the perpendicular edges sit outside
    // everything else, taking their space off one end only
    readonly property real menuZones: root.barConfig.vertical ? EdgeMenuManager.zoneOn(root.screen?.name, "top") + EdgeMenuManager.zoneOn(root.screen?.name, "bottom") : EdgeMenuManager.zoneOn(root.screen?.name, "left") + EdgeMenuManager.zoneOn(root.screen?.name, "right")
    readonly property real borderInset: frameWidth - ((root.barConfig.vertical ? root.screen.height : root.screen.width) - panelLength - menuZones) / 2
    // On a floating bar, where its islands may reach instead: a popout
    // pushed to one runs flush into the island's end there
    readonly property real islandStart: root.barConfig.islandStart
    readonly property real islandEnd: root.layoutSource?.islandEnd ?? panelLength - islandStart
    readonly property real minAlong: root.island ? islandStart : borderInset + Appearance.screenMargin
    readonly property real maxAlong: root.island ? islandEnd : panelLength - borderInset - Appearance.screenMargin
    // Outer edges of the perpendicular border strokes (the screen edges
    // with the border off), where a popout pushed to an end joins
    readonly property real strokeStart: root.island ? islandStart : borderInset - (Appearance.screenBorder ? Appearance.borderWidth : 0)
    readonly property real strokeEnd: root.island ? islandEnd : panelLength - strokeStart

    // Along the bar, in bar-window coordinates: the box centred on the
    // anchor, and the surface around it with a fillet margin each side,
    // placed by EdgeAttach (root.place). One that would be pushed back from
    // an end, or come within a connector gap of it, joins it instead: flush
    // on the perpendicular stroke, merging into that edge.
    readonly property real boxLength: (root.barConfig.vertical ? mainPopup.contentHeight : mainPopup.contentWidth) + surface.contentInset * 2
    readonly property real filletMargin: EdgeAttach.filletMargin(root.connectorGap, Appearance.borderWidth, Appearance.borderRadius)
    readonly property real alignedBoxStart: {
      if (!root.currentData)
        return 0;
      const start = root.barConfig.vertical ? root.anchorRect.y : root.anchorRect.x;
      const length = root.barConfig.vertical ? root.anchorRect.height : root.anchorRect.width;
      return start + (length - mainPopup.boxLength) / 2;
    }
    // An island's ends never join (a side runs flush into the island
    // instead), nor a detached box's (it's clamped clear of them)
    readonly property bool canJoin: !root.island && !detached
    readonly property var joins: EdgeAttach.joins(alignedBoxStart, boxLength, minAlong + filletMargin, maxAlong - filletMargin, root.connectorGap, canJoin, canJoin)
    readonly property bool joinStart: root.place.joinStart
    readonly property bool joinEnd: root.place.joinEnd
    readonly property real boxStart: root.place.start
    // Room the box takes past its content: to an island's ends, or from
    // stroke to stroke when it joins both
    readonly property real boxGrow: root.place.grow
    readonly property real boxEnd: root.place.end
    // Where the popup (the surface) starts along the bar
    // (the surface's own margin: none on a joined, flush or straight side)
    readonly property real alongPos: root.place.surfaceStart
    // Its length along the bar, at the target size
    readonly property real surfaceLength: root.place.surfaceLength
    // Where it's drawn, animating to alongPos (see shownBoxStart)
    readonly property real shownAlongPos: root.drawnBoxStart - surface.startMargin
    // The window along the bar: the whole bar, and wherever a box pushed
    // to an end can reach past it, so it never moves along the bar
    readonly property real windowFrom: Math.min(0, strokeStart, minAlong)
    readonly property real windowTo: Math.max(panelLength, strokeEnd, maxAlong)

    // On a transparent bar a popout is a detached box
    readonly property bool detached: root.barConfig.background === "transparent"

    // Where the surface sits, in bar-window coordinates
    readonly property real barX: {
      if (!root.currentData)
        return 0;
      if (root.barConfig.left) {
        return root.surfaceFrom - surface.backfill;
      } else if (root.barConfig.right) {
        // Mirror of the left case: measured from the bar's outer edge,
        // not relative to the anchor (tray icons are narrower than modules)
        return root.panelThickness - root.surfaceFrom + surface.backfill - surface.implicitWidth;
      } else {
        return mainPopup.shownAlongPos;
      }
    }

    readonly property real barY: {
      if (!root.currentData)
        return 0;
      if (root.barConfig.top) {
        return root.surfaceFrom - surface.backfill;
      } else if (root.barConfig.bottom) {
        return root.panelThickness - root.surfaceFrom + surface.backfill - surface.implicitHeight;
      } else {
        return mainPopup.shownAlongPos;
      }
    }

    mask: Region {
      item: surface
    }

    // Size comes from the shared attached shape: the content box wraps
    // the content plus the surface's inset on every side. Across the bar,
    // the room it may grow into stays too (see spareAcross). On a bottom
    // or right bar the window instead takes the screen's whole depth: one
    // growing there must also move, and the compositor shows the resize a
    // frame or more before the move, flashing the new size in the old place
    // (switching in place to taller content). At a fixed size it never does.
    readonly property real depth: root.spareBefore ? (root.barConfig.vertical ? root.screen.width : root.screen.height) : (root.barConfig.vertical ? surface.implicitWidth : surface.implicitHeight) + root.spareAcross
    implicitWidth: root.barConfig.vertical ? depth : windowTo - windowFrom
    implicitHeight: root.barConfig.vertical ? windowTo - windowFrom : depth
    // The surface in this window: at the bar side of its depth
    readonly property real surfaceX: root.barConfig.vertical ? (root.spareBefore ? depth - surface.implicitWidth : 0) : barX - windowFrom
    readonly property real surfaceY: root.barConfig.vertical ? barY - windowFrom : (root.spareBefore ? depth - surface.implicitHeight : 0)

    // The window's bar-side edge across the bar, in bar-window coordinates:
    // where the surface's attach edge is, whatever its size
    readonly property real nearEdge: root.spareBefore ? root.panelThickness - root.surfaceFrom + surface.backfill : root.surfaceFrom - surface.backfill

    anchor {
      window: root.currentAnchor
      // Placement is worked out here (clamped along the bar, flush on its
      // edge), so the compositor mustn't slide it: flush against the screen
      // edge it would nudge the popup inwards
      adjustment: PopupAdjustment.None

      // Hung from its bar-side edge, growing away from the bar, so a resize
      // keeps that edge without a move (see depth)
      gravity: root.barConfig.vertical ? (root.barConfig.right ? Edges.Bottom | Edges.Left : Edges.Bottom | Edges.Right) : (root.barConfig.bottom ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Right)

      rect {
        x: root.barConfig.vertical ? mainPopup.nearEdge : mainPopup.windowFrom
        y: root.barConfig.vertical ? mainPopup.windowFrom : mainPopup.nearEdge
        width: 1
        height: 1
      }
    }
    // Quickshell repositions a mapped popup when its anchor changes, not
    // when it resizes, which left a resized one off its edge
    function _reanchor() {
      if (mainPopup.visible)
        Qt.callLater(mainPopup.anchor.updateAnchor);
    }
    onWidthChanged: _reanchor()
    onHeightChanged: _reanchor()
  }

  PanelWindow {
    id: underWindow
    screen: root.screen
    visible: root.underBar && still.showing
    color: "transparent"

    // On the bar's layer, ordered under it (HyprlandManager's layer rules).
    // Normal exclusion with no zone of its own places it where the windows
    // start; the margin takes it back to the bar's outer edge, past the
    // border stroke, and along the bar it spans what the bar does.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "axiom-popout-under"
    WlrLayershell.keyboardFocus: root.wantsKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors {
      top: root.barConfig.top || root.barConfig.vertical
      bottom: root.barConfig.bottom || root.barConfig.vertical
      left: root.barConfig.left || !root.barConfig.vertical
      right: root.barConfig.right || !root.barConfig.vertical
    }

    readonly property real attachMargin: root.underStart - root.barReach
    readonly property real endMargin: root.barConfig.insideBorder ? -Appearance.borderWidth : 0
    margins {
      top: root.barConfig.top ? underWindow.attachMargin : underWindow.endMargin
      bottom: root.barConfig.bottom ? underWindow.attachMargin : underWindow.endMargin
      left: root.barConfig.left ? underWindow.attachMargin : underWindow.endMargin
      right: root.barConfig.right ? underWindow.attachMargin : underWindow.endMargin
    }

    // Deep enough for the box and its connector gaps either side, whether
    // it's detached
    readonly property real depth: root.attachAt - root.underStart + root.connectorGap * 2 + (root.barConfig.vertical ? surface.boxWidth : surface.boxHeight) + root.spareAcross
    implicitWidth: root.barConfig.vertical ? depth : 0
    implicitHeight: root.barConfig.vertical ? 0 : depth

    // Bar-window coordinates to this window's: along the bar, the bar is
    // taken as centred on the screen (as BarPopouts.borderInset does), and
    // this window as centred between what's reserved on the perpendicular
    // edges, which differ with a bar or dock on only one of them; across
    // it, measured from the bar's outer edge
    readonly property real shift: {
      const length = root.barConfig.vertical ? height : width;
      if (length <= 0)
        return 0;
      const name = root.screen?.name ?? "";
      const startLoc = root.barConfig.vertical ? Bar.Top : Bar.Left;
      const endLoc = root.barConfig.vertical ? Bar.Bottom : Bar.Right;
      const reservedAt = loc => EdgeMenuManager.reservedOn(root.screen, loc) + DockManager.zoneOn(name, Bar.edgeName(loc));
      return (mainPopup.panelLength - length + reservedAt(startLoc) - reservedAt(endLoc)) / 2;
    }
    readonly property real acrossShift: root.barConfig.left || root.barConfig.top ? -root.underStart : depth - root.panelThickness + root.underStart
    readonly property real surfaceX: mainPopup.barX - (root.barConfig.vertical ? -acrossShift : shift)
    readonly property real surfaceY: mainPopup.barY - (root.barConfig.vertical ? shift : -acrossShift)

    // Only the box takes input: the bar above it keeps its own
    mask: Region {
      x: root.boxRect.x
      y: root.boxRect.y
      width: root.boxRect.width
      height: root.boxRect.height
    }
  }

  AttachedSurface {
    id: surface
    // In whichever window shows the popout
    parent: root.underBar ? underWindow.contentItem : mainPopup.contentItem
    x: root.underBar ? underWindow.surfaceX : mainPopup.surfaceX
    y: root.underBar ? underWindow.surfaceY : mainPopup.surfaceY
    width: implicitWidth
    height: implicitHeight

    edge: root.barConfig.location
    castShadow: true
    active: still.showing && !root.isClosing
    // The blur window draws its fill and shadow (BlurManager), from where
    // the bar window is on screen: the surface is at (barX, barY) in bar
    // window coordinates in either window
    readonly property var barOrigin: root._panel?.screenOrigin ?? null
    backed: BlurManager.backing && surface.barOrigin !== null
    // A tray submenu's opening in the box's side stroke (TraySubmenuWrapper)
    strokeHoles: root.submenuHole ? [Qt.rect(root.submenuHole.x - surface.x, root.submenuHole.y - surface.y, root.submenuHole.width, root.submenuHole.height)] : []

    BlurShape {
      source: surface
      screen: root.screen?.name ?? ""
      x: (surface.barOrigin?.x ?? 0) + mainPopup.barX
      y: (surface.barOrigin?.y ?? 0) + mainPopup.barY
      shown: surface.backed && root.popupWindow.visible
    }
    connectorGap: root.connectorGap
    boxWidth: root.shownBoxWidth
    // A submenu's stretch: along the bar on a vertical one, away from it
    // on a horizontal one
    boxHeight: root.shownBoxHeight + root.shownStretchTop + root.shownStretchBottom
    // Square where a submenu runs flush to the box's end
    startCornerRadius: root.squareStartCorner ? 0 : surface.cornerRadius
    endCornerRadius: root.squareEndCorner ? 0 : surface.cornerRadius
    Glide on startCornerRadius {
      enabled: still.settled
    }
    // A detached box's near corner too, where one runs flush to its bar side
    startNearRadius: root.squareStartNear ? 0 : Appearance.borderRadius
    endNearRadius: root.squareEndNear ? 0 : Appearance.borderRadius
    Glide on startNearRadius {
      enabled: still.settled
    }
    Glide on endNearRadius {
      enabled: still.settled
    }
    Glide on endCornerRadius {
      enabled: still.settled
    }

    // A transparent bar has nothing to join onto
    detached: mainPopup.detached
    detachedOffset: root.underBar ? root.attachAt - root.underStart : 0
    // On an island an end runs flush into the island's instead
    joinStart: mainPopup.joinStart
    joinEnd: mainPopup.joinEnd
    flushStart: root.place.flushStart
    flushEnd: root.place.flushEnd
    flushStartThrough: !(root._sideJoined && root.openToLeft)
    flushEndThrough: !(root._sideJoined && !root.openToLeft)
    // Without the border, a merged popout runs straight off the screen edge
    straight: root.mergeWithPill && !Appearance.screenBorder
    straightJoins: !Appearance.screenBorder
    // On a pill's far stroke, cover that stroke's inner fringe too
    backfill: root.anchorPill !== null && !root.mergeWithPill ? 1 : 0

    // The content keeps its target size while the box animates to it,
    // hung from the box's start along the bar and from its bar side
    // across it, and cut to the box (as FloatingPopout does)
    Item {
      id: clipBox
      anchors.fill: parent
      clip: true

      Loader {
        id: loader
        // Merged (a pill bar showing no pills), the content starts past
        // where the pills would be
        readonly property real barSide: surface.contentInset + root.pillClearance
        // Along the bar, where it wants to be (EdgeAttach.place's
        // contentStart), however far the box grows past it either side
        readonly property real along: surface.contentInset + root.place.contentStart - root.drawnBoxStart
        width: mainPopup.contentWidth
        height: mainPopup.contentHeight
        x: root.barConfig.left ? barSide : root.barConfig.right ? clipBox.width - barSide - width : along
        y: root.barConfig.top ? barSide : root.barConfig.bottom ? clipBox.height - barSide - height : along
        opacity: still.contentOpacity

        active: root.occupied
        asynchronous: false

        onActiveChanged: root._loadContent()

        onLoaded: {
          if (item) {
            if (root.currentData) {
              for (let key in root.currentData) {
                if (item.hasOwnProperty(key)) {
                  // Content may derive one itself (a readonly property):
                  // skip it rather than abort
                  try {
                    item[key] = root.currentData[key];
                  } catch (e) {}
                }
              }
            }
            root._layOut(item);
          }
          root._payloadApplied = true;
          root.updateDismissTimer();
        }
      }

      // The content switched away from, held where it was along the bar
      // while the box glides on
      SwitchStill {
        id: still
        contentReady: root.contentReady
        occupied: root.occupied
        snapshot: () => ({
              "start": root.shownBoxStart,
              "width": root.shownBoxWidth,
              "height": root.shownBoxHeight,
              "along": surface.contentInset + root.place.contentStart
            })
        readonly property real along: (held?.along ?? 0) - root.drawnBoxStart
        x: root.barConfig.left ? loader.barSide : root.barConfig.right ? clipBox.width - loader.barSide - width : along
        y: root.barConfig.top ? loader.barSide : root.barConfig.bottom ? clipBox.height - loader.barSide - height : along
      }
    }
  }
}
