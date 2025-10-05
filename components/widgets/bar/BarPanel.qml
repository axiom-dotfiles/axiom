// BarPanel.qml
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.config
import qs.components.widgets.bar.modules as Widgets
import qs.components.widgets.bar
import qs.components.widgets.bar.popouts
import qs.components.reusable

// TODO: Make this a proper singleton service that manages multiple bars
// as of right now (and probably awhile) this is totally fine, not high priority
PanelWindow {
  id: root

  required property var barConfig

  screen: Quickshell.screens.find(s => s.name === barConfig.display) || null
  WlrLayershell.layer: WlrLayer.Top
  // TODO: fix
  // currently always reduces exclusive zone to make room for borders, but needs to not
  // if borders are disabled
  WlrLayershell.exclusiveZone: barConfig.autoHide ? 0 : barConfig.extent - Appearance.screenMargin + Appearance.borderWidth
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

  Component.onCompleted: {
    console.log("========== BAR PANEL ==========");
    console.log("  > Screen:", barConfig.display, "->", screen ? "Found" : "Not Found");
    console.log("  > Panel width:", width, "height:", height);
    console.log("  > Visible:", visible);
    console.log("  > implicitWidth:", implicitWidth, "implicitHeight:", implicitHeight);
    console.log("================================");
  }

  // --- Dynamic Widget Logic ---

  // This will change. The widget definition should just be a string of the component
  // this is way over complicated for loading
  // Maybe I should keep it though, as it allows for more complex mappings for
  // for configuring widgets, and it is already setup
  // TODO: decide
  readonly property var widgetComponentMap: {
    "Logo": "modules/Logo.qml",
    "Window": "modules/Window.qml",
    "Media": "modules/Media.qml",
    "Workspaces": "modules/Workspaces.qml",
    "Time": "modules/Time.qml",
    "Tailscale": "modules/Tailscale.qml",
    "Network": "modules/Network.qml",
    "SystemTray": "modules/SystemTray.qml",
    "Battery": "modules/Battery.qml",
    "Notifications": "modules/Notifications.qml"
  }

  // A factory function to build a model array for the WidgetGroup's Repeater
  // Will change slightly when the map above changes
  function buildWidgetModel(widgetConfigArray) {
    if (!widgetConfigArray || widgetConfigArray.length === 0) {
      return [];
    }

    const array = widgetConfigArray.filter(
      widgetConf => widgetConf.visible !== false).map(widgetConf => {
      const componentType = widgetComponentMap[widgetConf.type];
      if (!componentType) {
        console.warn("Unknown widget type in bar config:", widgetConf.type);
        return null;
      }

      return {
        component: componentType
        ,
        properties: widgetConf.properties || {}
      };
    }).filter(item => item !== null);
    return array;
  }

  // --- UI Implementation ---

  // TODO: support popouts in all widget groups
  Popouts {
    id: popouts
    barConfig: root.barConfig
    panel: root
    screen: root.screen
  }

  // The main bar container gets populated by the json config
  BarContainer {
    anchors.fill: parent
    screen: root.screen
    popouts: popouts
    barConfig: root.barConfig

    workspaces: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.buildWidgetModel(root.barConfig.widgets?.center)
        popouts: popouts
        panel: root
        screen: root.screen
      }
    }

    leftGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.left && root.barConfig.widgets.left.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.left) : []
        popouts: popouts
        panel: root
        screen: root.screen
      }
    }

    leftCenterGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.leftCenter && root.barConfig.widgets.leftCenter.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.leftCenter) : []
        popouts: popouts
        panel: root
        screen: root.screen
      }
    }

    rightCenterGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.rightCenter && root.barConfig.widgets.rightCenter.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.rightCenter) : []
        popouts: popouts
        panel: root
        screen: root.screen
      }
    }

    rightGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.right && root.barConfig.widgets.right.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.right) : []
        popouts: popouts
        panel: root
        screen: root.screen
      }
    }
  }
}
