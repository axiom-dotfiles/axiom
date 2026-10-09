pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services

// Where a layer-shell `window` is on its screen (BlurManager.layerOrigin),
// for surfaces whose fill the blur window draws and for popouts' footprints
// (PopoutClaim): null until Hyprland has reported it. Asks again whenever
// the window or what's reserved around it changes, and a few more times
// while it's mapped and still unknown (BlurManager.awaitOrigin).
QtObject {
  id: root

  required property var window
  required property string namespace
  // The window's edge, telling apart same-sized windows on one screen
  property int edge: Bar.Top

  readonly property var origin: BlurManager.layerOrigin(root.namespace, root.window?.screen?.name ?? "", root.window?.width ?? 0, root.window?.height ?? 0, root.edge)
  // Where it is, else where it most likely is until Hyprland says: on its
  // edge, centred along it (what's reserved at either end roughly
  // balancing). Close enough for which popouts overlap
  // (PopoutManager), never for drawing.
  readonly property point placed: root.origin ?? root._estimate
  readonly property point _estimate: {
    const sw = root.window?.screen?.width ?? 0, sh = root.window?.screen?.height ?? 0;
    const w = root.window?.width ?? 0, h = root.window?.height ?? 0;
    const vertical = root.edge === Bar.Left || root.edge === Bar.Right;
    return Qt.point(vertical ? (root.edge === Bar.Right ? sw - w : 0) : (sw - w) / 2, vertical ? (sh - h) / 2 : (root.edge === Bar.Bottom ? sh - h : 0));
  }

  readonly property var _inputs: [root.window?.width, root.window?.height, root.window?.visible, root.window?.screen, root.namespace, EdgeMenuManager.zones, DockManager.zones, BarManager.bars, Appearance.screenMargin, Appearance.screenBorder]
  on_InputsChanged: BlurManager.refreshLayers()

  // Mapped and still unknown: BlurManager asks again a few times
  readonly property bool _waiting: root.origin === null && (root.window?.visible ?? false) && (root.window?.width ?? 0) > 0
  on_WaitingChanged: {
    BlurManager.awaitOrigin(root, root._waiting);
    if (root._waiting) {
      root._timedOut = false;
      root._timeout.restart();
    }
  }
  // Known, or given up on: a surface the blur window backs waits for this
  // before it shows (else its first frames fill and shadow themselves
  // beside backed ones), but never longer than a moment
  readonly property bool settled: root.origin !== null || root._timedOut
  property bool _timedOut: false
  property Timer _timeout: Timer {
    interval: 400
    onTriggered: root._timedOut = true
  }
  Component.onDestruction: BlurManager.awaitOrigin(root, false)
}
