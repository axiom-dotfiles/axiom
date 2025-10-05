// SystemTrayMenuPopout.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

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
  implicitHeight: menuLayout.implicitHeight + 20
  
  width: implicitWidth
  height: implicitHeight
  
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
    color: Theme.background
    border.color: Theme.foreground
    border.width: Appearance.borderWidth
    radius: Appearance.borderRadius
    
    // Prevent clicks from propagating to the background MouseArea
    MouseArea {
      anchors.fill: parent
      onClicked: {
        // Consume the click event to prevent closing
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
          color: menuItemArea.containsMouse && menuItem.enabled && !menuItem.isSeparator 
                 ? Theme.backgroundAlt 
                 : "transparent"
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
          
          MouseArea {
            id: menuItemArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: menuItem.enabled && !menuItem.isSeparator
            
            onClicked: {
              if (menuItem.hasChildren) {
                // TODO: Handle submenu navigation
                // You could create a nested popout with a new QsMenuOpener
                console.log("Submenu clicked:", menuItem.text);
              } else {
                console.log("Triggering menu item:", menuItem.text);
                menuItem.triggered();
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
  
  // Debug logging
  Component.onCompleted: {
    console.log("Menu handle:", root.menuHandle);
    console.log("Menu opener children count:", menuOpener.children.count);
    
    // Log first few items to see structure
    for (let i = 0; i < Math.min(3, menuOpener.children.count); i++) {
      const item = menuOpener.children.get(i);
      console.log("Menu item", i, "- text:", item.text, 
                  "enabled:", item.enabled,
                  "isSeparator:", item.isSeparator,
                  "hasChildren:", item.hasChildren,
                  "buttonType:", item.buttonType);
    }
  }
}
