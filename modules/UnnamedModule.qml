pragma ComponentBehavior: Bound

import QtQuick

import qs.components.widgets.popouts
import qs.components.widgets.reusable
import qs.components.widgets.menu
import qs.config
import qs.services

Item {
  anchors.fill: parent

  EdgePopup {
    edge: EdgePopup.Edge.Right
    position: 0.5
    enableTrigger: true
    useImplicitSize: true
    triggerLength: 1500
    edgeMargin: 10

    PowerPanel {
      id: powerPanel
    }

  }
}
