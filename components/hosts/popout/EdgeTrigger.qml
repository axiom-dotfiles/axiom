pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services

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

  // Integrated edge menus' zones (EdgeMenuManager) move the surfaces this
  // triggers inwards, so the trigger follows: past a zone on its own edge,
  // and along it as the edge's free length shrinks from either end
  readonly property string _edgeName: ["top", "bottom", "left", "right"][edge]
  readonly property bool _vertical: edge === Bar.Left || edge === Bar.Right
  property real edgeInset: EdgeMenuManager.zoneOn(screen?.name ?? "", _edgeName)
  property real startInset: EdgeMenuManager.zoneOn(screen?.name ?? "", _vertical ? "top" : "left")
  property real endInset: EdgeMenuManager.zoneOn(screen?.name ?? "", _vertical ? "bottom" : "right")
  // The trigger's centre along the edge, within the free length
  readonly property real _centre: startInset + ((_vertical ? screen.height : screen.width) - startInset - endInset) * position + positionOffset

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
    left: edge === Bar.Left ? edgeInset : _vertical ? 0 : Math.max(0, _centre - triggerLength / 2)
    right: edge === Bar.Right ? edgeInset : _vertical ? 0 : Math.max(0, screen.width - _centre - triggerLength / 2)
    top: edge === Bar.Top ? edgeInset : !_vertical ? 0 : Math.max(0, _centre - triggerLength / 2)
    bottom: edge === Bar.Bottom ? edgeInset : !_vertical ? 0 : Math.max(0, screen.height - _centre - triggerLength / 2)
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
