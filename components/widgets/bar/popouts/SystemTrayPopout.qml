// SystemTrayPopout.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

import qs.config
import qs.components.widgets.bar.popouts

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
  readonly property int minWidth: 200

  property bool openToLeft: false

  // TODO: wtf is this 20
  implicitWidth: Math.max(minWidth, menuLayout.implicitWidth + 20)
  implicitHeight: menuLayout.implicitHeight + 20 + Widget.padding * 2

  Behavior on width {
    NumberAnimation {
      duration: Appearance.animationDuration / 3
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitHeight {
    NumberAnimation {
      duration: Appearance.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  HoverHandler {
    id: hoverHandler
    onHoveredChanged: {
      if (hovered) {
        exitTimer.stop();
      } else {
        if (!root.submenuOpen) {
          exitTimer.restart();
        }
      }
    }
  }

  Timer {
    id: exitTimer
    interval: 40
    onTriggered: {
      if (!root.submenuOpen) {
        root.wrapper.closePopout();
      }
    }
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.menuHandle
  }

  TraySubmenuWrapper {
    id: submenuWrapper
    screen: root.wrapper.screen
    openToLeft: root.openToLeft
    
    onOccupiedChanged: {
      root.submenuOpen = occupied;
      if (!occupied && !hoverHandler.hovered) {
        exitTimer.restart();
      }
    }
  }

  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: {
      submenuWrapper.closePopout();
      root.wrapper.closePopout();
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

          onItemClicked: function() {
            // submenuWrapper.closePopout();
            // root.wrapper.closePopout();
          }

          onSubmenuRequested: function(itemDelegate) {
            // let globalPos = itemDelegate.mapToGlobal(0, 0);
            let localPos = itemDelegate.mapToItem(backgroundContainer, 0, 0);
            console.log("Opening submenu for", itemDelegate.menuItem.text, "at", localPos.x, localPos.y, "item size", itemDelegate.width, itemDelegate.height);
            
            submenuWrapper.safeOpenPopout(root.wrapper.popupWindow, {
              menuItem: itemDelegate.menuItem,
              anchorX: localPos.x,
              anchorY: localPos.y,
              anchorWidth: itemDelegate.width,
              anchorHeight: itemDelegate.height
            });
          }

          Component.onCompleted: {
            // Close any open submenu when hovering non-submenu items
            if (!menuItem.hasChildren) {
              const mouseArea = children[children.length - 1]; // Get the MouseArea
              if (mouseArea && mouseArea.hasOwnProperty("entered")) {
                mouseArea.entered.connect(function() {
                  submenuWrapper.closePopout();
                });
              }
            }
          }
        }
      }

      // Empty state
      Text {
        visible: menuOpener.children.count === 0
        text: "No menu items"
        color: Theme.accent
        // font.family: Config.appearance.fontFamily
        // font.pixelSize: Config.appearance.fontSize - 2
        opacity: 0.5
        Layout.fillWidth: true
        Layout.preferredHeight: root.itemHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
