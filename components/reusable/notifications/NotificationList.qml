// qs/components/reusable/notifications/NotificationList.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services

import qs.components.reusable.notifications

// TODO: bit of a refactor
// I don't think it is terrible, but got a bit spaghetti
// on my first go at it
// ALso animations could be better
ListView {
  id: root
  property bool popup: false

  property var groupedNotifications: []

  implicitHeight: contentHeight
  spacing: Widget.spacing
  clip: true

  // IDK when tf these are needed vs not needed
  // model: ScriptModel {
  //   values: root.groupedNotifications
  // }

  model: root.groupedNotifications
  delegate: NotificationGroup {
    required property var modelData
    width: root.width
    groupData: modelData
  }

  Connections {
    target: Notifs.notifications
    function onRowsInserted()    { root.rebuildGroups() }
    function onRowsRemoved()     { root.rebuildGroups() }
    function onModelReset()      { root.rebuildGroups() }
  }

  Component.onCompleted: {
    rebuildGroups()
  }

  function rebuildGroups() {
    const groups = {};
    const notificationsModel = Notifs.notifications;

    for (const notif of notificationsModel.values) {
      const appName = notif.appName || "System";

      if (!groups[appName]) {
        groups[appName] = {
          appName: appName,
          appIcon: notif.appIcon,
          notifications: [],
          time: 0
        };
      }
      console.log("notif namee: ", notif.appName);

      groups[appName].notifications.push(notif);

      if (notif.time > groups[appName].time) {
        groups[appName].time = notif.time;
      }
    }

    let result = Object.values(groups);
    result.sort((a, b) => b.time - a.time);

    root.groupedNotifications = result;
  }
}
