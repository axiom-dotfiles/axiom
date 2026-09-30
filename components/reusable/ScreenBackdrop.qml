pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config

// A full-screen surface's dim background (the overlay, workspace overview
// and launcher): the whole monitor, under the bars and the border, which
// stay drawn over it. A Top-layer window mapped after them would land
// above them, so HyprlandManager gives this namespace a higher layer
// order, which stacks it under them. It takes no input: clicks go to the
// surface above it, or to the bars and border (which clears the
// surface's focus grab, unless the surface lets its screen's bars
// through: see ShellManager.grabPartners).
PanelWindow {
  id: root

  // Whether it's showing; it stays mapped while it animates out
  property bool shown: false
  // Slides down from the top edge with the surface (the overlay) instead
  // of fading in and out
  property bool slide: false
  property int duration: slide ? Appearance.animSlow : Appearance.animNormal
  property color fillColor: Appearance.darkMode ? Theme.background : Theme.foreground
  property real fillOpacity: 0.85

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "axiom-backdrop"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  color: "transparent"
  visible: root.shown || (root.slide ? slideOffset.y > -root.height : fill.opacity > 0)
  mask: Region {}

  Rectangle {
    id: fill
    anchors.fill: parent
    color: root.fillColor
    opacity: root.slide || root.shown ? root.fillOpacity : 0

    Behavior on opacity {
      enabled: !root.slide
      NumberAnimation {
        duration: root.duration
        easing.type: Appearance.easing
      }
    }

    transform: Translate {
      id: slideOffset
      y: !root.slide || root.shown ? 0 : -root.height
      Behavior on y {
        enabled: root.slide
        NumberAnimation {
          duration: root.duration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }
}
