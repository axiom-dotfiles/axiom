// TraySubmenuPopout.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

/**
 * Submenu content - reuses the same wrapper for nested submenus
 * No circular dependency because we don't create new wrappers
 */
Item {
  id: root
  
  required property var wrapper
  required property var menuItem  // QsMenuEntry - the parent item that has children
  
  readonly property int itemSpacing: 4
  readonly property int itemHeight: 32
  readonly property int itemPadding: 8
  readonly property int minWidth: 200
  
  implicitWidth: Math.max(minWidth, menuLayout.implicitWidth + 20)
  implicitHeight: menuLayout.implicitHeight + 20
  
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
        
        delegate: Rectangle {
          id: submenuItemDelegate
          
          required property var modelData
          readonly property var submenuItem: modelData  // QsMenuEntry
          
          Layout.fillWidth: true
          Layout.preferredHeight: submenuItem.isSeparator ? 1 : root.itemHeight
          
          visible: true
          color: submenuItemArea.containsMouse && submenuItem.enabled && !submenuItem.isSeparator 
                 ? Theme.backgroundHighlight
                 : "transparent"
          radius: Appearance.borderRadius
          opacity: submenuItem.enabled ? 1.0 : 0.5
          
          // Main content row (hidden for separators)
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.itemPadding
            anchors.rightMargin: root.itemPadding
            spacing: 8
            visible: !submenuItem.isSeparator
            
            // Checkbox/Radio indicator
            Rectangle {
              visible: submenuItem.buttonType !== QsMenuButtonType.None
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              color: "transparent"
              border.color: Theme.accent
              border.width: 1
              radius: submenuItem.buttonType === QsMenuButtonType.RadioButton ? 8 : 2
              
              Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: parent.height - 6
                radius: submenuItem.buttonType === QsMenuButtonType.RadioButton ? 5 : 1
                color: Theme.accent
                visible: submenuItem.checkState === Qt.Checked
              }
            }
            
            // Icon
            Image {
              visible: submenuItem.icon !== ""
              source: submenuItem.icon
              sourceSize.width: 16
              sourceSize.height: 16
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            
            // Label
            Text {
              text: submenuItem.text
              color: Theme.accent
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
            
            // Submenu indicator (for nested submenus)
            Text {
              visible: submenuItem.hasChildren
              text: "›"
              color: Theme.accent
            }
          }
          
          // Separator line
          Rectangle {
            anchors.centerIn: parent
            width: parent.width - (root.itemPadding * 2)
            height: 1
            color: Theme.foreground
            opacity: 0.2
            visible: submenuItem.isSeparator
          }
          
          // Hover timer for nested submenu opening
          Timer {
            id: nestedSubmenuHoverTimer
            interval: 200
            repeat: false
            onTriggered: {
              if (submenuItem.hasChildren && submenuItemArea.containsMouse) {
                openNestedSubmenu();
              }
            }
          }
          
          function openNestedSubmenu() {
            // Get global position of this item
            let globalPos = submenuItemDelegate.mapToGlobal(0, 0);
            
            // REUSE the same wrapper - just update its content
            // This avoids circular dependency
            root.wrapper.openPopout(root.wrapper.parentPopup, {
              menuItem: submenuItem,  // The new submenu to show
              parentItemDelegate: submenuItemDelegate,
              anchorX: globalPos.x,
              anchorY: globalPos.y,
              anchorWidth: submenuItemDelegate.width,
              anchorHeight: submenuItemDelegate.height
            });
          }
          
          MouseArea {
            id: submenuItemArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: submenuItem.enabled && !submenuItem.isSeparator
            
            onEntered: {
              if (submenuItem.hasChildren) {
                nestedSubmenuHoverTimer.restart();
              }
            }
            
            onExited: {
              nestedSubmenuHoverTimer.stop();
            }
            
            onClicked: {
              if (submenuItem.hasChildren) {
                // Open nested submenu by reusing the wrapper
                openNestedSubmenu();
              } else {
                // Trigger the action and close everything
                console.log("Triggering submenu item:", submenuItem.text);
                submenuItem.triggered();
                root.wrapper.closePopout();
              }
            }
          }
        }
      }
      
      // Empty state
      Text {
        visible: menuOpener.children.count === 0
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
