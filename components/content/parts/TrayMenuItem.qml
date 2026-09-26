// TrayMenuItem.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// TODO: Use styled components to make this way cleaner
/**
 * Reusable tray menu item component
 */
Rectangle {
  id: root
  required property var menuItem
  required property int itemHeight
  required property int itemPadding
  signal itemClicked
  signal submenuRequested(Item itemDelegate)
  // Pointer entered an item without a submenu (callers close open submenus)
  signal plainItemHovered
  property int minItemWidth: 100
  property int maxItemWidth: 600
  property bool openToLeft
  // Keeps a submenu opened from this item up while the pointer is on it
  readonly property bool hovered: menuItemArea.containsMouse

  Layout.fillWidth: true
  Layout.preferredWidth: contentRow.implicitWidth + (itemPadding * 2)
  Layout.minimumWidth: minItemWidth
  Layout.maximumWidth: maxItemWidth
  Layout.preferredHeight: menuItem.isSeparator ? 1 : itemHeight
  visible: true
  color: menuItemArea.containsMouse && menuItem.enabled && !menuItem.isSeparator ? Theme.backgroundHighlight : "transparent"
  radius: Appearance.borderRadius
  opacity: menuItem.enabled ? 1.0 : 0.5

  // Main content row
  RowLayout {
    id: contentRow
    anchors.fill: parent
    anchors.leftMargin: root.itemPadding
    anchors.rightMargin: root.itemPadding
    spacing: 8
    visible: !root.menuItem.isSeparator
    layoutDirection: root.openToLeft ? Qt.RightToLeft : Qt.LeftToRight

    // Checkbox/Radio indicator
    Rectangle {
      visible: root.menuItem.buttonType !== QsMenuButtonType.None
      Layout.preferredWidth: 16
      Layout.maximumWidth: 16
      Layout.minimumWidth: 16
      Layout.preferredHeight: 16
      color: "transparent"
      border.color: Theme.foreground
      border.width: 1
      radius: root.menuItem.buttonType === QsMenuButtonType.RadioButton ? 8 : 2

      Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: parent.height - 6
        radius: root.menuItem.buttonType === QsMenuButtonType.RadioButton ? 5 : 1
        color: Theme.accent
        visible: root.menuItem.checkState === Qt.Checked
      }
    }

    // Icon
    Image {
      visible: root.menuItem.icon !== ""
      source: root.menuItem.icon
      sourceSize.width: 16
      sourceSize.height: 16
      Layout.preferredWidth: 16
      Layout.maximumWidth: 16
      Layout.minimumWidth: 16
      Layout.preferredHeight: 16
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    // Label
    Text {
      text: root.menuItem.text
      color: Theme.foreground
      Layout.fillWidth: true
      Layout.minimumWidth: 50
      elide: Text.ElideRight
      wrapMode: Text.NoWrap
      clip: true
      horizontalAlignment: root.openToLeft ? Text.AlignRight : Text.AlignLeft
    }

    // Submenu indicator
    Text {
      visible: root.menuItem.hasChildren
      text: root.openToLeft ? "‹" : "›"
      color: Theme.accent
      font.pixelSize: 20
      Layout.preferredWidth: implicitWidth
      Layout.maximumWidth: implicitWidth
      Layout.minimumWidth: implicitWidth
    }
  }

  // Separator line
  Rectangle {
    anchors.centerIn: parent
    width: parent.width - (root.itemPadding * 2)
    height: 1
    color: Theme.foreground
    opacity: 0.2
    visible: root.menuItem.isSeparator
  }

  // Hover timer for submenu opening
  Timer {
    id: submenuHoverTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (root.menuItem.hasChildren && menuItemArea.containsMouse) {
        root.submenuRequested(root);
      }
    }
  }

  MouseArea {
    id: menuItemArea
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.menuItem.enabled && !root.menuItem.isSeparator

    onEntered: {
      if (root.menuItem.hasChildren) {
        submenuHoverTimer.restart();
      } else {
        root.plainItemHovered();
      }
    }

    onExited: {
      submenuHoverTimer.stop();
    }

    onClicked: {
      if (root.menuItem.hasChildren) {
        root.submenuRequested(root);
      } else {
        root.menuItem.triggered();
        root.itemClicked();
      }
    }
  }
}
