import QtQuick
import QtQuick.Effects
import Quickshell.Wayland

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable

// A window on the overview board: its live capture (the app icon until it
// has one), rounded. Visual only; OverviewInput takes the input.
Item {
  id: root

  // A hyprctl client
  property var windowData: null
  // False while the overview is closed: nothing is captured
  property bool capturing: true
  property real radius: 4
  property bool hovered: false
  property bool resizing: false
  // The title strip while hovered
  property bool showTitle: true

  readonly property var toplevel: HyprlandManager.toplevelForAddress(root.windowData?.address)
  readonly property string iconPath: IconResolver.resolveWindowIcon(root.windowData?.class, root.windowData?.title)
  readonly property bool focused: (root.windowData?.focusHistoryID ?? -1) === 0
  // The icon stands in only for a window that never gives a frame: not for
  // the first frame's short wait on open, and not once the window closes
  // (its toplevel goes before the client list catches up)
  property bool _hadContent: false
  property bool _waited: false

  onCapturingChanged: {
    root._hadContent = false;
    root._waited = false;
    if (root.capturing)
      iconDelay.restart();
  }
  Component.onCompleted: if (root.capturing)
    iconDelay.start()

  Timer {
    id: iconDelay
    interval: 250
    onTriggered: root._waited = true
  }

  Item {
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
      color: Theme.backgroundAlt
    }

    ScreencopyView {
      id: capture
      anchors.fill: parent
      captureSource: root.capturing ? root.toplevel : null
      // Only as sharp as shown; live only while it's being looked at or
      // resized (otherwise one frame per open)
      constraintSize: Qt.size(Math.round(root.width), Math.round(root.height))
      live: root.hovered || root.resizing
      onHasContentChanged: if (hasContent)
        root._hadContent = true
    }

    Image {
      anchors.centerIn: parent
      visible: !capture.hasContent && !root._hadContent && root._waited
      width: Math.min(parent.width, parent.height) * 0.4
      height: width
      sourceSize: Qt.size(64, 64)
      source: root.iconPath
      fillMode: Image.PreserveAspectFit
    }

    // Title strip while hovered
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: title.implicitHeight + 6
      visible: root.showTitle && root.hovered && !root.resizing && root.height > height * 2.5
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.85)

      StyledText {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        text: root.windowData?.title || root.windowData?.class || ""
        textSize: Appearance.fontSize - 3
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
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
    color: "transparent"
    border.width: root.hovered || root.resizing ? Appearance.borderWidth * 2 : Appearance.borderWidth
    border.color: root.resizing || root.hovered ? Theme.accent : root.focused ? Theme.borderFocus : Theme.border

    Behavior on border.color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  // App icon badge, once there's a capture to put it on
  Image {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 4
    visible: capture.hasContent && root.height > 40
    width: Math.min(24, root.height / 4)
    height: width
    sourceSize: Qt.size(48, 48)
    source: root.iconPath
    fillMode: Image.PreserveAspectFit
  }

  // Size while resizing
  Rectangle {
    anchors.centerIn: parent
    visible: root.resizing
    width: sizeLabel.implicitWidth + 12
    height: sizeLabel.implicitHeight + 6
    radius: height / 2
    color: Theme.accent

    StyledText {
      id: sizeLabel
      anchors.centerIn: parent
      text: `${root.windowData?.size?.[0] ?? 0} × ${root.windowData?.size?.[1] ?? 0}`
      textSize: Appearance.fontSize - 2
      textColor: Theme.background
    }
  }
}
