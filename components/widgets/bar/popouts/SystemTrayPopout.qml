// SystemTrayMenuPopout.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

import qs.config
import qs.components.widgets.bar.popouts

// TODO: not single file
Item {
  id: root

  required property var wrapper

  property var trayItem: wrapper.currentData?.trayItem
  property bool isVertical: wrapper.currentData?.isVertical ?? false
  property var menuHandle: trayItem?.menu  // QsMenuHandle

  readonly property int itemSpacing: 4
  readonly property int itemHeight: 32
  readonly property int itemPadding: 8
  readonly property int minWidth: 200

  implicitWidth: Math.max(minWidth, menuLayout.implicitWidth + 20)
  implicitHeight: menuLayout.implicitHeight + 20 + Widget.padding * 2 // TODO: magic num removal

  Behavior on width {
    NumberAnimation {
      duration: Widget.animationDuration / 3
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitHeight {
    NumberAnimation {
      duration: Widget.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  // Auto-close when mouse leaves
  HoverHandler {
    id: hoverHandler
    onHoveredChanged: {
      if (hovered) {
        exitTimer.stop();
      } else {
        exitTimer.restart();
      }
    }
  }

  Timer {
    id: exitTimer
    interval: 40
    onTriggered: {
      root.wrapper.closePopout();
    }
  }

  // Menu opener to access the menu children
  QsMenuOpener {
    id: menuOpener
    menu: root.menuHandle
  }

  // Submenu wrapper instance
  TraySubmenuWrapper {
    id: submenuWrapper
    screen: root.wrapper.screen
    parentPopup: root.wrapper.panel
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
    anchors.fill: parent
    anchors.margins: 8
    color: Theme.backgroundAlt
    // border.color: Theme.border
    // border.width: Appearance.borderWidth
    radius: Appearance.borderRadius

    // Prevent clicks from propagating to the background MouseArea
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

        delegate: Rectangle {
          id: menuItemDelegate

          required property var modelData
          readonly property var menuItem: modelData  // QsMenuEntry

          Layout.fillWidth: true
          Layout.preferredHeight: menuItem.isSeparator ? 1 : root.itemHeight

          visible: true
          color: menuItemArea.containsMouse && menuItem.enabled && !menuItem.isSeparator ? Theme.backgroundHighlight : "transparent"
          radius: Appearance.borderRadius
          opacity: menuItem.enabled ? 1.0 : 0.5

          // Main content row (hidden for separators)
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.itemPadding
            anchors.rightMargin: root.itemPadding
            spacing: 8
            visible: !menuItem.isSeparator

            // Checkbox/Radio indicator
            Rectangle {
              visible: menuItem.buttonType !== QsMenuButtonType.None
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              color: "transparent"
              border.color: Theme.accent
              border.width: 1
              radius: menuItem.buttonType === QsMenuButtonType.RadioButton ? 8 : 2

              Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: parent.height - 6
                radius: menuItem.buttonType === QsMenuButtonType.RadioButton ? 5 : 1
                color: Theme.accent
                visible: menuItem.checkState === Qt.Checked
              }
            }

            // Icon
            Image {
              visible: menuItem.icon !== ""
              source: menuItem.icon
              sourceSize.width: 16
              sourceSize.height: 16
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              fillMode: Image.PreserveAspectFit
              smooth: true
            }

            // Label
            Text {
              text: menuItem.text
              color: Theme.accent
              // font.family: Config.appearance.fontFamily
              // font.pixelSize: Config.appearance.fontSize - 2
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            // Submenu indicator
            Text {
              visible: menuItem.hasChildren
              text: "›"
              color: Theme.accent
              // font.family: Config.appearance.fontFamily
              // font.pixelSize: Config.appearance.fontSize
            }
          }

          // Separator line
          Rectangle {
            anchors.centerIn: parent
            width: parent.width - (root.itemPadding * 2)
            height: 1
            color: Theme.foreground
            opacity: 0.2
            visible: menuItem.isSeparator
          }

          // Hover timer for submenu opening
          Timer {
            id: submenuHoverTimer
            interval: 200
            repeat: false
            onTriggered: {
              if (menuItem.hasChildren && menuItemArea.containsMouse) {
                openSubmenu();
              }
            }
          }

          function openSubmenu() {
            let globalPos = menuItemDelegate.mapToGlobal(0, 0);
            console.log("Opening submenu for item:", menuItem.text, "at", globalPos);
            // Pass menuItem through currentData
            submenuWrapper.openPopout(root.wrapper.panel, {
              menuItem: menuItem,
              anchorX: globalPos.x,
              anchorY: globalPos.y,
              anchorWidth: menuItemDelegate.width,
              anchorHeight: menuItemDelegate.height
            });
          }

          MouseArea {
            id: menuItemArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: menuItem.enabled && !menuItem.isSeparator

            onEntered: {
              if (menuItem.hasChildren) {
                submenuHoverTimer.restart();
              } else {
                // Close any open submenu when hovering other items
                submenuWrapper.closePopout();
              }
            }

            onExited: {
              submenuHoverTimer.stop();
            }

            onClicked: {
              if (menuItem.hasChildren) {
                openSubmenu();
              } else {
                console.log("Triggering menu item:", menuItem.text);
                menuItem.triggered();
                submenuWrapper.closePopout();
                root.wrapper.closePopout();
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
