pragma ComponentBehavior: Bound

import QtQuick

import qs.components.widgets.popouts
import qs.components.reusable
import qs.components.widgets.menu
import qs.config
import qs.services

Item {
  anchors.fill: parent

  EdgePopup {
    edge: EdgePopup.Edge.Right
    panelId: "mainMenu"
    position: 0.5
    enableTrigger: true
    // customHeight: Display.resolutionHeight - Widget.containerWidth * 2
    triggerLength: Display.resolutionHeight
    edgeMargin: Widget.containerWidth - Appearance.borderWidth // trigger Width TODO: change
    // customHeight: Display.resolutionHeight - (Widget.containerWidth * 2) + (Appearance.borderWidth * 2)

    PowerPanel {
      id: powerPanel
      panelId: "mainMenu"
      // customHeight: Display.resolutionHeight - Widget.containerWidth * 2 + (Appearance.borderWidth * 2)
    }
  }
}
