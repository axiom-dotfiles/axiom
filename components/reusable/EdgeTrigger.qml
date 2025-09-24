// EdgeTrigger.qml - Updated with containsMouse property
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

PanelWindow {
  id: root

  // Signals
  signal triggered
  signal hoverStarted
  signal hoverEnded

  // Properties
  property alias containsMouse: mouseArea.containsMouse

  // Edge configuration
  enum Edge {
    Left,
    Right,
    Top,
    Bottom
  }
  property int edge: EdgeTrigger.Edge.Right
  property real position: 0.5  // 0-1 position along edge
  property real positionOffset: 0  // Pixel offset

  // Trigger configuration
  property int triggerWidth: 5  // Changed from 0 to 5 as default
  property int triggerLength: 200  // Length along the edge
  property bool triggerOnHover: true
  property bool triggerOnClick: false
  property int hoverDelay: 300

  color: "transparent"

  // Set anchors based on edge
  anchors {
    left: edge === EdgeTrigger.Edge.Left
    right: edge === EdgeTrigger.Edge.Right
    top: edge === EdgeTrigger.Edge.Top
    bottom: edge === EdgeTrigger.Edge.Bottom
  }

  // Size based on edge orientation
  implicitWidth: {
    switch (edge) {
    case EdgeTrigger.Edge.Left:
    case EdgeTrigger.Edge.Right:
      return triggerWidth;
    case EdgeTrigger.Edge.Top:
    case EdgeTrigger.Edge.Bottom:
      return triggerLength;
    }
  }

  implicitHeight: {
    switch (edge) {
    case EdgeTrigger.Edge.Left:
    case EdgeTrigger.Edge.Right:
      return triggerLength;
    case EdgeTrigger.Edge.Top:
    case EdgeTrigger.Edge.Bottom:
      return triggerWidth;
    }
  }

  // Position along the edge using margins
  margins {
    left: {
      if (edge === EdgeTrigger.Edge.Top || edge === EdgeTrigger.Edge.Bottom) {
        let targetX = (screen.width * position) - (triggerLength / 2) + positionOffset;
        return Math.max(0, targetX);
      }
      return 0;
    }

    right: {
      if (edge === EdgeTrigger.Edge.Top || edge === EdgeTrigger.Edge.Bottom) {
        let targetX = (screen.width * position) - (triggerLength / 2) + positionOffset;
        let rightMargin = screen.width - (targetX + triggerLength);
        return Math.max(0, rightMargin);
      }
      return 0;
    }

    top: {
      if (edge === EdgeTrigger.Edge.Left || edge === EdgeTrigger.Edge.Right) {
        let targetY = (screen.height * position) - (triggerLength / 2) + positionOffset;
        return Math.max(0, targetY);
      }
      return 0;
    }

    bottom: {
      if (edge === EdgeTrigger.Edge.Left || edge === EdgeTrigger.Edge.Right) {
        let targetY = (screen.height * position) - (triggerLength / 2) + positionOffset;
        let bottomMargin = screen.height - (targetY + triggerLength);
        return Math.max(0, bottomMargin);
      }
      return 0;
    }
  }

  // Exclude from window management
  exclusionMode: ExclusionMode.Ignore

  // Visual indicator (optional - uncomment for debugging)
  // Rectangle {
  //   id: visualIndicator
  //   anchors.fill: parent
  //   color: "blue"
  //   opacity: 0.2
  //   visible: root.showTriggerIndicator
  //
  //   Behavior on opacity {
  //     NumberAnimation { duration: 200 }
  //   }
  // }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: triggerOnHover

    onEntered: {
      if (triggerOnHover) {
        console.log("Trigger hover entered");
        hoverTimer.restart();
        root.hoverStarted();
      }
    }

    onExited: {
      console.log("Trigger hover exited");
      hoverTimer.stop();
      root.hoverEnded();
    }

    onClicked: {
      if (triggerOnClick) {
        root.triggered();
      }
    }
  }

  // Hover timer
  Timer {
    id: hoverTimer
    interval: hoverDelay
    onTriggered: {
      if (triggerOnHover && mouseArea.containsMouse) {
        console.log("Trigger timer fired");
        root.triggered();
      }
    }
  }

  // Helper functions
  function setPosition(pos, offset = 0) {
    position = Math.max(0, Math.min(1, pos));
    positionOffset = offset;
  }

  function setTriggerArea(width, length) {
    triggerWidth = width;
    triggerLength = length;
  }
}
