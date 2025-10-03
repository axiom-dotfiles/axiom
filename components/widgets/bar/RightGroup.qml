pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config
import qs.components.widgets.bar.modules as Widgets

WidgetGroup {
  id: root

  property var screen
  property bool showTray: true
  property bool showBattery: false

  model: {
    let widgets = [];

    widgets.push({
      component: tailscaleComponent
    });
    widgets.push({
      component: networkComponent
    });

    if (showTray) {
      widgets.push({
        component: trayComponent,
        properties: {
          orientation: Bar.vertical ? Qt.Vertical : Qt.Horizontal
        }
      });
    }

    if (showBattery) {
      widgets.push({
        component: batteryComponent
      });
    }

    widgets.push({
      component: notificationsComponent
    });
    widgets.push({
      component: logoComponent
    });

    return widgets;
  }

  Component {
    id: tailscaleComponent
    Widgets.Tailscale {}
  }
  Component {
    id: networkComponent
    Widgets.Network {}
  }
  Component {
    id: trayComponent
    Widgets.SystemTray {
      property int orientation: Qt.Horizontal
    }
  }
  Component {
    id: batteryComponent
    Widgets.Battery {}
  }
  Component {
    id: notificationsComponent
    Widgets.Notifications {}
  }
  Component {
    id: logoComponent
    Widgets.Logo {}
  }
}
