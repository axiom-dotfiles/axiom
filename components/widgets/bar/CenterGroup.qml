pragma ComponentBehavior: Bound

import QtQuick

import qs.components.widgets.bar.declarations
import qs.config

QtObject {
  property Component leftCenterGroup: WidgetGroup {
    model: [
      {
        component: timeComponent
      }
    ]

    Component {
      id: timeComponent
      Time {}
    }
  }

  property Component rightCenterGroup: WidgetGroup {
    property bool showSystemMonitor: false

    model: {
      let widgets = [];
      if (showSystemMonitor)
      // widgets.push({
      //   component: systemMonitorComponent
      // });
      {}
      return widgets;
    }

    // Component {
    //   id: systemMonitorComponent
    //   SystemMonitor {}
    // }
  }
}
