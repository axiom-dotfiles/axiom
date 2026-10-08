pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell

import qs.config
import qs.components.methods
import qs.components.hosts.overlay

// One screen of a screen layout (a ScreenLayout: the lock screen's, the
// greeter's): the background (wallpaper or a color, dimmed), then the
// modules on the layout's grid of `columns` × `rows` units, stretched to
// fill the screen, fading in. Children go over the modules (LockSurface's
// and GreeterSurface's fallback fields).
Item {
  id: root

  required property ShellScreen screen
  // The ScreenLayout shown
  property var layout: null
  // The modules shown here (the surface leaves some out on other screens)
  property var modules: []
  // Passed to every module (`host`); its `kind` ("lockscreen",
  // "greeter") is the x-hosts name the modules must list
  property var host: ({})
  // What's drawn: only modules whose x-hosts list this host. Validation
  // takes any module in a layout and only the editor's library holds to
  // x-hosts, but the greeter's layout comes from a folder any of the
  // user's programs can write, and must never get a module that launches
  // or runs anything
  readonly property var shownModules: root.modules.filter(module => OverlayConfig.moduleInfo(module?.type)?.hosts.includes(root.host.kind) === true)
  // Its wallpaper, when the background is "wallpaper"
  property string wallpaper: ""
  property bool blurWallpaper: true

  default property alias content: fade.data

  // The grid: at least columns × rows (doubled with fineGrid), fitted
  // inside a margin
  readonly property real margin: OverlayConfig.cardSpacing
  readonly property var reach: GridPlacement.bounds(root.layout?.modules ?? [])
  readonly property var gridSize: GridPlacement.screenGrid(root.layout)
  readonly property int cols: Math.max(root.gridSize.cols, root.reach.cols, 1)
  readonly property int rows: Math.max(root.gridSize.rows, root.reach.rows, 1)

  anchors.fill: parent

  // The background, which translucent modules frost (`frosted`)
  Item {
    id: backdrop
    anchors.fill: parent

    Rectangle {
      anchors.fill: parent
      color: root.layout?.background === "color" ? Theme.resolveColor(root.layout.backgroundColor) : Theme.background
    }

    Image {
      anchors.fill: parent
      visible: root.layout?.background === "wallpaper"
      source: visible ? root.wallpaper : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize: Qt.size(root.screen?.width ?? 0, root.screen?.height ?? 0)
      layer.enabled: root.blurWallpaper
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
  }

  // No compositor blur reaches a lock surface (or the greeter's), so while
  // the shell's surfaces blur, the modules frost the background here
  // themselves, at about Hyprland's strength: the backdrop blurred, where
  // the modules draw at least the blur threshold (as Hyprland's
  // ignore_alpha). Not over a wallpaper blurred already.
  readonly property bool frosted: Appearance.blur && !(root.layout?.background === "wallpaper" && root.blurWallpaper)
  readonly property var _strength: HyprLua.blurStrength(Appearance.blurStrength)

  ShaderEffectSource {
    id: backdropCapture
    anchors.fill: parent
    visible: false
    sourceItem: root.frosted ? backdrop : null
  }

  ShaderEffectSource {
    id: modulesCapture
    anchors.fill: parent
    visible: false
    sourceItem: root.frosted ? grid : null
    sourceRect: Qt.rect(-grid.x, -grid.y, root.width, root.height)
  }

  // Fades in over the backdrop, which is there from the first frame
  Item {
    id: fade

    anchors.fill: parent
    opacity: 0
    Component.onCompleted: opacity = 1

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animSlow
        easing.type: Easing.InOutQuad
      }
    }

    MultiEffect {
      anchors.fill: parent
      visible: root.frosted
      source: backdropCapture
      autoPaddingEnabled: false
      blurEnabled: true
      blur: 1
      blurMax: Math.min(64, root._strength.size * Math.pow(2, root._strength.passes))
      maskEnabled: true
      maskSource: modulesCapture
      maskThresholdMin: Appearance.blurThreshold
      maskSpreadAtMin: 0
    }

    ModuleGrid {
      id: grid
      x: root.margin
      y: root.margin
      modules: root.shownModules
      extent: ({
          "cols": root.cols,
          "rows": root.rows
        })
      stretch: ({
          "width": root.width - root.margin * 2,
          "height": root.height - root.margin * 2
        })
      host: root.host
      grid: OverlayGrid {
        fixedUnit: GridPlacement.latticeUnit(root.cols, root.rows, root.width, root.height, root.margin)
      }
    }
  }
}
