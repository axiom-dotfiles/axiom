// StandaloneBar.qml - Standalone reusable bar component
pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components.widgets.bar
import qs.components.widgets.bar.popouts
import qs.components.reusable

Item {
  id: root

  required property var barConfig
  
  property var popouts: null
  property var panel: null
  property var screen: null
  
  property alias barContainer: container

  implicitWidth: barConfig.vertical ? barConfig.extent : 300
  implicitHeight: barConfig.vertical ? 300 : barConfig.extent

  // --- Dynamic Widget Logic ---
  function buildWidgetModel(widgetConfigArray) {
    if (!widgetConfigArray || widgetConfigArray.length === 0) {
      return [];
    }

    const array = widgetConfigArray.filter(
      widgetConf => widgetConf.visible !== false).map(widgetConf => {
      const componentType = "modules/" + widgetConf.type + ".qml";
      if (!componentType) {
        console.Error("Unknown widget type in bar config:", widgetConf.type);
        return null;
      }

      return {
        component: componentType,
        properties: widgetConf.properties || {}
      };
    }).filter(item => item !== null);
    return array;
  }

  BarContainer {
    id: container
    anchors.fill: parent
    screen: root.screen
    popouts: root.popouts
    barConfig: root.barConfig

    centerGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.buildWidgetModel(root.barConfig.widgets?.center)
        popouts: root.popouts
        panel: root.panel
        screen: root.screen
      }
    }

    leftGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.left && root.barConfig.widgets.left.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.left) : []
        popouts: root.popouts
        panel: root.panel
        screen: root.screen
      }
    }

    leftCenterGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.leftCenter && root.barConfig.widgets.leftCenter.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.leftCenter) : []
        popouts: root.popouts
        panel: root.panel
        screen: root.screen
      }
    }

    rightCenterGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.rightCenter && root.barConfig.widgets.rightCenter.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.rightCenter) : []
        popouts: root.popouts
        panel: root.panel
        screen: root.screen
      }
    }

    rightGroup: Component {
      WidgetGroup {
        barConfig: root.barConfig
        model: root.barConfig.widgets?.right && root.barConfig.widgets.right.length > 0 ? root.buildWidgetModel(root.barConfig.widgets?.right) : []
        popouts: root.popouts
        panel: root.panel
        screen: root.screen
      }
    }
  }
}
