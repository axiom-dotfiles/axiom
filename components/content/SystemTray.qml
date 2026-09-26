pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.components.content.parts
import qs.components.hosts.popout

// TODO: Use styled components to make this way cleaner
Item {
  id: root

  required property var wrapper

  property var trayItem: wrapper.currentData?.trayItem
  property bool isVertical: wrapper.currentData?.isVertical ?? false
  property var barConfig: wrapper.currentData?.barConfig
  property var menuHandle: trayItem?.menu
  property bool submenuOpen: false

  readonly property int itemSpacing: 4
  readonly property int itemHeight: 32
  readonly property int itemPadding: Widget.padding
  readonly property int minWidth: 350

  readonly property bool openToLeft: root.wrapper?.openToLeft ?? false

  readonly property bool hovered: hoverHandler.hovered || root.submenuOpen

  // TODO: wtf is this 20
  implicitWidth: Math.max(minWidth, menuLayout.implicitWidth + 20)
  implicitHeight: menuLayout.implicitHeight + 20 + Widget.padding * 2

  Behavior on width {
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitHeight {
    NumberAnimation {
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
  }

  HoverHandler {
    id: hoverHandler
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.menuHandle
  }

  TraySubmenuWrapper {
    id: submenuWrapper
    screen: root.wrapper.screen
    openToLeft: root.openToLeft

    // Just report state — root.hovered above folds this in, and the
    // wrapper (BarPopouts) reacts to that automatically. No manual timer
    // poking needed here anymore.
    onOccupiedChanged: {
      root.submenuOpen = occupied;
    }
  }

  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: {
      submenuWrapper.requestDismiss();
      root.wrapper.requestDismiss();
    }
  }

  // Background container
  Rectangle {
    id: backgroundContainer
    anchors.fill: parent
    anchors.margins: Widget.padding
    color: Theme.backgroundAlt
    // border.color: Theme.border
    // border.width: Appearance.borderWidth
    radius: Appearance.borderRadius

    MouseArea {
      anchors.fill: parent
      onClicked: {
        mouse.accepted = true;
      }
    }

    ColumnLayout {
      id: menuLayout
      anchors.centerIn: parent
      spacing: root.itemSpacing
      width: parent.width - 20

      Repeater {
        model: menuOpener.children

        delegate: TrayMenuItem {
          required property var modelData
          openToLeft: submenuWrapper.openToLeft

          menuItem: modelData
          itemHeight: root.itemHeight
          itemPadding: root.itemPadding

          onSubmenuRequested: function (itemDelegate) {
            // Everything in the popup window's coordinates: the submenu
            // attaches to the side of this popout's box, level with the item
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

      // Empty state
      Text {
        visible: menuOpener.children.values.length === 0
        text: I18n.tr("No menu items")
        color: Theme.accent
        // font.family: Paths.appearance.fontFamily
        // font.pixelSize: Paths.appearance.fontSize - 2
        opacity: 0.5
        Layout.fillWidth: true
        Layout.preferredHeight: root.itemHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
