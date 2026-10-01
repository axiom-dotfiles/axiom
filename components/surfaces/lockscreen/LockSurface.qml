pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.overlay
import qs.components.content.parts

// What one screen shows while the built-in lock is up (the content of a
// WlSessionLockSurface, see shell/Lockscreen.qml), or in the layouts
// editor's preview: the background (wallpaper or a color, dimmed), then
// the layout's modules on its grid of `columns` × `rows` units, stretched
// to fill the screen. The compositor gives the lock surfaces all input and
// hides everything else, so this needs no focus grabs or layer tricks.
//
// The password field lives on the target screen (a Password module, else
// a field of its own, so no layout can lock anyone out); other screens show
// the modules without it, or the background only (`otherScreens`). Nothing
// here may unlock or run commands: only AuthManager's success unlocks, and
// lock screen modules are the ones whose x-hosts list "lockscreen".
Item {
  id: root

  required property ShellScreen screen
  // The layout shown: the saved one, or the layouts editor's draft in its
  // preview (see LockscreenConfig.layout)
  property var layout: LockscreenConfig.layout
  // The editor's preview: nothing is locked and the field is inert
  property bool preview: false

  readonly property bool isTarget: ShellManager.isTarget(root.screen)
  readonly property var allModules: root.layout?.modules ?? []
  readonly property var modules: root.isTarget ? root.allModules : root.layout?.otherScreens === "layout" ? root.allModules.filter(module => module?.type !== "Password") : []
  // Where this surface's Password module reports itself
  // (LockManager.passwordFields): this instance's own, set once on
  // creation (a binding would loop on the counter newSurfaceKey bumps)
  property string passwordKey: ""

  // The grid: at least columns × rows (doubled with fineGrid), fitted
  // inside a margin
  readonly property real margin: OverlayConfig.cardSpacing
  readonly property var reach: GridPlacement.bounds(root.allModules)
  readonly property var gridSize: LockscreenConfig.gridOf(root.layout)
  readonly property int cols: Math.max(root.gridSize.cols, root.reach.cols, 1)
  readonly property int rows: Math.max(root.gridSize.rows, root.reach.rows, 1)

  anchors.fill: parent

  // The fallback field waits a tick, so a Password module can report first
  property bool _settled: false
  Component.onCompleted: {
    root.passwordKey = LockManager.newSurfaceKey(root.preview);
    Qt.callLater(() => root._settled = true);
  }

  Rectangle {
    anchors.fill: parent
    color: root.layout?.background === "color" ? Theme.resolveColor(root.layout.backgroundColor) : Theme.background
  }

  Image {
    anchors.fill: parent
    visible: root.layout?.background === "wallpaper"
    source: visible ? Appearance.wallpaperFor(root.screen.name) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    sourceSize: Qt.size(root.screen.width, root.screen.height)
    layer.enabled: LockscreenConfig.blurWallpaper
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1
      blurMax: 64
      autoPaddingEnabled: false
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: (root.layout?.dim ?? 0) / 100
  }

  // Fades in over the backdrop, which is there from the first frame
  Item {
    anchors.fill: parent
    opacity: 0
    Component.onCompleted: opacity = 1

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animSlow
        easing.type: Easing.InOutQuad
      }
    }

    ModuleGrid {
      x: root.margin
      y: root.margin
      modules: root.modules
      extent: ({
          "cols": root.cols,
          "rows": root.rows
        })
      stretch: ({
          "width": root.width - root.margin * 2,
          "height": root.height - root.margin * 2
        })
      host: ({
          "kind": "lockscreen",
          "target": root.isTarget,
          "preview": root.preview,
          "key": root.passwordKey,
          "bare": !(root.layout?.moduleBorders ?? false),
          "passwordBorder": root.layout?.passwordBorder ?? false,
          "greetingBorder": root.layout?.greetingBorder ?? false
        })
      grid: OverlayGrid {
        fixedUnit: GridPlacement.latticeUnit(root.cols, root.rows, root.width, root.height, root.margin)
      }
    }

    // No Password module shows on the target screen: a field of its own,
    // over whatever else is there, near the bottom
    Loader {
      z: 1
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: parent.height / 6
      width: Math.min(parent.width * 0.6, Appearance.fontSize * 28)
      active: root.isTarget && root._settled && LockManager.passwordFields[root.passwordKey] !== true
      sourceComponent: Rectangle {
        implicitHeight: fallback.implicitHeight + Widget.padding * 2
        radius: Widget.radius
        color: Theme.background
        border.color: Theme.border
        border.width: Appearance.borderWidth

        PasswordField {
          id: fallback
          anchors.fill: parent
          anchors.margins: Widget.padding
          active: !root.preview
        }
      }
    }
  }
}
