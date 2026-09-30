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

ReservedAreaWindow {
  id: root

  required property ShellScreen screen

  property bool isOpen: false
  property real slideOffset: isOpen ? 0 : -height

  visible: false
  // Its layer rule arranges it after docks and draws it over them
  // (see HyprlandManager.layerRulesLua)
  WlrLayershell.namespace: "axiom-overlay"

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
    // Only while open: a grab held through the close animation would be
    // cleared by any click then, for nothing
    active: root.isOpen && group.ownsGrab
    // This screen's bars and their popouts stay usable while it's open
    // (every screen's, and the other instances, when it's on all of them)
    windows: group.windows.concat(ShellManager.grabPartnersFor(group.everywhere ? null : root.screen), ShellManager.captureWindows)
    onCleared: {
      if (root.isOpen && OverlayConfig.closeOnOutsideClick) {
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
        if (!inside(overlayPages) && !inside(navigator))
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
        id: overlayPages
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
      availableWidth: overlayPages.maxWidth - OverlayConfig.cardSpacing * 2
      availableHeight: overlayPages.maxHeight - OverlayConfig.cardSpacing * 2
    }

    OverlayPageNavigator {
      id: navigator
      anchors {
        bottom: parent.bottom
        bottomMargin: Widget.padding * 2
        horizontalCenter: parent.horizontalCenter
      }
      currentIndex: overlayPages.currentIndex
      pages: overlayPages.pages
      maxWidth: slideContainer.width - Widget.padding * 4
      onPrevious: overlayPages.currentIndex = (overlayPages.currentIndex - 1 + overlayPages.pageCount) % overlayPages.pageCount
      onNext: overlayPages.currentIndex = (overlayPages.currentIndex + 1) % overlayPages.pageCount
      onSelect: index => overlayPages.currentIndex = index
    }
  }
}
