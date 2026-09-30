pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.services

/**
 * A popout that floats on the screen instead of growing out of an edge
 * (EdgePopout): a plain rounded box in an Overlay-layer window covering the
 * area the bars and border leave free, fading and scaling in. Used by the
 * floating OSD and the floating launcher.
 *
 * Open/close/queue state and hover-loss dismissal come from
 * PopoutWrapperBase, as for EdgePopout, and the content is a Component in
 * the same way: loaded while open (unless keepLoaded), optionally exposing
 * `autoDismiss` / `dismissDelay` / `hovered`.
 *
 * Placement: the box's anchor point is `xFraction` across and `yFraction`
 * down the free area, with `yAlign` saying which part of the box sits
 * there (0 its top, 0.5 its centre, 1 its bottom), kept `margin` inside.
 * Content that changes height while open sets `maxContentHeight`: the box
 * is placed as if it were that tall, so it doesn't move, and grows down
 * from its top (or up from its bottom with `growUp`).
 */
PopoutWrapperBase {
  id: root

  required property ShellScreen screen

  property Component content: null
  readonly property Item contentItem: loader.item as Item
  // Keep content alive while closed (content that itself reports when the
  // popout should open)
  property bool keepLoaded: false

  property real xFraction: 0.5
  property real yFraction: 0.5
  property real yAlign: 0.5
  property real margin: Appearance.screenMargin
  property real maxContentHeight: 0
  property bool growUp: false

  // Space between the box and its content
  property real contentPadding: Appearance.borderWidth + PopoutConfig.padding
  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground
  // Scale it grows in from
  property real closedScale: 0.95

  property string layerNamespace: "axiom-floating-popout"
  // Takes the keyboard, with a focus grab (content with a text field)
  property bool wantsKeyboardFocus: false
  // A click off the box closes it (the whole window takes input then)
  property bool closeOnClickOutside: false
  // Off leaves the focus grab to another window (see SurfaceGroup)
  property bool grabEnabled: true
  // Other windows the grab lets input through to
  property var grabWindows: []
  readonly property var window: surfaceWindow

  currentItem: root.contentItem
  keepAlive: boxHover.hovered || (focusGrab.active && root.wantsKeyboardFocus)

  PanelWindow {
    id: surfaceWindow
    screen: root.screen
    color: "transparent"
    // Stays mapped while the box fades out
    visible: root.occupied || box.opacity > 0
    focusable: root.wantsKeyboardFocus

    // Normal exclusion with no zone of its own: the window covers the area
    // the bars and border leave free
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.keyboardFocus: root.wantsKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Only the box takes input, unless a click beside it closes it
    mask: Region {
      item: root.closeOnClickOutside ? surfaceWindow.contentItem : box
    }

    HyprlandFocusGrab {
      id: focusGrab
      windows: [surfaceWindow].concat(root.grabWindows, ShellManager.captureWindows)
      active: root.isOpen && root.grabEnabled && (root.wantsKeyboardFocus || root.closeOnClickOutside)

      onActiveChanged: {
        if (active)
          root.contentItem?.forceActiveFocus();
      }

      onCleared: {
        if (!active)
          root.hide();
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.closeOnClickOutside
      onClicked: root.hide()
    }

    Rectangle {
      id: box

      readonly property real contentHeight: root.contentItem?.implicitHeight ?? 0
      // The height it's placed by
      readonly property real placedHeight: Math.max(box.height, root.maxContentHeight + root.contentPadding * 2)
      readonly property real placedY: Math.max(root.margin, Math.min(surfaceWindow.height * root.yFraction - box.placedHeight * root.yAlign, surfaceWindow.height - box.placedHeight - root.margin))

      width: (root.contentItem?.implicitWidth ?? 0) + root.contentPadding * 2
      height: box.contentHeight + root.contentPadding * 2
      x: Math.max(root.margin, Math.min(surfaceWindow.width * root.xFraction - width / 2, surfaceWindow.width - width - root.margin))
      y: root.growUp ? box.placedY + box.placedHeight - box.height : box.placedY
      color: root.fillColor
      border.color: root.strokeColor
      border.width: Appearance.borderWidth
      radius: Appearance.borderRadius
      clip: true

      opacity: root.isOpen ? 1 : 0
      scale: root.isOpen ? 1 : root.closedScale
      transformOrigin: root.growUp ? Item.Bottom : root.maxContentHeight > 0 ? Item.Top : Item.Center
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
      Behavior on height {
        NumberAnimation {
          duration: Appearance.animFast
          easing.type: Appearance.easing
        }
      }

      HoverHandler {
        id: boxHover
      }

      // Swallows clicks, so they don't reach the close-on-click area
      MouseArea {
        anchors.fill: parent
      }

      Loader {
        id: loader
        // Growing up, it hangs from the box's bottom: the box's height
        // animates, and the content must not move with it
        x: root.contentPadding
        y: root.growUp ? box.height - root.contentPadding - height : root.contentPadding
        width: root.contentItem?.implicitWidth ?? 0
        height: box.contentHeight
        active: root.occupied || root.keepLoaded
        sourceComponent: root.content

        onLoaded: root.updateDismissTimer()
      }
    }
  }
}
