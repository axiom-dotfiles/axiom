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
    id: root
    edge: EdgePopup.Edge.Right
    panelId: "mainMenu"
    position: 0.5
    enableTrigger: true
    // customHeight: Display.resolutionHeight - Widget.containerWidth * 2
    triggerLength: Display.resolutionHeight
    edgeMargin: Config.containerOffset + Appearance.borderWidth * 2 + 3
    // edgeMargin: Config.containerOffset - (Appearance.borderWidth * 2) - 5
    // customHeight: Display.resolutionHeight - (Widget.containerWidth * 2) + (Appearance.borderWidth * 2)

    Component.onCompleted: {
      if (panelId !== "") {
        ShellManager.togglePanelLocation.connect(function(id) {
          console.log("Received togglePanelLocation for id:", id, "Current panelId:", panelId);
          if (id === panelId) {
            root.toggleLocation();
          }
        });
      }

    }

    MainMenu {
      id: mainMenu
      panelId: "mainMenu"
      // customHeight: Display.resolutionHeight - Widget.containerWidth * 2 + (Appearance.borderWidth * 2)
    }

    function toggleLocation() {
      if (root.reserveSpace) {
        root.edgeMargin = Config.containerOffset - (Appearance.borderWidth * 2) - 5 // Minor spaghetti
        mainMenu.customHeight = Display.resolutionHeight - Widget.containerWidth * 2
      } else {
        root.edgeMargin = Config.containerOffset + Appearance.borderWidth * 2 + 3
        mainMenu.customHeight = 0
      }
    }
  }
}
