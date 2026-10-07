pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services

// Where a layer-shell `window` is on its screen (BlurManager.layerOrigin),
// for surfaces whose fill the blur window draws: null until Hyprland has
// reported it. Asks again whenever the window or what's reserved around it
// changes.
QtObject {
  id: root

  required property var window
  required property string namespace
  // The window's edge, telling apart same-sized windows on one screen
  property int edge: Bar.Top

  readonly property var origin: BlurManager.layerOrigin(root.namespace, root.window?.screen?.name ?? "", root.window?.width ?? 0, root.window?.height ?? 0, root.edge)

  readonly property var _inputs: [root.window?.width, root.window?.height, root.window?.visible, root.window?.screen, root.namespace, EdgeMenuManager.zones, DockManager.zones, BarManager.bars, Appearance.screenMargin, Appearance.screenBorder]
  on_InputsChanged: BlurManager.refreshLayers()
}
