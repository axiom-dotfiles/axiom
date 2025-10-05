// TrayMenuItem.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

/**
 * Reusable tray menu item component
 */
Rectangle {
  id: menuItemDelegate

  required property var menuItem  // QsMenuEntry
  required property int itemHeight
  required property int itemPadding
  required property var onItemClicked  // Function to call when item is clicked
  required property var onSubmenuRequested  // Function to call when submenu should open

  Layout.fillWidth: true
  Layout.preferredHeight: menuItem.isSeparator ? 1 : itemHeight

  visible: true
  color: menuItemArea.containsMouse && menuItem.enabled && !menuItem.isSeparator ? Theme.backgroundHighlight : "transparent"
  radius: Appearance.borderRadius
  opacity: menuItem.enabled ? 1.0 : 0.5

  // Main content row (hidden for separators)
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: menuItemDelegate.itemPadding
    anchors.rightMargin: menuItemDelegate.itemPadding
    spacing: 8
    visible: !menuItemDelegate.menuItem.isSeparator

    // Checkbox/Radio indicator
    Rectangle {
      visible: menuItemDelegate.menuItem.buttonType !== QsMenuButtonType.None
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      color: "transparent"
      border.color: Theme.accent
      border.width: 1
      radius: menuItemDelegate.menuItem.buttonType === QsMenuButtonType.RadioButton ? 8 : 2

      Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: parent.height - 6
        radius: menuItemDelegate.menuItem.buttonType === QsMenuButtonType.RadioButton ? 5 : 1
        color: Theme.accent
        visible: menuItemDelegate.menuItem.checkState === Qt.Checked
      }
    }

    // Icon
    Image {
      visible: menuItemDelegate.menuItem.icon !== ""
      source: menuItemDelegate.menuItem.icon
      sourceSize.width: 16
      sourceSize.height: 16
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    // Label
    Text {
      text: menuItemDelegate.menuItem.text
      color: Theme.accent
      Layout.fillWidth: true
      elide: Text.ElideRight
    }

    // Submenu indicator
    Text {
      visible: menuItemDelegate.menuItem.hasChildren
      text: "›"
      color: Theme.accent
    }
  }

  // Separator line
  Rectangle {
    anchors.centerIn: parent
    width: parent.width - (menuItemDelegate.itemPadding * 2)
    height: 1
    color: Theme.foreground
    opacity: 0.2
    visible: menuItemDelegate.menuItem.isSeparator
  }

  // Hover timer for submenu opening
  Timer {
    id: submenuHoverTimer
    interval: 200
    repeat: false
    onTriggered: {
      if (menuItemDelegate.menuItem.hasChildren && menuItemArea.containsMouse) {
        menuItemDelegate.onSubmenuRequested(menuItemDelegate);
      }
    }
  }

  MouseArea {
    id: menuItemArea
    anchors.fill: parent
    hoverEnabled: true
    enabled: menuItemDelegate.menuItem.enabled && !menuItemDelegate.menuItem.isSeparator

    onEntered: {
      if (menuItemDelegate.menuItem.hasChildren) {
        submenuHoverTimer.restart();
      }
    }

    onExited: {
      submenuHoverTimer.stop();
    }

    onClicked: {
      if (menuItemDelegate.menuItem.hasChildren) {
        menuItemDelegate.onSubmenuRequested(menuItemDelegate);
      } else {
        console.log("Triggering menu item:", menuItemDelegate.menuItem.text);
        menuItemDelegate.menuItem.triggered();
        menuItemDelegate.onItemClicked();
      }
    }
  }
}
