pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import qs.components.widgets.popouts
import qs.components.reusable

import qs.config
import qs.services

Item {
  id: root

  required property string panelId
  property bool active: false
  default property alias content: contentArea.data

  property bool reserveSpace: false
  property int lockedMargin: Widget.containerWidth

  property bool aboveWindows: true
  property bool focusable: false
  property int animationDuration: 300
  property var easingType: Easing.OutCubic
  enum Edge {
    Left,
    Right,
    Top,
    Bottom
  }
  property int edge: EdgePopup.Edge.Right
  property real position: 0.5
  property real positionOffset: 0
  property int customWidth: 0
  property int customHeight: 0
  property int edgeMargin: 0
  property bool enableFade: true
  property bool enableTrigger: true
  property int triggerWidth: 5
  property int triggerLength: 1400
  property bool triggerOnHover: true
  property bool triggerOnClick: false
  property int hoverDelay: 300
  property bool showTriggerIndicator: false
  property bool closeOnMouseExit: true
  property bool closeOnClickOutside: true

  property bool __animating: false

  property var __loadedItem: contentArea.data.length > 0 ? contentArea.data[0] : null
  readonly property int actualWidth: Math.max(1, (customWidth > 0 ? customWidth : (__loadedItem ? __loadedItem.implicitWidth : 0)))
  readonly property int actualHeight: Math.max(1, (customHeight > 0 ? customHeight : (__loadedItem ? __loadedItem.implicitHeight : 0)))

  Component.onCompleted: {
    if (panelId !== "") {
      ShellManager.togglePanelReservation.connect(function (id) {
        console.log("Received togglePanelReservation for id:", id, "Current panelId:", panelId);
        if (id === panelId) {
          root.toggleReservation();
        }
      });
    }
  }

  // TODO: get this not here


  PanelWindow {
    id: reservationPanel

    // Visible only when the reservation feature is active.
    // This allows the space to be reserved even when the popup is hidden.
    visible: root.reserveSpace && (root.actualWidth > 0 && root.actualHeight > 0)

    // TODO: Get the popup above the panel windows when reservation is active,
    // this allows windows to slide under the panel, but the popup should be above
    // aboveWindows: reserveSpace ? true : false
    aboveWindows: false
    color: "transparent"
    focusable: false

    exclusiveZone: {
      if (!root.reserveSpace)
        return 0;
      return (root.edge === EdgePopup.Edge.Left || root.edge === EdgePopup.Edge.Right) ? root.actualWidth + Config.containerOffset : root.actualHeight;
    }

    implicitWidth: reservationPanel.exclusiveZone + Widget.containerWidth
    implicitHeight: Display.resolutionHeight

    Rectangle {
      anchors.fill: parent
      color: Theme.background
    }

    anchors {
      left: root.edge === EdgePopup.Edge.Left ? true : false
      right: root.edge === EdgePopup.Edge.Right ? true : false
      top: root.edge === EdgePopup.Edge.Top ? true : false
      bottom: root.edge === EdgePopup.Edge.Bottom ? true : false
    }

    margins {
      left: {
        switch (root.edge) {
        case EdgePopup.Edge.Right:
          return Screen.width - root.actualWidth;
        case EdgePopup.Edge.Top:
        case EdgePopup.Edge.Bottom:
          return (Screen.width * root.position) + root.positionOffset - (root.actualWidth / 2);
        default:
          // Left edge
          return 0;
        }
      }
      right: {
        switch (root.edge) {
        case EdgePopup.Edge.Left:
          return Screen.width - root.actualWidth;
        case EdgePopup.Edge.Top:
        case EdgePopup.Edge.Bottom:
          return Screen.width - ((Screen.width * root.position) + root.positionOffset + (root.actualWidth / 2));
        default:
          // Right edge
          return 0;
        }
      }
      top: {
        switch (root.edge) {
        case EdgePopup.Edge.Bottom:
          return Screen.height - root.actualHeight;
        case EdgePopup.Edge.Left:
        case EdgePopup.Edge.Right:
          return (Screen.height * root.position) + root.positionOffset - (root.actualHeight / 2);
        default:
          // Top edge
          return 0;
        }
      }
      bottom: {
        switch (root.edge) {
        case EdgePopup.Edge.Top:
          return Screen.height - root.actualHeight;
        case EdgePopup.Edge.Left:
        case EdgePopup.Edge.Right:
          return Screen.height - ((Screen.height * root.position) + root.positionOffset + (root.actualHeight / 2));
        default:
          // Bottom edge
          return 0;
        }
      }
    }
  }

  EdgeTrigger {
    id: trigger
    edge: {
      switch (root.edge) {
      case EdgePopup.Edge.Left:
        return EdgeTrigger.Edge.Left;
      case EdgePopup.Edge.Right:
        return EdgeTrigger.Edge.Right;
      case EdgePopup.Edge.Top:
        return EdgeTrigger.Edge.Top;
      case EdgePopup.Edge.Bottom:
        return EdgeTrigger.Edge.Bottom;
      }
    }
    position: root.position
    positionOffset: root.positionOffset
    triggerWidth: root.triggerWidth
    triggerLength: root.triggerLength
    triggerOnHover: root.triggerOnHover
    triggerOnClick: root.triggerOnClick
    hoverDelay: root.hoverDelay
    onHoverStarted: {
      if (root.enableTrigger && root.triggerOnHover && !root.active) {
        root.show();
      }
    }
    onTriggered: {
      root.show();
    }
  }

  Item {
    PopupWindow {
      id: popup
      visible: (slideContainer.active || __animating) && (root.actualWidth > 0 && root.actualHeight > 0)
      property bool locked: false

      Component.onCompleted: {
        ShellManager.togglePanelLock.connect(function (id) {
          if (id === panelId) {
            popup.locked = !popup.locked;
            if (!visible && popup.locked) {
              root.show();
            }
          }
        });
      }

      anchor.window: trigger
      anchor.rect.x: {
        switch (root.edge) {
        case EdgePopup.Edge.Left:
          return trigger.width + root.edgeMargin;
        case EdgePopup.Edge.Right:
          return -(root.actualWidth) - root.edgeMargin;
        default:
          return (trigger.width / 2) - (root.actualWidth / 2);
        }
      }
      anchor.rect.y: {
        switch (root.edge) {
        case EdgePopup.Edge.Top:
          return trigger.height + root.edgeMargin;
        case EdgePopup.Edge.Bottom:
          return -(root.actualHeight) - root.edgeMargin;
        default:
          return (trigger.height / 2) - (root.actualHeight / 2);
        }
      }

      implicitWidth: root.actualWidth
      implicitHeight: root.actualHeight
      color: "transparent"

      Item {
        id: contentWrapper
        anchors.fill: parent

        EdgeSlideContainer {
          id: slideContainer
          anchors.fill: parent

          active: root.active && root.actualWidth > 0 && root.actualHeight > 0

          edge: {
            switch (root.edge) {
            case EdgePopup.Edge.Left:
              return EdgeSlideContainer.Edge.Left;
            case EdgePopup.Edge.Right:
              return EdgeSlideContainer.Edge.Right;
            case EdgePopup.Edge.Top:
              return EdgeSlideContainer.Edge.Top;
            case EdgePopup.Edge.Bottom:
              return EdgeSlideContainer.Edge.Bottom;
            }
          }

          animationDuration: root.animationDuration
          easingType: root.easingType
          enableFade: root.enableFade
          fadeAnimationDuration: 200

          onAnimationCompleted: {
            __animating = false;
          }

          Loader {
            id: contentArea
            anchors.fill: parent
          }

          MouseArea {
            anchors.fill: parent
            enabled: root.active && root.closeOnMouseExit
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onExited: root.hide()
          }
        }
      }
    }
  }

  onActiveChanged: {
    __animating = true;
  }

  function show() {
    if (!active)
      active = true;
  }

  function hide() {
    if (popup.locked)
      return;
    if (active)
      active = false;
  }

  function toggle() {
    if (popup.locked)
      return;
    if (__animating)
      return;
    active = !active;
  }

  function showAndLock() {
    if (!active) {
      popup.locked = true;
      active = true;
    } else {
      popup.locked = !popup.locked;
    }
  }

  function setPosition(pos, offset = 0) {
    position = Math.max(0, Math.min(1, pos));
    positionOffset = offset;
  }

  function toggleReservation() {
    console.log("Toggling reservation for panel:", panelId, "New state:", !reserveSpace);
    reserveSpace = !reserveSpace;
  }
}
