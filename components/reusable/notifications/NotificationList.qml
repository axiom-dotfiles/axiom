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

  Component {
    id: wrapperComponent
    NotificationWrapper {}
  }

  // This will hold our JS array of grouped notification objects.
  property var groupedNotifications: []

  implicitHeight: contentHeight
  spacing: Widget.spacing
  clip: true

  // The model is our generated array of groups.
  // model: ScriptModel {
  //   values: root.groupedNotifications
  // }

  model: root.groupedNotifications
  delegate: NotificationGroup {
    // modelData is now a group object: { appName, appIcon, notifications: [...] }
    required property var modelData
    width: root.width
    groupData: modelData
  }

  // --- REFACTORED: Listen directly to the C++ model for changes ---
  Connections {
    target: Notifs.notifications // The C++ QAbstractListModel
    function onRowsInserted()    { root.rebuildGroups() }
    function onRowsRemoved()     { root.rebuildGroups() }
    function onModelReset()      { root.rebuildGroups() } // Important for full clears
  }

  Component.onCompleted: {
    rebuildGroups() // Initial population
  }

  // --- REFACTORED: Simplified grouping function ---
  // This function now reads from the live C++ model and builds the JS structure for the view.
  function rebuildGroups() {
    const groups = {};
    const notificationsModel = Notifs.notifications;

    for (const notif of notificationsModel.values) {
      // 'notif' is now the live C++ Notification object.
      const appName = notif.appName || "System";

      if (!groups[appName]) {
        groups[appName] = {
          appName: appName,
          appIcon: notif.appIcon,
          notifications: [], // This array will hold the LIVE C++ notification objects
          time: 0
        };
      }
      console.log("notif namee: ", notif.appName);

      const wrapper = wrapperComponent.createObject(root, {
        // Copy all the data the UI needs into the wrapper's safe properties
        appName: notif.appName,
        appIcon: notif.appIcon,
        summary: notif.summary,
        body: notif.body,
        actions: notif.actions,
        image: notif.image,
        time: Date.now() / 1000,
        urgency: notif.urgency,
        notificationId: notif.id,
        // Keep a reference to the original C++ object
        originalNotification: notif
      });


      // Push the SAFE WRAPPER object, not the raw C++ object
      groups[appName].notifications.push(wrapper);

      // Keep track of the latest time for sorting the groups.
      if (notif.time > groups[appName].time) {
        groups[appName].time = notif.time;
      }
    }

    let result = Object.values(groups);
    result.sort((a, b) => b.time - a.time);

    root.groupedNotifications = result;
  }
}
