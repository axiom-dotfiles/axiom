pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services

// A surface's shape, registered with BlurManager for the blur window
// (shell/BlurBacking) to draw and blur in its place. `source` is an
// AttachedSurface (`kind: "attached"`) or a Rectangle (`"rect"`), mirrored
// there with its geometry bound live; `x`/`y` are where its top-left sits
// on `screen` (a screen name).
QtObject {
  id: root

  required property Item source
  // A rect's fill (an AttachedSurface's is its fillColor)
  property color color: Theme.background
  property string kind: "attached"
  property string screen: ""
  property real x: 0
  property real y: 0
  // Placed (its window found on screen) and showing
  property bool shown: true
  // Its key in BlurManager, set as it registers
  property int uid: -1
  // What of it shows, on screen: its window's rect, for a shape that moves
  // past its window's edges (a hiding dock); null for the whole screen
  property var clipRect: null

  Component.onCompleted: BlurManager.register(root)
  Component.onDestruction: BlurManager.unregister(root)
}
