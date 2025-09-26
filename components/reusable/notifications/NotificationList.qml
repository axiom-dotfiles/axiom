// qs/components/reusable/notifications/NotificationList.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services

import qs.components.reusable.notifications

ListView {
  id: root
  property bool popup: false
  property var _groupedNotifications: []

  implicitHeight: contentHeight
  spacing: Widget.spacing
  clip: true

  model: ScriptModel {
    values: root._groupedNotifications
  }
  delegate: NotificationGroup {
    required property var modelData
    width: root.width
    // modelData: modelData
    groupData: modelData
  }

  Connections {
    target: Notifs.notifications
    function onModelChanged() {
      root.updateModel();
    }
    function onRowsInserted() {
      root.updateModel();
    }
    function onRowsRemoved() {
      root.updateModel();
    }
  }

  Component.onCompleted: {
    updateModel();
  }

  function updateModel() {
    const groups = {};
    const notificationsArray = Notifs.notifications.values;

    for (const notif of notificationsArray) {
      const appName = notif.appName || "System";

      if (!groups[appName]) {
        groups[appName] = {
          appName: appName,
          summary: notif.summary,
          body: notif.body,
          appIcon: notif.appIcon,
          actions: notif.actions,
          image: notif.image,
          notifications: [],
          time: 0
        };
      }

      groups[appName].notifications.push(notif);
      if (notif.time > groups[appName].time) {
        groups[appName].time = notif.time;
      }
    }

    let result = Object.values(groups);
    result.sort((a, b) => b.time - a.time);

    root._groupedNotifications = result;
  }
}
