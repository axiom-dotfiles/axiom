// TraySubmenuPopout.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
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
  readonly property int minWidth: 200
  readonly property int maxWidth: 400
  
  implicitWidth: Math.max(minWidth, Math.min(maxWidth, menuLayout.implicitWidth + 20))
  implicitHeight: menuLayout.implicitHeight + 20 + Widget.padding * 2
  
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
  // Menu opener to access this submenu's children
  QsMenuOpener {
    id: menuOpener
    menu: root.menuItem
  }
  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: {
      root.wrapper.closePopout();
    }
  }
  // Background container
  Rectangle {
    anchors.fill: parent
    anchors.margins: 8
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
          onItemClicked: function() {
            root.wrapper.closePopout();
          }
          onSubmenuRequested: function(itemDelegate) {
            let globalPos = itemDelegate.mapToGlobal(0, 0);
            root.wrapper.safeOpenPopout(root.wrapper.parentPopup, {
              menuItem: itemDelegate.menuItem,
              parentItemDelegate: itemDelegate,
              anchorX: globalPos.x,
              anchorY: globalPos.y,
              anchorWidth: itemDelegate.width,
              anchorHeight: itemDelegate.height
            });
          }
        }
      }
      // Empty state
      Text {
        visible: menuOpener.children.length === 0
        text: "No submenu items"
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
