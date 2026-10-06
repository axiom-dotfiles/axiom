pragma ComponentBehavior: Bound
import QtQuick

import qs.components.content.parts
import qs.components.hosts.popout

// A tray item's menu. Its submenus open beside it (TraySubmenuWrapper).
Item {
  id: root

  required property var wrapper

  property var trayItem: wrapper.currentData?.trayItem
  property bool isVertical: wrapper.currentData?.isVertical ?? false
  property var barConfig: wrapper.currentData?.barConfig
  property bool submenuOpen: false

  readonly property bool openToLeft: root.wrapper?.openToLeft ?? false

  readonly property bool hovered: hoverHandler.hovered || root.submenuOpen

  implicitWidth: menuList.implicitWidth
  implicitHeight: menuList.implicitHeight

  // The host keeps the popout hidden until the menu has arrived
  readonly property bool contentReady: menuList.contentReady

  HoverHandler {
    id: hoverHandler
  }

  TraySubmenuWrapper {
    id: submenuWrapper
    screen: root.wrapper.screen
    openToLeft: root.openToLeft

    // root.hovered folds this in, and the wrapper (BarPopouts) reacts to it.
    // A submenu gone with the pointer off this menu and its icon (it left
    // the submenu, or picked an entry) takes the menu with it at once,
    // closing in a cascade rather than after the menu's own dismiss delay
    onOccupiedChanged: {
      root.submenuOpen = occupied;
      if (!occupied && !hoverHandler.hovered && !root.wrapper.anchorHovered)
        root.wrapper.requestDismiss();
    }
  }

  TrayMenuList {
    id: menuList
    anchors.fill: parent
    menu: root.trayItem?.menu
    openToLeft: submenuWrapper.openToLeft
    maxWidth: (root.wrapper.screen?.width ?? 2000) * 0.3

    onSubmenuRequested: function (itemDelegate) {
      // Everything in the popup window's coordinates: the submenu attaches
      // to the side of this popout's box, level with the item
      const windowPos = itemDelegate.mapToItem(null, 0, 0);
      submenuWrapper.safeOpenPopout(root.wrapper.popupWindow, {
        menuItem: itemDelegate.menuItem,
        anchorItem: itemDelegate,
        anchorY: windowPos.y,
        attachRect: root.wrapper.boxRect
      });
    }

    // Close any open submenu when hovering an item without one
    onPlainItemHovered: submenuWrapper.closePopout()
  }
}
