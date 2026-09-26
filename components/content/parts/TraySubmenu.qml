pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

/**
 * Submenu content
 */
Item {
  id: root
  required property var wrapper
  required property var menuItem
  readonly property int itemSpacing: 4
  readonly property int itemHeight: 32
  readonly property int itemPadding: 8
  // TODO: which of all these mins and maxes actually constrain the items
  readonly property int minWidth: 200
  readonly property int maxWidth: 800

  implicitWidth: Math.max(minWidth, Math.min(maxWidth, menuLayout.implicitWidth + 20))
  implicitHeight: menuLayout.implicitHeight + 20 + Widget.padding * 2

  // Exposes our hover state to the wrapper's (TraySubmenuWrapper)
  // centralized dismiss logic — timing and dismissal now live there.
  property alias hovered: hoverHandler.hovered

  HoverHandler {
    id: hoverHandler
  }

  // Menu opener to access this submenu's children
  QsMenuOpener {
    id: menuOpener
    menu: root.menuItem
  }
  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: {
      root.wrapper.requestDismiss();
    }
  }
  // Background container
  Rectangle {
    anchors.fill: parent
    anchors.margins: Widget.padding
    color: Theme.backgroundAlt
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
        delegate: TrayMenuItem {
          required property var modelData
          menuItem: modelData
          itemHeight: root.itemHeight
          itemPadding: root.itemPadding
          minItemWidth: root.minWidth - 40
          maxItemWidth: root.maxWidth - 40
          onItemClicked: function () {
            root.wrapper.requestDismiss();
          }
          // A nested submenu drills down: it replaces this one in the same
          // place (same anchor window and attach rect), since there is one
          // submenu wrapper per tray popout
          onSubmenuRequested: function (itemDelegate) {
            root.wrapper.safeOpenPopout(root.wrapper.currentAnchor, Object.assign({}, root.wrapper.currentData, {
              menuItem: itemDelegate.menuItem
            }));
          }
        }
      }
      // Empty state
      Text {
        visible: menuOpener.children.values.length === 0
        text: I18n.tr("No submenu items")
        color: Theme.accent
        opacity: 0.5
        Layout.fillWidth: true
        Layout.preferredHeight: root.itemHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
