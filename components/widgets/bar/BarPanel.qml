pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.components.widgets.bar.modules as Widgets
import qs.components.widgets.popouts
import qs.components.reusable

PanelWindow {
  id: root

  required property var modelData
  required property QtObject barConfig
  property string display: Display.primary

  screen: modelData
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.exclusiveZone: barConfig.autoHide ? 0 : barConfig.extent
  WlrLayershell.namespace: "axiom-bar"

  anchors {
    top: (barConfig.top || barConfig.vertical)
    bottom: (barConfig.bottom || barConfig.vertical)
    left: (barConfig.left || !barConfig.vertical)
    right: (barConfig.right || !barConfig.vertical)
  }

  visible: barConfig.enabled

  implicitHeight: barConfig.vertical ? 0 : barConfig.extent
  implicitWidth: barConfig.vertical ? barConfig.extent : 0

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
        orientation: barConfig.vertical ? Qt.Vertical : Qt.Horizontal
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
