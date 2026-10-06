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

/**
 * Popout wrapper for bar widgets
 * Handles positioning, animation, and content loading for popouts that emerge from the bar.
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

  // The content-type name travels inside currentData.name (see
  // PopoutAnchor.qml) rather than as a separate argument, so this file
  // never needs to override openPopout/safeOpenPopout from the base.
  readonly property string currentName: currentData?.name ?? ""
  // Which side the tray's submenus open to
  readonly property bool openToLeft: root.barConfig.right || mainPopup.isOnRightHalfOfScreen

  // content/<name>.qml, loaded by URL like bar widgets and overlay modules:
  // a new popout is just a file there plus a PopoutAnchor naming it
  function _loadContent() {
    root._payloadApplied = false;
    if (loader.active && root.currentName !== "")
      loader.setSource(Qt.resolvedUrl("../../content/" + root.currentName + ".qml"), {
        "wrapper": root
      });
    else if (!loader.active)
      // Cleared, so reactivating doesn't first rebuild the previous popout
      loader.source = "";
  }
  onCurrentNameChanged: _loadContent()

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

  onCurrentDataChanged: updateAnchorRect()

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
  PillStretch {
    container: root.layoutSource
    owner: "barPopout"
    stretch: root.occupied ? root.place.stretch : null
  }
  // How far past the bar's outer edge a merged popout's content starts:
  // where a pill's far stroke would be, with the border on or off
  readonly property real pillClearance: mergeWithPill ? root.pillFoot : 0
  // Where the popout attaches, measured from the bar's outer edge: the
  // outer edge itself when merged, a pill's far stroke, the bar's own
  // inner stroke (solid, border off), or the bar's inner edge (where the
  // border strip's stroke starts; a transparent bar's detached box no
  // nearer than the windows, see Bar.detachedPush)
  readonly property real attachAt: mergeWithPill ? 0 : anchorPill !== null || root.island ? pillFoot : root.barConfig.extent - (root.barConfig.innerStroke ? Appearance.borderWidth : 0) + Bar.detachedPush(root.barConfig, HyprlandManager.gapsOut[Bar.edgeName(root.barConfig.location)] ?? 0, root.connectorGap)
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
  property real shownBoxWidth: root.targetBoxWidth
  property real shownBoxHeight: root.targetBoxHeight
  property real shownBoxStart: mainPopup.boxStart
  // Set once the popout has shown at its first size, so opening jumps
  // straight there rather than animating from wherever it last was
  property bool _settled: false
  function _updateSettled() {
    if (!root.occupied || !root.contentReady)
      root._settled = false;
    else
      Qt.callLater(() => root._settled = root.occupied && root.contentReady);
  }
  Behavior on shownBoxWidth {
    enabled: root._settled
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Appearance.easing
    }
  }
  Behavior on shownBoxHeight {
    enabled: root._settled
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Appearance.easing
    }
  }
  Behavior on shownBoxStart {
    enabled: root._settled
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Appearance.easing
    }
  }

  readonly property real _boxAcross: root.barConfig.vertical ? root.targetBoxWidth : root.targetBoxHeight
  readonly property real _shownBoxAcross: root.barConfig.vertical ? root.shownBoxWidth : root.shownBoxHeight
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
  onContentReadyChanged: {
    _notePeak();
    _updateSettled();
  }
  onOccupiedChanged: {
    if (!root.occupied)
      root._peakAcross = 0;
    _updateSettled();
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
    visible: !root.underBar && root.occupied && root.contentReady && !ShellManager.captureFrozen
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
    readonly property real shownAlongPos: root.shownBoxStart - surface.startMargin
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
    // the room it may grow into stays too (see spareAcross).
    implicitWidth: root.barConfig.vertical ? surface.implicitWidth + root.spareAcross : windowTo - windowFrom
    implicitHeight: root.barConfig.vertical ? windowTo - windowFrom : surface.implicitHeight + root.spareAcross
    // The surface in this window
    readonly property real surfaceX: root.barConfig.vertical ? (root.spareBefore ? root.spareAcross : 0) : barX - windowFrom
    readonly property real surfaceY: root.barConfig.vertical ? barY - windowFrom : (root.spareBefore ? root.spareAcross : 0)

    anchor {
      window: root.currentAnchor
      // Placement is worked out here (clamped along the bar, flush on its
      // edge), so the compositor mustn't slide it: flush against the screen
      // edge it would nudge the popup inwards
      adjustment: PopupAdjustment.None

      rect {
        x: root.barConfig.vertical ? mainPopup.barX - mainPopup.surfaceX : mainPopup.windowFrom
        y: root.barConfig.vertical ? mainPopup.windowFrom : mainPopup.barY - mainPopup.surfaceY
        width: 1
        height: 1
      }
    }
  }

  PanelWindow {
    id: underWindow
    screen: root.screen
    visible: root.underBar && root.occupied && root.contentReady
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

    // Bar-window coordinates to this window's: along the bar, the two are
    // taken as centred on each other (as BarPopouts.borderInset does);
    // across it, measured from the bar's outer edge
    readonly property real shift: {
      const length = root.barConfig.vertical ? height : width;
      return length > 0 ? (mainPopup.panelLength - length) / 2 : 0;
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
    active: root.occupied && !root.isClosing && root.contentReady
    connectorGap: root.connectorGap
    boxWidth: root.shownBoxWidth
    boxHeight: root.shownBoxHeight

    // A transparent bar has nothing to join onto
    detached: mainPopup.detached
    detachedOffset: root.underBar ? root.attachAt - root.underStart : 0
    // On an island an end runs flush into the island's instead
    joinStart: mainPopup.joinStart
    joinEnd: mainPopup.joinEnd
    flushStart: root.place.flushStart
    flushEnd: root.place.flushEnd
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
        readonly property real along: surface.contentInset + root.place.contentStart - root.shownBoxStart
        width: mainPopup.contentWidth
        height: mainPopup.contentHeight
        x: root.barConfig.left ? barSide : root.barConfig.right ? clipBox.width - barSide - width : along
        y: root.barConfig.top ? barSide : root.barConfig.bottom ? clipBox.height - barSide - height : along

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
    }
  }
}
