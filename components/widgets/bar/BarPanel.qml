pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.components.widgets.bar.declarations as Widgets
import qs.components.widgets.popouts
import qs.components.reusable

PanelWindow {
  id: root

  required property var modelData
  property string display: Display.primary
  property int barHeight: Bar.height
  property int barWidth: Bar.vertical ? Bar.height : 0

  screen: modelData
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.exclusiveZone: Bar.vertical ? barWidth : barHeight
  WlrLayershell.namespace: "qs-bar"

  anchors {
    top: Bar.vertical ? true : (modelData.name === display)
    bottom: Bar.vertical ? true : (modelData.name === "DP-2")
    left: Bar.vertical ? !Bar.rightSide : true
    right: Bar.vertical ? Bar.rightSide : true
  }

  visible: if (modelData.name === display)
    true
  else if (modelData.name === "DP-2" && !Config.singleMonitor)
    true
  else
    false

  implicitHeight: Bar.vertical ? 0 : barHeight
  implicitWidth: Bar.vertical ? barWidth : 0

  PopoutWrapper {
    id: popouts
    screen: root.screen
  }

  BarContainer {
    anchors.fill: parent
    screen: root.screen
    popouts: popouts

    workspaces: Component {
      Widgets.Workspaces {
        screen: root.screen
        popouts: popouts
        orientation: Bar.vertical ? Qt.Vertical : Qt.Horizontal
        panel: root
      }
    }

    leftGroup: Component {
      LeftGroup {
        screen: root.screen
        showMedia: true
      }
    }

    rightGroup: Component {
      RightGroup {
        screen: root.screen
        showTray: root.screen.name === Display.primary
        showBattery: Display.primary === "eDP-1"
      }
    }

    leftCenterGroup: centerGroups.leftCenterGroup

    rightCenterGroup: Component {
      Loader {
        sourceComponent: centerGroups.rightCenterGroup
        onLoaded: {
          if (item) {
            item.showSystemMonitor = root.screen.name === "DP-1";
          }
        }
      }
    }
  }

  CenterGroup {
    id: centerGroups
  }
}
