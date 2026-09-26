pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config

PanelWindow {
  id: root

  // Signals
  signal triggered
  signal hoverStarted
  signal hoverEnded

  // Properties
  property alias containsMouse: mouseArea.containsMouse

  // Edge configuration (a Bar.Location value, shared with bars/popouts)
  property int edge: Bar.Right
  property real position: 0.5  // 0-1 position along edge
  property real positionOffset: 0  // Pixel offset

  // Trigger configuration
  property int triggerWidth: 5  // Changed from 0 to 5 as default
  property int triggerLength: 200  // Length along the edge
  property bool triggerOnHover: true
  property bool triggerOnClick: false
  property int hoverDelay: 300

  color: "transparent"

  // Anchor the attach edge, plus both sides of the perpendicular axis: a
  // wlr-layer-shell margin only takes effect on an anchored edge, and
  // positioning along the edge (margins.top/bottom or left/right below)
  // needs both anchored, not just one, else the surface centers itself.
  anchors {
    left: edge !== Bar.Right
    right: edge !== Bar.Left
    top: edge !== Bar.Bottom
    bottom: edge !== Bar.Top
  }

  // Size based on edge orientation
  implicitWidth: {
    switch (edge) {
    case Bar.Left:
    case Bar.Right:
      return triggerWidth;
    case Bar.Top:
    case Bar.Bottom:
      return triggerLength;
    }
  }

  implicitHeight: {
    switch (edge) {
    case Bar.Left:
    case Bar.Right:
      return triggerLength;
    case Bar.Top:
    case Bar.Bottom:
      return triggerWidth;
    }
  }

  // Position along the edge using margins
  margins {
    left: {
      if (edge === Bar.Top || edge === Bar.Bottom) {
        let targetX = (screen.width * position) - (triggerLength / 2) + positionOffset;
        return Math.max(0, targetX);
      }
      return 0;
    }

    right: {
      if (edge === Bar.Top || edge === Bar.Bottom) {
        let targetX = (screen.width * position) - (triggerLength / 2) + positionOffset;
        let rightMargin = screen.width - (targetX + triggerLength);
        return Math.max(0, rightMargin);
      }
      return 0;
    }

    top: {
      if (edge === Bar.Left || edge === Bar.Right) {
        let targetY = (screen.height * position) - (triggerLength / 2) + positionOffset;
        return Math.max(0, targetY);
      }
      return 0;
    }

    bottom: {
      if (edge === Bar.Left || edge === Bar.Right) {
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
  //     NumberAnimation { duration: Appearance.animNormal }
  //   }
  // }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: triggerOnHover

    onEntered: {
      if (triggerOnHover) {
        hoverTimer.restart();
        root.hoverStarted();
      }
    }

    onExited: {
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
