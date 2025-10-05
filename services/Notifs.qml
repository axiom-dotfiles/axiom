/*
 * Notifs.qml
 *
 * This singleton provides a centralized service for managing and tracking desktop notifications.
 */
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  id: root

  readonly property alias notifications: server.trackedNotifications

  readonly property int count: notifications.values.length

  /**
     * A "Do Not Disturb" flag. When true, new notification popups will be suppressed,
     * except for those marked with 'Critical' urgency. Notifications will still be
     * added to the `notifications` list.
     */
  property bool dnd: false

  /**
     * This signal is emitted when a new notification is received that should be
     * displayed as a popup. The UI layer should connect to this signal.
     */
  signal showPopup(variant notification)

  /**
     * Dismisses all currently tracked notifications.
     */
  function clearAll() {
    // Iterate backwards when removing items from a model to avoid index shifting issues.
    for (var i = notifications.values.length - 1; i >= 0; i--) {
      const notif = notifications.values.find(i);
      if (notif) {
        notif.dismiss();
      }
    }
  }

  function sendNotification(appName, summary, body, options) {
    options = options || {};
    const notif = server.createNotification(appName, summary, body, options);
    notif.tracked = true; // Automatically track this notification
    if (!root.dnd || notif.urgency === NotificationUrgency.Critical) {
      root.showPopup(notif);
    }
    return notif;
  }

  // MARK: - Internal Implementation

  /**
     * The core NotificationServer that listens for DBus notifications.
     */
  NotificationServer {
    id: server

    // Set all capabilities to true to be a fully-featured server
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyHyperlinksSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    persistenceSupported: true
    // Optional, set to false if you don't want the server to outlive a QML reload
    keepOnReload: false 

    Component.onCompleted: {
      // This log is the most important for debugging.
      // It should now print "true".
      console.log("========== Notification Server ==========");
      console.log("  > Registered:", server.registered);
      console.log("  > Capabilities:");
      console.log("    - Actions:", server.actionsSupported);
      console.log("    - Action Icons:", server.actionIconsSupported);
      console.log("    - Body:", server.bodySupported);
      console.log("    - Body Hyperlinks:", server.bodyHyperlinksSupported);
      console.log("    - Body Markup:", server.bodyMarkupSupported);
      console.log("    - Image:", server.imageSupported);
      console.log("    - Persistence:", server.persistenceSupported);
      console.log("  > Tracked Notifications:", server.trackedNotifications.values.length);
      console.log("=========================================");
    }

    /**
     * This signal handler is the entry point for all new notifications.
     */
    onNotification: notification => {
      // The 'tracked' property adds the notification to the `trackedNotifications` model.
      // We don't track 'transient' notifications (e.g., volume changes).
      if (!notification.transient) {
        notification.tracked = true;
      }

      // Suppress popups if Do Not Disturb is on, unless the notification is critical.
      if (!root.dnd || notification.urgency === NotificationUrgency.Critical) {
        root.showPopup(notification);
      }

      // You can connect to the closed signal if you need to know when a
      // notification is dismissed by the client or times out.
      notification.closed.connect(reason => {
          // console.log("Notification", notification.id, "closed:", reason)
      });
    }
  }
}
