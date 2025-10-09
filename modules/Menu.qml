pragma ComponentBehavior: Bound

import QtQuick

import qs.components.widgets.popouts
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
    triggerLength: Display.resolutionHeight
    edgeMargin: Config.containerOffset + Appearance.borderWidth * 2
    wantsKeyboardFocus: mainMenu.wantsKeyboardFocus

    Component.onCompleted: {
      if (panelId !== "") {
        ShellManager.togglePanelLocation.connect(function (id) {
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
    }

    function toggleLocation() {
      if (root.reserveSpace) {
        root.edgeMargin = Config.containerOffset - (Appearance.borderWidth * 2) - 5;
        mainMenu.customHeight = Display.resolutionHeight - Appearance.containerWidth * 2;
      } else {
        root.edgeMargin = Config.containerOffset + Appearance.borderWidth * 2 + 3;
        mainMenu.customHeight = 0;
      }
    }
  }
}
