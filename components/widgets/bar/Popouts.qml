pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.services
import qs.config
import qs.components.widgets.bar
import qs.components.widgets.popouts

// This is somewhere I would argue a little repeated code for an entire all-in-one solution

/**
 * Popout wrapper for bar widgets
 * Handles positioning, animation, and content loading for popouts that emerge from the bar
 */
Item {
  id: root

  required property ShellScreen screen
  required property var barConfig
  required property QtObject panel

  property var currentAnchor: null
  property var currentData: null
  property string currentName: ""
  property bool occupied: false
  property bool isClosing: false

  property Item currentItem: loader.item ?? null

  // Gap between bar and main content (connector thickness)
  readonly property int connectorGap: 4

  function closePopout() {
    if (isClosing) return
    isClosing = true
    closeDelayTimer.restart()
  }

  function openPopout(anchor, name, data) {
    if (isClosing) return
    
    currentAnchor = anchor
    currentData = data
    currentName = name
    occupied = true
  }

  Timer {
    id: closeDelayTimer
    interval: Widget.animationDuration
    repeat: false
    onTriggered: {
      root.occupied = false
      root.isClosing = false
      root.currentAnchor = null
      root.currentData = null
      root.currentName = ""
    }
  }

  PopupWindow {
    id: mainPopup
    visible: root.occupied && loader.status === Loader.Ready
    screen: root.screen
    color: "transparent"

    // Content dimensions
    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100
    
    // Total size including connector gap
    implicitWidth: {
      if (root.barConfig.vertical) {
        return contentWidth + root.connectorGap
      }
      return contentWidth
    }
    
    implicitHeight: {
      if (root.barConfig.vertical) {
        return contentHeight
      }
      return contentHeight + root.connectorGap
    }

    anchor {
      window: root.currentAnchor
      
      rect {
        x: {
          if (!root.currentData) return 0
          
          if (root.barConfig.left) {
            // Start at bar edge (extent from screen edge)
            return root.barConfig.extent
          } else if (root.barConfig.right) {
            // Position so animation slides from right
            return (root.currentData.anchorX ?? 0) - mainPopup.implicitWidth
          } else {
            // Top/Bottom: center horizontally with anchor
            let anchorCenter = (root.currentData.anchorX ?? 0) + (root.currentData.anchorWidth ?? 0) / 2
            let popoutCenter = mainPopup.implicitWidth / 2
            let targetX = anchorCenter - popoutCenter
            
            // Clamp to screen bounds
            return Math.max(Appearance.screenMargin, 
                          Math.min(targetX, Display.resolutionWidth - mainPopup.implicitWidth - Appearance.screenMargin))
          }
        }
        
        y: {
          if (!root.currentData) return 0
          
          if (root.barConfig.top) {
            // Start at bar edge
            return root.barConfig.extent
          } else if (root.barConfig.bottom) {
            // Position so animation slides from bottom
            return (root.currentData.anchorY ?? 0) - mainPopup.implicitHeight
          } else {
            // Left/Right: center vertically with anchor
            let anchorCenter = (root.currentData.anchorY ?? 0) + (root.currentData.anchorHeight ?? 0) / 2
            let popoutCenter = mainPopup.implicitHeight / 2
            let targetY = anchorCenter - popoutCenter
            
            // Clamp to screen bounds
            return Math.max(Appearance.screenMargin,
                          Math.min(targetY, Display.resolutionHeight - mainPopup.implicitHeight - Appearance.screenMargin))
          }
        }
        
        width: 1
        height: 1
      }
    }

    SlideAnimation {
      id: slideContainer
      anchors.fill: parent
      
      active: root.occupied && !root.isClosing
      slideFromRight: root.barConfig.right
      slideFromLeft: root.barConfig.left
      slideFromTop: root.barConfig.top
      slideFromBottom: root.barConfig.bottom
      animationDuration: Widget.animationDuration
      enableFade: Widget.animations

      Rectangle {
        id: topCorner
      }
      
      // Main content container
      Rectangle {
        id: contentContainer
        color: Theme.background
        radius: Appearance.borderRadius
        border.color: Theme.foreground
        border.width: Appearance.borderWidth

        // Position with gap from bar edge
        x: root.barConfig.left ? root.connectorGap - Appearance.borderRadius: 0
        y: root.barConfig.top ? root.connectorGap - Appearance.borderRadius: 0
        
        width: root.barConfig.vertical ? 
          parent.width - root.connectorGap : 
          parent.width
        height: root.barConfig.vertical ? 
          parent.height : 
          parent.height - root.connectorGap

        // Content loads INSIDE this rectangle
        Loader {
          id: loader
          anchors.fill: parent
          anchors.margins: Widget.spacing
          
          active: root.occupied
          asynchronous: false

          sourceComponent: {
            switch (root.currentName) {
              case "workspace-grid":
                return workspaceGridComponent
              case "media-player":
                return mediaPlayerComponent
              default:
                return null
            }
          }

          onLoaded: {
            if (item) {
              item.wrapper = root
              if (root.currentData) {
                // Pass through any additional data properties
                for (let key in root.currentData) {
                  if (item.hasOwnProperty(key)) {
                    item[key] = root.currentData[key]
                  }
                }
              }
            }
          }
        }
      }

      // Connector - thin bridge between bar and content
      Rectangle {
        id: connector
        color: Theme.background
        
        // Position based on bar location (on the bar-facing edge)
        x: root.barConfig.left ? 0 : 
           root.barConfig.right ? parent.width - root.connectorGap : 0
        y: root.barConfig.top ? 0 : 
           root.barConfig.bottom ? parent.height - root.connectorGap : 0
        
        width: root.barConfig.vertical ? root.connectorGap : parent.width
        height: root.barConfig.vertical ? parent.height : root.connectorGap
        
        // TODO: Add inverted corner shapepaths here for smooth bar connection
      }
    }
  }

  Component {
    id: workspaceGridComponent
    WorkspacePopOut {
      wrapper: root
    }
  }

  Component {
    id: mediaPlayerComponent
    Item {} // Placeholder
  }
}
