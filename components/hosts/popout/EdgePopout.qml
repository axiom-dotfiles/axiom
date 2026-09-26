pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.components.reusable

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
  readonly property Item contentItem: loader.item
  // Keep content alive while closed (e.g. content that itself decides
  // when the popout should open)
  property bool keepLoaded: false

  // When false the popout can't open at all (and closes if open), and its
  // trigger strip is removed
  property bool available: true
  onAvailableChanged: {
    if (!available)
      hide();
  }

  // Hover strip at the very edge of the screen that opens the popout
  property bool triggerEnabled: true
  property int triggerWidth: PopoutConfig.edgeTriggerSize
  property int triggerLength: 200
  property int hoverDelay: PopoutConfig.openDelay

  property bool wantsKeyboardFocus: false
  // Take the keyboard when clicked, without a focus grab (content that may
  // hold a text field, e.g. an edge menu's modules)
  property bool keyboardOnDemand: false
  // A plain rounded box a connector gap in from the edge, not joined to it
  // (an edge whose bar has no strip to grow out of: pills, transparent)
  property bool detached: false
  property bool closeOnClickOutside: false
  // Space between the box and its content
  property real contentPadding: Widget.spacing
  // Extra distance in from the attach edge (for a detached box)
  property real edgeOffset: 0
  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground
  // Off leaves the focus grab to another window (see SurfaceGroup)
  property bool grabEnabled: true
  // Other windows the grab lets input through to
  property var grabWindows: []
  // The surface's window
  readonly property var window: surfaceWindow

  property int connectorGap: Appearance.borderRadius * 2

  readonly property bool vertical: edge === Bar.Left || edge === Bar.Right
  readonly property bool straight: Bar.screenEdgeOpen(root.screen, root.edge)
  readonly property bool isOpen: occupied && !isClosing
  // For opens driven by global events (volume changes, IPC) rather than
  // hovering this screen's edge.
  readonly property bool isFocusedScreen: Hyprland.focusedMonitor?.name === screen?.name

  // Length of the edge between the perpendicular borders/bars. The window
  // has no size until it's first mapped, so fall back to an estimate.
  readonly property real edgeLength: {
    const mapped = vertical ? surfaceWindow.height : surfaceWindow.width;
    if (mapped > 0)
      return mapped;
    return (vertical ? screen.height : screen.width) - Appearance.screenMargin * 2;
  }
  // Largest content box that fits along the edge, leaving a screen margin
  // between the fillets and the perpendicular borders
  readonly property real maxBoxLength: edgeLength - connectorGap * 2 + Appearance.borderWidth * 2 - Appearance.screenMargin * 2

  currentItem: loader.item ?? null
  keepAlive: surfaceHover.hovered || trigger.containsMouse || (focusGrab.active && wantsKeyboardFocus)

  // `data` is the open payload: { anchorItem } keeps it open while that
  // item is hovered, as for bar popouts
  function show(data) {
    if (!available)
      return;
    if (isOpen) {
      // Already open: just restart the countdown
      updateDismissTimer();
      return;
    }
    safeOpenPopout(null, data ?? ({}));
  }

  function hide() {
    if (isOpen)
      requestDismiss();
  }

  function toggle() {
    if (isOpen)
      hide();
    else
      show();
  }

  EdgeTrigger {
    id: trigger
    screen: root.screen
    visible: root.available && root.triggerEnabled
    edge: root.edge
    position: root.position
    positionOffset: root.positionOffset
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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "axiom-edge-popout"
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
    readonly property real attachMargin: (root.straight ? 0 : -Appearance.borderWidth) + root.edgeOffset
    margins {
      top: root.edge === Bar.Top ? surfaceWindow.attachMargin : 0
      bottom: root.edge === Bar.Bottom ? surfaceWindow.attachMargin : 0
      left: root.edge === Bar.Left ? surfaceWindow.attachMargin : 0
      right: root.edge === Bar.Right ? surfaceWindow.attachMargin : 0
    }

    implicitWidth: root.vertical ? surface.implicitWidth : 0
    implicitHeight: root.vertical ? 0 : surface.implicitHeight

    mask: Region {
      item: surface
    }

    HyprlandFocusGrab {
      id: focusGrab
      windows: [surfaceWindow].concat(root.grabWindows)
      active: surfaceWindow.visible && root.grabEnabled && (root.wantsKeyboardFocus || root.closeOnClickOutside)

      onActiveChanged: {
        if (active)
          loader.item?.forceActiveFocus();
      }

      onCleared: {
        if (!active)
          root.hide();
      }
    }

    AttachedSurface {
      id: surface

      readonly property real alongPosition: {
        const along = root.vertical ? height : width;
        const target = root.edgeLength * root.position + root.positionOffset - along / 2;
        return Math.max(0, Math.min(target, root.edgeLength - along));
      }

      x: root.vertical ? 0 : alongPosition
      y: root.vertical ? alongPosition : 0
      width: implicitWidth
      height: implicitHeight

      edge: root.edge
      straight: root.straight
      detached: root.detached
      active: root.isOpen
      connectorGap: root.connectorGap
      boxWidth: (loader.item?.implicitWidth ?? 100) + root.contentPadding * 2
      boxHeight: (loader.item?.implicitHeight ?? 100) + root.contentPadding * 2
      fillColor: root.fillColor
      strokeColor: root.strokeColor

      HoverHandler {
        id: surfaceHover
      }

      Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: root.contentPadding

        active: root.occupied || root.keepLoaded
        asynchronous: false
        sourceComponent: root.content

        onLoaded: root.updateDismissTimer()
      }
    }
  }
}
