// EdgePopup.qml - Corrected version with robust sizing and animation
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.components.widgets.popouts
import qs.components.reusable

Item {
  id: root

  // Core properties
  property bool active: false
  default property alias content: contentArea.data

  // ... (All other properties remain the same) ...
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
  readonly property int actualWidth: Math.max(1, (customWidth > 0 ? customWidth : (__loadedItem ? __loadedItem.implicitWidth :  0)))
  readonly property int actualHeight: Math.max(1, (customHeight > 0 ? customHeight : (__loadedItem ? __loadedItem.implicitHeight :  0)))

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
    if (active)
      active = false;
  }

  function toggle() {
    if (__animating)
      return;
    active = !active;
  }

  function setPosition(pos, offset = 0) {
    position = Math.max(0, Math.min(1, pos));
    positionOffset = offset;
  }
}
