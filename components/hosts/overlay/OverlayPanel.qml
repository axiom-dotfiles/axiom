pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config
import qs.services
import qs.components.reusable
// Imported (though views load by URL) so qs scans the view types
import qs.components.views // qmllint disable unused-imports

PanelWindow {
  id: root

  required property var screen

  property bool isOpen: false
  property real slideOffset: isOpen ? 0 : -height

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  // Normal exclusion with no zone of its own places the window inside the
  // border's and bars' reserved area, wherever the bars are, so pages
  // center in the free space and the bars stay reachable; the
  // -borderWidth margin lines it up with their inner stroke (as EdgePopout).
  // The window itself is transparent: ScreenBackdrop dims the whole
  // monitor under it. A bare screen edge (no border, no bar) has no stroke
  // to land on: the panel meets the edge.
  readonly property bool openTop: Bar.screenEdgeOpen(root.screen, Bar.Top)
  readonly property bool openBottom: Bar.screenEdgeOpen(root.screen, Bar.Bottom)
  readonly property bool openLeft: Bar.screenEdgeOpen(root.screen, Bar.Left)
  readonly property bool openRight: Bar.screenEdgeOpen(root.screen, Bar.Right)
  // A transparent bar reserves Hyprland's gaps_out less than its extent
  // (see BarPanel) and has no stroke to land on: sit at its invisible
  // inner edge instead, past the reserved space by that gap
  readonly property var _edges: Bar.edgesFor(root.screen)
  function _margin(side, open) {
    if (open)
      return 0;
    if (root._edges[side]?.background === "transparent")
      return HyprlandManager.gapsOut[side] ?? 0;
    return -Appearance.borderWidth;
  }
  margins {
    left: root._margin("left", root.openLeft)
    right: root._margin("right", root.openRight)
    top: root._margin("top", root.openTop)
    bottom: root._margin("bottom", root.openBottom)
  }

  color: "transparent"
  focusable: true
  visible: false
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  function open() {
    visible = true;
    isOpen = true;
    slideContainer.forceActiveFocus();
  }

  function close() {
    isOpen = false;
    hideTimer.start();
  }

  // When the overlay last closed from a click outside it: a click on a
  // button outside the grab (e.g. another monitor's bar) clears the grab
  // (closing it) before the button toggles, which must not reopen it
  property real _outsideCloseTime: 0

  function toggle() {
    if (!isOpen && Date.now() - _outsideCloseTime < 300)
      return;
    if (isOpen) {
      close();
    } else {
      open();
    }
  }

  Timer {
    id: hideTimer
    interval: Appearance.animSlow
    repeat: false
    onTriggered: {
      root.visible = false;
    }
  }

  Connections {
    target: ShellManager
    function onToggleOverlay() {
      if (ShellManager.isTarget(root.screen, OverlayConfig.monitors))
        root.toggle();
    }
    function onOpenOverlayPage(type) {
      if (!ShellManager.isTarget(root.screen, OverlayConfig.monitors))
        return;
      root.open();
      ShellManager.showOverlayPage(type);
    }
    function onCloseOverlay() {
      if (root.isOpen)
        root.close();
    }
  }

  IpcHandler {
    target: "overlay"
    // One handler per target name: the target screen's
    enabled: ShellManager.isTarget(root.screen, OverlayConfig.monitors)

    function open() {
      root.open();
    }

    function close() {
      root.close();
    }

    function toggle() {
      root.toggle();
    }

    // Opens on a page by view type (e.g. "BarEditor", "Themes")
    function page(type: string) {
      root.open();
      ShellManager.showOverlayPage(type);
    }
  }

  // On every monitor, the instances open and close together
  SurfaceGroup {
    id: group
    kind: "overlay"
    mode: OverlayConfig.monitors
    screen: root.screen
    window: root
    shown: root.isOpen
    onSyncRequested: shown => shown ? root.open() : root.close()
  }

  HyprlandFocusGrab {
    id: grab
    active: root.visible && group.ownsGrab
    // This screen's bars and their popouts stay usable while it's open
    // (every screen's, and the other instances, when it's on all of them)
    windows: group.windows.concat(ShellManager.grabPartnersFor(group.everywhere ? null : root.screen))
    onCleared: {
      if (!root.isOpen) {
        grab.active = true;
      } else if (OverlayConfig.closeOnOutsideClick) {
        root._outsideCloseTime = Date.now();
        root.close();
      }
    }
  }

  Item {
    id: slideContainer
    anchors.fill: parent
    // Keys nothing inside the overlay handled end up here
    focus: true
    Keys.onEscapePressed: event => {
      if (OverlayConfig.closeOnEscape && root.isOpen)
        root.close();
      else
        event.accepted = false;
    }

    transform: Translate {
      y: root.slideOffset
      Behavior on y {
        NumberAnimation {
          duration: Appearance.animSlow
          easing.type: Easing.InOutQuad
        }
      }
    }

    // The empty background (the backdrop shows through it): a click on
    // it, outside the page and the navigator, closes. Declared first, so it
    // only gets clicks nothing over it takes.
    MouseArea {
      id: backgroundClicks
      anchors.fill: parent
      enabled: OverlayConfig.closeOnOutsideClick && root.isOpen
      onClicked: mouse => {
        const inside = item => {
          const p = backgroundClicks.mapToItem(item, mouse.x, mouse.y);
          return item.contains(p);
        };
        if (!inside(tabWrapper) && !inside(navigator))
          root.close();
      }
    }

    // Where pages go: everything above the navigator, so a page never
    // sits under its dots
    Item {
      id: pageArea
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        bottom: navigator.top
        bottomMargin: Widget.padding * 2
      }

      OverlayPages {
        id: tabWrapper
        anchors.centerIn: parent
        screen: root.screen
        open: root.visible
        grid: grid
        // The window has no size until it's first mapped: until then,
        // estimate from the screen so the first page is built to fit
        maxWidth: (pageArea.width > 0 ? pageArea.width : root.screen.width) - OverlayConfig.cardSpacing * 2
        maxHeight: (pageArea.height > 0 ? pageArea.height : root.screen.height - navigator.height - Widget.padding * 4) - OverlayConfig.cardSpacing * 2
      }
    }

    // This screen's card size: what fits the space the pages get
    OverlayGrid {
      id: grid
      availableWidth: tabWrapper.maxWidth - OverlayConfig.cardSpacing * 2
      availableHeight: tabWrapper.maxHeight - OverlayConfig.cardSpacing * 2
    }

    OverlayPageNavigator {
      id: navigator
      anchors {
        bottom: parent.bottom
        bottomMargin: Widget.padding * 2
        horizontalCenter: parent.horizontalCenter
      }
      currentIndex: tabWrapper.currentIndex
      pages: tabWrapper.pages
      maxWidth: slideContainer.width - Widget.padding * 4
      onPrevious: tabWrapper.currentIndex = (tabWrapper.currentIndex - 1 + tabWrapper.pageCount) % tabWrapper.pageCount
      onNext: tabWrapper.currentIndex = (tabWrapper.currentIndex + 1) % tabWrapper.pageCount
      onSelect: index => tabWrapper.currentIndex = index
    }
  }
}
