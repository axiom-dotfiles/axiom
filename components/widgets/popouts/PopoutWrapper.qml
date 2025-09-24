import QtQuick
import Quickshell

import qs.services
import qs.config

Item {
  id: root

  required property ShellScreen screen

  property string currentName: ""
  property var currentAnchor: null    // bar sub-item passed in
  property var currentData: null
  property bool hasCurrent: false

  property bool isClosing: false

  property Item current: content.item?.current ?? null

  // Animation properties
  property int animLength: 200
  property list<real> animCurve: [0.4, 0.0, 0.2, 1.0]
  property int gap: 4                 // small gap between bar and popout

  function closePopout() {
    if (isClosing)
      return;
    isClosing = true;

    if (mainAnimation) {
      mainAnimation.active = false;
    }
    closeDelayTimer.restart();
  }

  Timer {
    id: exitTimer
    interval: 100
    onTriggered: {
      root.closePopout();
    }
  }

  Timer {
    id: closeDelayTimer
    interval: root.animLength
    repeat: false
    onTriggered: {
      root.currentName = "";
      root.isClosing = false;
      root.hasCurrent = false;
      root.currentData = null;
      root.currentAnchor = null;
      root.current = null;
    }
  }

  function openPopout(anchor, name, data) {
    if (isClosing) {
      return;
    }
    mainAnimation.active = true;
    currentName = name;
    currentAnchor = anchor;
    currentData = data;
    hasCurrent = true;
  }

  PopupWindow {
    id: combinedPopup
    visible: root.hasCurrent && implicitWidth > 0 && implicitHeight > 0
    color: "transparent"

    // Calculate total bounds to encompass both connector and main content
    implicitWidth: {
      var connectorEnd = connectorX + connectorWidth;
      var mainEnd = mainContentX + mainContentWidth;
      return Math.max(1, Math.max(connectorEnd, mainEnd));
    }

    implicitHeight: Math.max(1, Math.max(connectorHeight, mainContentHeight))

    // Position at the leftmost point (connector start)
    anchor {
      window: currentAnchor
      rect {
        x: currentData ? (currentData.anchorX || 0) + Widget.height + 8 : 0
        y: currentData ? (currentData.anchorY || 0) - 10 : 0
        width: Math.max(1, 20)
        height: Math.max(1, currentData ? currentData.anchorHeight : 40)
      }
    }

    // Properties for layout calculations
    property int connectorX: 0
    property int connectorWidth: connectorContent.implicitWidth
    property int connectorHeight: currentData ? currentData.anchorHeight + 20 : 60

    property int mainContentX: 0
    property int mainContentWidth: content.item ? content.item.implicitWidth : 200
    property int mainContentHeight: content.item ? content.item.implicitHeight : 100

    // TODO: Outward Border Radius workaround to make the border fit into the bar

    // Container for both elements
    Item {
      anchors.fill: parent
      SlideAnimationContainer {
        id: mainAnimation
        x: combinedPopup.mainContentX
        y: 0
        width: combinedPopup.mainContentWidth + combinedPopup.connectorWidth
        height: combinedPopup.mainContentHeight

        active: false
        slideFromRight: Bar.rightSide
        animationDuration: 250
        enableFade: true
        easingType: Easing.OutCubic

        Rectangle {
          id: connectorContent
          anchors.fill: parent
          color: Theme.background
          radius: Appearance.borderRadius
          border.color: Theme.foreground

          Rectangle {
            anchors {
              left: parent.left
              top: parent.top
              bottom: parent.bottom
            }
            width: 1
            height: parent.height
            color: Theme.backgroundAlt
            // color: "red"
          }
        }
        // HoverHandler {
        //   id: hoverHandler
        //   onHoveredChanged: {
        //     console.log("hovered:", hovered);
        //     if (hovered) {
        //       exitTimer.stop();
        //     } else {
        //       exitTimer.restart();
        //     }
        //   }
        // }

        Loader {
          id: content
          // Unfortunately this needs to be set in the popout component
          // anchors.centerIn: parent

          active: hasCurrent
          asynchronous: false
          enabled: true

          // onLoaded: {
          //   console.log("Loader loaded, item:", item ? true : false, "item.implicitWidth:", item?.implicitWidth, "item.implicitHeight:", item?.implicitHeight);
          //   if (item) {
          //     item.wrapper = root;
          //   }
          // }
          //
          // onStatusChanged: {
          //   console.log("Loader status:", status, "component:", sourceComponent ? true : false);
          // }

          sourceComponent: {
            switch (root.currentName) {
            case "workspace-grid":
              return workspaceGridComponent;
            case "media-player":
              return mediaPlayerComponent;
            default:
              return null;
            }
          }
        }
      }
    }

    // Timer {
    //   id: popwinSizeTimer
    //   interval: 1
    //   onTriggered: {
    //     console.log("popup size", combinedPopup.width, combinedPopup.height);
    //   }
    // }
  }

  // Size based on content
  implicitWidth: hasCurrent && content.item ? content.item.implicitWidth : 0
  implicitHeight: hasCurrent && content.item ? content.item.implicitHeight : 0

  // IMPORTANT: give the Item real size; implicit* alone don't size an Item
  width: implicitWidth
  height: implicitHeight

  // Show only when we actually have size
  visible: width > 0 && height > 0
  clip: true
  z: 1e4  // ensure on top of bar

  Behavior on x {
    NumberAnimation {
      duration: root.animLength
      easing.bezierCurve: root.animCurve
    }
  }
  Behavior on y {
    NumberAnimation {
      duration: root.animLength
      easing.bezierCurve: root.animCurve
    }
  }
  Behavior on implicitWidth {
    NumberAnimation {
      duration: root.animLength
      easing.bezierCurve: root.animCurve
    }
  }
  Behavior on implicitHeight {
    NumberAnimation {
      duration: root.animLength
      easing.bezierCurve: root.animCurve
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
    MediaPanel {
      wrapper: root
    }
  }
}
