import QtQuick
import QtQuick.Effects

import qs.config

// One workspace on the overview board: a miniature desktop (the monitor's
// wallpaper, or a plain color). Its number is a WorkspaceNumber, drawn above
// the windows by OverviewGrid. Visual only; OverviewInput takes the input.
Item {
  id: root

  // A wallpaper URL, or "" for a plain `color`
  property string wallpaper: ""
  property color color: Theme.backgroundAlt
  // 0-1: how dark it is drawn when it isn't the active workspace
  property real dim: 0.5
  property real radius: Appearance.borderRadius
  // The monitor's active workspace
  property bool current: false
  property bool hovered: false
  // A window is being dragged over it; dropFill: onto it as a whole (it
  // has no tiled windows to split)
  property bool dropTarget: false
  property bool dropFill: false

  Item {
    id: desktop
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }

    Rectangle {
      anchors.fill: parent
      color: root.color
    }

    Image {
      anchors.fill: parent
      visible: root.wallpaper !== ""
      source: root.wallpaper
      // Every cell asks for the same size, so they share one decoded image
      sourceSize: Qt.size(Math.round(root.width), Math.round(root.height))
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
    }

    // Other workspaces sit back a little
    Rectangle {
      anchors.fill: parent
      color: Theme.base00
      opacity: root.current || root.dropTarget ? 0 : root.hovered ? root.dim * 0.4 : root.dim

      Behavior on opacity {
        NumberAnimation {
          duration: Appearance.animFast
        }
      }
    }
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: true
  }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.dropFill ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : "transparent"
    border.width: root.current || root.dropTarget ? Appearance.borderWidth * 2 : Appearance.borderWidth
    border.color: root.dropTarget ? Theme.accent : root.current ? Theme.accent : root.hovered ? Theme.borderFocus : Theme.border

    Behavior on border.color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }
}
