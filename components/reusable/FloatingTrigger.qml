import QtQuick
import Quickshell

import qs.config

PanelWindow {
  id: root

  property var popouts: null
  property var panel: null

  anchors {
    top: true
    left: !Bar.vertical
    right: Bar.vertical
  }

  implicitWidth: Display.resolutionWidth / 3
  implicitHeight: 40
  color: "transparent"

  // PanelWindow.exclusionMode: PanelWindow.ExclusionMode.Ignore

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true

    onEntered: {
      hoverTimer.restart();
    }

    onExited: {
      hoverTimer.stop();
    }
  }

  Timer {
    id: hoverTimer
    interval: 300

    onTriggered: {
      if (root.popouts && panel) {
        console.log("anchor", root.x, root.y, root.width, root.height);
        root.popouts.openPopout(root.panel, "media-player", {
          monitor: root.monitor,
          activeId: root.monitor?.activeWorkspace?.id ?? 1,
          anchorX: 0 + Bar.extent,
          anchorY: 0 + Bar.extent,
          anchorWidth: root.width,
          anchorHeight: root.height
        });
      }
      // if (popouts) {
      // popouts.openPopout("full-menu", {})
      // }
    }
  }
}
