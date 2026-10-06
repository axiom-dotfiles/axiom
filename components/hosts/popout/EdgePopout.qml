pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.services
import qs.components.methods

/**
 * A popout that slides out of a screen edge and joins the screen border
 * (or a bar on that edge) with the same connector + fillets as bar
 * popouts — see AttachedSurface.qml.
 *
 * Open/close/queue state and hover-loss dismissal come from
 * PopoutWrapperBase, the same as bar popouts. Unlike bar popouts, every
 * instance owns its own state, so instantiate one per screen (Variants
 * over Quickshell.screens) and they open independently.
 *
 * Content is a Component, loaded only while open (unless keepLoaded). It
 * can optionally expose `autoDismiss` / `dismissDelay` / `hovered`
 * exactly like bar popout content; hovering the surface or the trigger strip already
 * keeps it open without the content doing anything.
 *
 * Usage:
 *   Variants {
 *     model: Quickshell.screens
 *     delegate: EdgePopout {
 *       required property ShellScreen modelData
 *       screen: modelData
 *       edge: Bar.Right
 *       content: Component { MyPanel {} }
 *     }
 *   }
 */
PopoutWrapperBase {
  id: root

  required property ShellScreen screen

  // Side of the screen to attach to (a Bar.Location value)
  property int edge: Bar.Right
  // Position along the edge: 0-1 of the available length, plus pixels
  property real position: 0.5
  property real positionOffset: 0

  property Component content: null
  readonly property Item contentItem: loader.item as Item
  // The content's largest size across the edge, if it changes size while
  // open: the window keeps room for it, so it isn't resized (and, on the
  // bottom or right edge, moved by the compositor a frame late) each time
  property real maxContentDepth: 0
  // Keep content alive while closed (e.g. content that itself decides
  // when the popout should open)
  property bool keepLoaded: false

  // Hover strip at the very edge of the screen that opens the popout
  property bool triggerEnabled: true
  property int triggerWidth: PopoutConfig.edgeTriggerSize
  property int triggerLength: 200
  property int hoverDelay: PopoutConfig.openDelay
  // The strip's centre along the edge in screen px (NaN: at the box's
  // `position`, EdgeTrigger.centre)
  property real triggerCentre: NaN

  property bool wantsKeyboardFocus: false
  // Take the keyboard when clicked, without a focus grab (content that may
  // hold a text field, e.g. an edge menu's modules)
  property bool keyboardOnDemand: false
  // A plain rounded box a connector gap in from the edge, not joined to it:
  // held off the edge, or on a bar with nothing to grow out of
  // (EdgePlacement.detached)
  readonly property bool detached: placement.detached
  property bool closeOnClickOutside: false
  // Space between the box and its content
  property real contentPadding: Appearance.borderWidth + PopoutConfig.padding
  // Extra distance in from the attach edge (for a detached box)
  property real edgeOffset: root.attachAt - root.attachBase
  // How far back towards the screen edge a detached box slides in from:
  // the window then starts there, drawn under the bar or border it passes
  // (on underLayer, the layer of what it slides under). From what's on its
  // edge: a bar's outer edge (past the border stroke it lies on inside the
  // border), else the border's or a solid bar's stroke, or the bare screen
  // edge. Not while the overlay is open on its screen, see _overOverlay.
  property real slideDistance: root._overOverlay ? 0 : root.attachAt - (root.barConfig ? root.barOuter + (root.barConfig.insideBorder ? Appearance.borderWidth : 0) : root.attachBase)
  property int underLayer: WlrLayer.Top
  readonly property bool slidesUnder: detached && slideDistance > 0
  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground
  // Off leaves the focus grab to another window (see SurfaceGroup)
  property bool grabEnabled: true
  // Other windows the grab lets input through to
  property var grabWindows: []
  // Its layer namespace unless it slides under (layer rules stack by it)
  property string overNamespace: "axiom-edge-popout"
  // The surface's window, its layer namespace, and the box within it
  readonly property var window: surfaceWindow
  // The hover strip's window (a focus grab's partner, see EdgeMenuSync)
  readonly property var triggerWindow: trigger
  readonly property string layerNamespace: root.slidesUnder ? "axiom-popout-under" : root.overNamespace
  readonly property rect boxInWindow: Qt.rect(boxArea.x, boxArea.y, boxArea.width, boxArea.height)

  property int connectorGap: Appearance.borderRadius * 2

  readonly property bool vertical: edge === Bar.Left || edge === Bar.Right
  readonly property bool bareEdge: placement.bareEdge

  // Held off the edge (an edge menu's or OSD's `detached`): a detached box
  // `gap` in from the frame lines on its edge and at its ends
  // (BarManager.detachedGaps), so it lines up with a floating bar's islands, or
  // with the windows. Its gaps are what places it, so a change of `held`
  // never reads them before they follow.
  property bool held: false
  property int gap: -1
  readonly property var gaps: root.held ? BarManager.detachedGaps(root.screen, root.edge, root.gap) : null

  // What's reserved along a screen edge (a Bar.Location), which this
  // window sits inside: the border, a bar, integrated menus. Docks are
  // left out: the window reaches past them.
  function reservedOn(location) {
    return EdgeMenuManager.reservedOn(root.screen, location);
  }
  readonly property int startSide: root.vertical ? Bar.Top : Bar.Left
  readonly property int endSide: root.vertical ? Bar.Bottom : Bar.Right

  // A bar other than a solid one on this edge, while it shows, and its
  // outer edge across it (EdgePlacement)
  readonly property var barPanel: placement.barPanel
  readonly property var barConfig: placement.barConfig
  readonly property real barOuter: placement.barOuter
  // Where the window's attach edge goes by default: on the stroke of what
  // reserves the edge (none on a bare edge)
  readonly property real attachBase: root.reservedOn(root.edge) - (root.bareEdge ? 0 : Appearance.borderWidth)
  // Where it goes held: a connector gap short of where the box goes (a
  // detached box sits that far past its attach edge)
  readonly property real heldAttach: root.gaps ? EdgeMenuManager.frameLineOn(root.screen, root.edge) + root.gaps.across - root.connectorGap / 2 : root.attachBase
  // Where it goes: held, as heldAttach; following a bar, as that meets it
  // (EdgePlacement.barAttach); else on what reserves the edge
  readonly property real attachAt: root.gaps ? root.heldAttach : placement.followsBar ? placement.barAttach : root.attachBase

  // While the overlay is open on its screen a box that would slide under
  // a bar draws over the overlay instead (HyprlandManager.layerRulesLua),
  // since the layer it slides out from under is one the overlay covers
  // (as BarPopouts.underBar). Followed only while closed: the namespace
  // changes with it.
  readonly property bool overlayOpen: ShellManager.surfaceOpenOn("overlay", root.screen)
  property bool _overOverlay: false
  function _followOverlay() {
    if (!root.occupied)
      root._overOverlay = root.overlayOpen;
  }
  onOverlayOpenChanged: root._followOverlay()
  onOccupiedChanged: root._followOverlay()

  // Extra box depth at the attach edge that a merged box's content keeps
  // clear of the pills by
  readonly property real attachClearance: placement.attachClearance

  // Join the perpendicular edges when the box reaches them, as a bar
  // popout pushed to an end does: flush on that edge's stroke, merging
  // into it. Both ends joined stretch the box along the whole edge.
  property bool joinEnds: false
  // The content's length along the edge, ignoring the cap (maxBoxLength),
  // which the joins are decided from: they raise the cap, so deciding from
  // the capped length would feed back into itself. Infinity for content
  // that grows to fill whatever room it's given.
  property real reachLength: root.contentItem ? (root.vertical ? root.contentItem.implicitHeight : root.contentItem.implicitWidth) : 0

  // A joining window reaches onto the perpendicular strokes (as a bar's
  // inside the border does), so a joined end can sit on the stroke's outer edge.
  // Positions along the edge are measured from their inner edge anyway.
  readonly property real strokeInset: joinEnds && Appearance.screenBorder ? Appearance.borderWidth : 0
  // Length of the edge between the perpendicular borders/bars. The window
  // has no size until it's first mapped, so fall back to an estimate.
  readonly property real edgeLength: {
    const mapped = vertical ? surfaceWindow.height : surfaceWindow.width;
    if (mapped > 0)
      return mapped - root.strokeInset * 2;
    return (vertical ? screen.height : screen.width) - Appearance.screenMargin * 2;
  }
  // Room for a side wall's fillet at an end that isn't joined
  readonly property real filletMargin: placement.filletMargin
  // The least room the box keeps from each end that isn't joined, from
  // the perpendicular edge's inner side: its fillet's, or held, its gaps
  // from the frame lines there (in this window's edge coordinates, which
  // start past what's reserved there)
  property real startInset: root.gaps ? Math.max(0, EdgeMenuManager.frameLineOn(root.screen, root.startSide) + root.gaps.start - root.reservedOn(root.startSide)) : root.filletMargin
  property real endInset: root.gaps ? Math.max(0, EdgeMenuManager.frameLineOn(root.screen, root.endSide) + root.gaps.end - root.reservedOn(root.endSide)) : root.filletMargin

  // The natural box centred at `position`: an end joins when the box would
  // be pushed back from that edge, or leave less than a connector gap
  // between its fillet and it (EdgeAttach.joins)
  readonly property real _naturalBox: reachLength + contentPadding * 2
  readonly property real _naturalStart: edgeLength * position + positionOffset - _naturalBox / 2
  readonly property var _joins: EdgeAttach.joins(_naturalStart, _naturalBox, startInset, edgeLength - endInset, connectorGap, joinEnds && placement.joinable(vertical ? "top" : "left"), joinEnds && placement.joinable(vertical ? "bottom" : "right"))
  readonly property bool joinStart: _joins.joinStart
  readonly property bool joinEnd: _joins.joinEnd
  // Without the border, joined ends run straight off the screen edge
  readonly property real _strokeStart: -strokeInset
  readonly property real _strokeEnd: edgeLength + strokeInset

  // Largest content box that fits along the edge: from stroke to stroke
  // when both ends join, else keeping its inset from each end that
  // doesn't, as the clamp in place does
  readonly property real maxBoxLength: {
    const start = root.joinStart ? root._strokeStart : root.startInset;
    const end = root.joinEnd ? root._strokeEnd : root.edgeLength - root.endInset;
    return end - start;
  }

  // The box along the edge, in edge coordinates (0 at the perpendicular
  // edges' inner side): flush on a joined end, else centred at `position`
  // and clamped to its insets (startInset/endInset), so its fillets stay
  // on the edge; on a bar's pills or islands, as a bar popout's
  // (EdgePlacement). Both ends joined, it runs the whole edge, the content
  // centred.
  readonly property real _contentAlong: Math.ceil((vertical ? root.contentItem?.implicitHeight ?? 100 : root.contentItem?.implicitWidth ?? 100) + contentPadding * 2)
  EdgePlacement {
    id: placement
    screen: root.screen
    edge: root.edge
    held: root.held
    connectorGap: root.connectorGap
    length: root.edgeLength
    strokeInset: root.strokeInset
    centre: root.edgeLength * root.position + root.positionOffset
    aligned: placement.centre - root._contentAlong / 2
    contentLength: root._contentAlong
    joinStart: root.joinStart
    joinEnd: root.joinEnd
    lo: root.startInset
    hi: root.edgeLength - root.endInset
    owner: "edgePopout:" + root
    showing: root.occupied && root.contentItem !== null
  }
  readonly property var place: placement.place
  readonly property real boxLength: root.place.end - root.place.start
  // The surface (fillets included) along the edge
  readonly property real surfaceStart: root.place.surfaceStart

  currentItem: root.contentItem
  keepAlive: surfaceHover.hovered || trigger.containsMouse || (focusGrab.active && wantsKeyboardFocus)

  EdgeTrigger {
    id: trigger
    screen: root.screen
    visible: root.triggerEnabled
    edge: root.edge
    position: root.position
    positionOffset: root.positionOffset
    centre: root.triggerCentre
    triggerWidth: root.triggerWidth
    triggerLength: root.triggerLength
    hoverDelay: root.hoverDelay
    onTriggered: root.show()
  }

  PanelWindow {
    id: surfaceWindow
    screen: root.screen
    visible: root.occupied && loader.status === Loader.Ready
    color: "transparent"

    // Overlay so the connector draws over the border/bar stroke it joins.
    // Normal exclusion with no zone of its own places the window inside
    // the border's and bars' reserved area; the -borderWidth margin then
    // lines it up with their inner stroke, whether that's a bar or the
    // plain border.
    // Sliding under something, on its layer, ordered under it (see
    // HyprlandManager's layer rules)
    WlrLayershell.layer: root.slidesUnder ? root.underLayer : WlrLayer.Overlay
    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.keyboardFocus: root.wantsKeyboardFocus || root.keyboardOnDemand ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    // Spans the whole edge; the input mask limits it to the surface.
    anchors {
      top: root.edge === Bar.Top || root.vertical
      bottom: root.edge === Bar.Bottom || root.vertical
      left: root.edge === Bar.Left || !root.vertical
      right: root.edge === Bar.Right || !root.vertical
    }

    // On a bare screen edge (no border, no bar) there's no stroke to land
    // on: the surface sits at the edge and runs straight off it
    // Docks reserving space inside the border don't push it in: it reaches
    // past them, on its own edge and at both ends
    readonly property string screenName: root.screen?.name ?? ""
    readonly property real attachMargin: (root.bareEdge ? 0 : -Appearance.borderWidth) - surface.backfill + root.edgeOffset - (root.slidesUnder ? root.slideDistance : 0) - DockManager.zoneOn(screenName, Bar.edgeName(root.edge))
    margins {
      top: root.edge === Bar.Top ? surfaceWindow.attachMargin : root.vertical ? -root.strokeInset - DockManager.zoneOn(surfaceWindow.screenName, "top") : 0
      bottom: root.edge === Bar.Bottom ? surfaceWindow.attachMargin : root.vertical ? -root.strokeInset - DockManager.zoneOn(surfaceWindow.screenName, "bottom") : 0
      left: root.edge === Bar.Left ? surfaceWindow.attachMargin : root.vertical ? 0 : -root.strokeInset - DockManager.zoneOn(surfaceWindow.screenName, "left")
      right: root.edge === Bar.Right ? surfaceWindow.attachMargin : root.vertical ? 0 : -root.strokeInset - DockManager.zoneOn(surfaceWindow.screenName, "right")
    }

    // The surface, or room for it at the content's largest
    readonly property real depth: {
      const content = root.vertical ? (root.contentItem?.implicitWidth ?? 0) : (root.contentItem?.implicitHeight ?? 0);
      const surfaceDepth = root.vertical ? surface.implicitWidth : surface.implicitHeight;
      // and room for the shadow or glow it casts (SurfaceShadow)
      return surfaceDepth + Math.max(0, root.maxContentDepth - content) + BarStyle.shadowReach;
    }
    implicitWidth: root.vertical ? surfaceWindow.depth : 0
    implicitHeight: root.vertical ? 0 : surfaceWindow.depth

    // One sliding under a bar takes input on its box alone
    mask: Region {
      item: root.slidesUnder ? boxArea : surface
    }

    Item {
      id: boxArea
      x: surface.x + surface.boxRect.x
      y: surface.y + surface.boxRect.y
      width: surface.boxRect.width
      height: surface.boxRect.height
    }

    HyprlandFocusGrab {
      id: focusGrab
      windows: [surfaceWindow].concat(root.grabWindows, ShellManager.modalWindows)
      active: surfaceWindow.visible && root.grabEnabled && (root.wantsKeyboardFocus || root.closeOnClickOutside)

      onActiveChanged: {
        if (active)
          root.contentItem?.forceActiveFocus();
      }

      onCleared: {
        if (!active)
          root.hide();
      }
    }

    AttachedSurface {
      id: surface

      // At the attach edge of a window that may be deeper than it
      x: root.vertical ? (root.edge === Bar.Right ? surfaceWindow.width - width : 0) : root.strokeInset + root.surfaceStart
      y: root.vertical ? root.strokeInset + root.surfaceStart : (root.edge === Bar.Bottom ? surfaceWindow.height - height : 0)
      width: implicitWidth
      height: implicitHeight

      edge: root.edge
      castShadow: true
      straight: placement.straight
      detached: root.detached
      detachedOffset: root.slidesUnder ? root.slideDistance : 0
      active: root.isOpen
      connectorGap: root.connectorGap
      boxWidth: root.vertical ? (root.contentItem?.implicitWidth ?? 100) + root.contentPadding * 2 + root.attachClearance : root.boxLength
      boxHeight: root.vertical ? root.boxLength : (root.contentItem?.implicitHeight ?? 100) + root.contentPadding * 2 + root.attachClearance
      joinStart: root.place.joinStart
      joinEnd: root.place.joinEnd
      flushStart: root.place.flushStart
      flushEnd: root.place.flushEnd
      straightJoins: !Appearance.screenBorder
      fillColor: root.fillColor
      strokeColor: root.strokeColor
      // On a pill's far stroke, cover that stroke's inner fringe too
      backfill: !root.detached && placement.onPill ? 1 : 0

      HoverHandler {
        id: surfaceHover
      }

      Loader {
        id: loader
        // Across the edge it fills the box; along it, it keeps its own
        // length, where it wants to be (EdgeAttach.place's contentOffset:
        // the box can grow past it, to a joined stroke or an island's end).
        // Plain geometry, not anchors switched by `vertical`: those
        // re-evaluate one at a time when the edge changes, and QML drops
        // the anchor that briefly conflicts (top + bottom + verticalCenter)
        // for good.
        readonly property real leftMargin: root.contentPadding + (root.edge === Bar.Left ? root.attachClearance : 0)
        readonly property real rightMargin: root.contentPadding + (root.edge === Bar.Right ? root.attachClearance : 0)
        readonly property real topMargin: root.contentPadding + (root.edge === Bar.Top ? root.attachClearance : 0)
        readonly property real bottomMargin: root.contentPadding + (root.edge === Bar.Bottom ? root.attachClearance : 0)
        x: root.vertical ? leftMargin : root.contentPadding + root.place.contentOffset
        y: root.vertical ? root.contentPadding + root.place.contentOffset : topMargin
        width: root.vertical ? parent.width - leftMargin - rightMargin : (root.contentItem?.implicitWidth ?? 0)
        height: root.vertical ? (root.contentItem?.implicitHeight ?? 0) : parent.height - topMargin - bottomMargin

        active: root.occupied || root.keepLoaded
        asynchronous: false
        sourceComponent: root.content

        onLoaded: root.updateDismissTimer()
      }
    }
  }
}
