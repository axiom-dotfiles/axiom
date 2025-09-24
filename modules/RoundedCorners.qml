import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services
import qs.config

PanelWindow {
  id: workspaceContainer
  property int borderWidth: Widget.containerWidth
  property int innerBorderWidth: 1
  property int borderRadius: Appearance.borderRadius
  property color borderColor: Theme.foreground

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  aboveWindows: true
  WlrLayershell.layer: WlrLayer.Top
  color: "transparent"
  mask: Region {}

  // TODO: Figure out a better way to do this without a small black dot in
  // each corner.
  // Create the border effect with multiple rectangles
  // Top border (excluding corners)
  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
      rightMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    }
    height: workspaceContainer.borderWidth
    color: Theme.background
  }

  // Bottom border (excluding corners)
  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      leftMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
      rightMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    }
    height: workspaceContainer.borderWidth
    color: Theme.background
  }

  // Left border (excluding corners)
  // Rectangle {
  //   anchors {
  //     left: parent.left
  //     top: parent.top
  //     bottom: parent.bottom
  //     topMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
  //     bottomMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
  //   }
  //   width: workspaceContainer.borderWidth
  //   color: Theme.background
  // }

  // Right border (excluding corners)
  Rectangle {
    anchors {
      right: parent.right
      top: parent.top
      bottom: parent.bottom
      topMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
      bottomMargin: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    }
    width: workspaceContainer.borderWidth
    color: Theme.background
  }

  // Top-left corner
  Rectangle {
    anchors {
      left: parent.left
      top: parent.top
    }
    width: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    height: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    color: Theme.background

    Item {
      clip: true
      Rectangle {
        anchors {
          right: parent.right
          bottom: parent.bottom
        }
        width: workspaceContainer.borderRadius
        height: workspaceContainer.borderRadius
        color: Theme.accent
        radius: workspaceContainer.borderRadius
      }
    }
  }

  // Top-right corner
  Rectangle {
    anchors {
      right: parent.right
      top: parent.top
    }
    width: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    height: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    color: Theme.background

    Rectangle {
      anchors {
        left: parent.left
        bottom: parent.bottom
      }
      width: workspaceContainer.borderRadius
      height: workspaceContainer.borderRadius
      color: "transparent"
      radius: workspaceContainer.borderRadius
    }
  }

  // Bottom-left corner
  Rectangle {
    anchors {
      left: parent.left
      bottom: parent.bottom
    }
    width: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    height: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    color: Theme.background

    Rectangle {
      anchors {
        right: parent.right
        top: parent.top
      }
      width: workspaceContainer.borderRadius
      height: workspaceContainer.borderRadius
      color: "transparent"
      radius: workspaceContainer.borderRadius
    }
  }

  // Bottom-right corner
  Rectangle {
    anchors {
      right: parent.right
      bottom: parent.bottom
    }
    width: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    height: workspaceContainer.borderWidth + workspaceContainer.borderRadius
    color: Theme.background

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
      }
      width: workspaceContainer.borderRadius
      height: workspaceContainer.borderRadius
      color: "transparent"
      radius: workspaceContainer.borderRadius
    }
  }

  // Inner border around the cutout
  Rectangle {
    anchors {
      fill: parent
      margins: workspaceContainer.borderWidth - workspaceContainer.innerBorderWidth
      leftMargin: 0
    }
    radius: workspaceContainer.borderRadius
    color: "transparent"
    border.width: workspaceContainer.innerBorderWidth
    border.color: workspaceContainer.borderColor
  }
}
