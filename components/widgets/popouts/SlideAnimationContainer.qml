import QtQuick
import Quickshell

Item {
  id: root

  property bool active: false
  property bool slideFromRight: true
  property int animationDuration: 250
  property int fadeAnimationDuration: 200
  property bool enableFade: true
  property var easingType: Easing.OutCubic

  default property alias content: contentArea.children

  implicitWidth: Math.max(1, contentArea.implicitWidth)
  implicitHeight: Math.max(1, contentArea.implicitHeight)

  clip: true

  Item {
    id: contentWrapper
    width: parent.width > 0 ? parent.width : 1
    height: parent.height > 0 ? parent.height : 1

    property real targetX: 0
    property real hiddenX: {
      if (!root.parent)
        return 0;
      var w = root.width > 0 ? root.width : 1;
      return root.slideFromRight ? w : -w;
    }

    states: [
      State {
        name: "visible"
        when: root.active && root.width > 0 && root.height > 0
        PropertyChanges {
          target: contentWrapper
          x: targetX
        }
      },
      State {
        name: "hidden"
        when: !root.active || root.width <= 0 || root.height <= 0
        PropertyChanges {
          target: contentWrapper
          x: hiddenX
        }
      }
    ]

    transitions: Transition {
      NumberAnimation {
        property: "x"
        duration: root.animationDuration
        easing.type: root.easingType
      }
    }

    // Content area
    Item {
      id: contentArea
      anchors.fill: parent
    }
  }

  // Optional opacity animation
  opacity: root.enableFade ? (root.active ? 1.0 : 0.0) : 1.0

  Behavior on opacity {
    enabled: root.enableFade && root.visible
    NumberAnimation {
      duration: root.fadeAnimationDuration
      easing.type: Easing.InOutQuad
    }
  }

  // Defensive initialization
  Component.onCompleted: {
    // Delay initialization to ensure parent is ready
    Qt.callLater(function () {
      if (root.width > 0 && root.height > 0) {
        contentWrapper.x = root.active ? contentWrapper.targetX : contentWrapper.hiddenX;
      }
    });
  }

  // Update hidden position when width changes (with validation)
  onWidthChanged: {
    if (width > 0) {
      contentWrapper.hiddenX = root.slideFromRight ? width : -width;
    }
  }
}
