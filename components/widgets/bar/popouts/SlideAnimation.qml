import QtQuick
import qs.config

/**
 * Reusable slide animation container
 * Supports sliding from any direction with optional fade
 */
Item {
  id: root

  property bool active: false
  
  // Direction flags (only one should be true)
  property bool slideFromRight: false
  property bool slideFromLeft: false
  property bool slideFromTop: false
  property bool slideFromBottom: false
  
  property int animationDuration: Widget.animations ? Widget.animationDuration : 0
  property bool enableFade: true
  property var easingType: Easing.OutCubic

  default property alias content: contentArea.children

  clip: true

  Item {
    id: contentWrapper
    width: parent.width
    height: parent.height

    readonly property real targetX: 0
    readonly property real targetY: 0
    
    readonly property real hiddenX: {
      if (root.slideFromRight) return root.width
      if (root.slideFromLeft) return -root.width
      return 0
    }
    
    readonly property real hiddenY: {
      if (root.slideFromBottom) return root.height
      if (root.slideFromTop) return -root.height
      return 0
    }

    states: [
      State {
        name: "visible"
        when: root.active
        PropertyChanges {
          target: contentWrapper
          x: targetX
          y: targetY
        }
      },
      State {
        name: "hidden"
        when: !root.active
        PropertyChanges {
          target: contentWrapper
          x: hiddenX
          y: hiddenY
        }
      }
    ]

    transitions: Transition {
      NumberAnimation {
        properties: "x,y"
        duration: root.animationDuration
        easing.type: root.easingType
      }
    }

    Item {
      id: contentArea
      anchors.fill: parent
    }
  }

  // Fade animation
  opacity: root.enableFade ? (root.active ? 1.0 : 0.0) : 1.0

  Behavior on opacity {
    enabled: root.enableFade
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Component.onCompleted: {
    Qt.callLater(function() {
      contentWrapper.x = root.active ? contentWrapper.targetX : contentWrapper.hiddenX
      contentWrapper.y = root.active ? contentWrapper.targetY : contentWrapper.hiddenY
    })
  }
}
