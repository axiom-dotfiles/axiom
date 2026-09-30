pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.components.hosts.popout

// An OSD that floats on the screen instead of sliding out of an edge: a
// plain rounded box whose centre sits at x% across and y% up the free area
// (inside the bars and border), fading in. Open/close and hover-aware
// dismissal are PopoutWrapperBase's, as for EdgePopout.
PopoutWrapperBase {
  id: root

  required property ShellScreen screen
  // 0-1 across (from the left) and up (from the bottom)
  property real xFraction: 0.5
  property real yFraction: 0.33
  property Component content: null
  readonly property Item contentItem: loader.item as Item
  // Space between the box and its content
  property real contentPadding: Appearance.borderWidth + PopoutConfig.padding

  currentItem: root.contentItem
  keepAlive: boxHover.hovered

  PanelWindow {
    id: window
    screen: root.screen
    color: "transparent"
    // Stays mapped while the box fades out
    visible: root.occupied || box.opacity > 0

    // Normal exclusion with no zone of its own: the window covers the area
    // the bars and border leave free
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "axiom-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Only the box takes input (scrolling a bar, hovering to keep it open)
    mask: Region {
      item: box
    }

    Rectangle {
      id: box

      readonly property real margin: Appearance.screenMargin

      width: (root.contentItem?.implicitWidth ?? 0) + root.contentPadding * 2
      height: (root.contentItem?.implicitHeight ?? 0) + root.contentPadding * 2
      x: Math.max(margin, Math.min(window.width * root.xFraction - width / 2, window.width - width - margin))
      y: Math.max(margin, Math.min(window.height * (1 - root.yFraction) - height / 2, window.height - height - margin))
      color: Theme.background
      border.color: Theme.foreground
      border.width: Appearance.borderWidth
      radius: Appearance.borderRadius

      opacity: root.isOpen ? 1 : 0
      scale: root.isOpen ? 1 : 0.95
      Behavior on opacity {
        NumberAnimation {
          duration: Appearance.animNormal
          easing.type: Appearance.easing
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: Appearance.animNormal
          easing.type: Appearance.easing
        }
      }

      HoverHandler {
        id: boxHover
      }

      Loader {
        id: loader
        x: root.contentPadding
        y: root.contentPadding
        width: root.contentItem?.implicitWidth ?? 0
        height: root.contentItem?.implicitHeight ?? 0
        // The bars report their own changes, so they exist while closed
        active: true
        sourceComponent: root.content

        onLoaded: root.updateDismissTimer()
      }
    }
  }
}
