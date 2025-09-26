// qs/components/reusable/notifications/NotificationWrapper.qml
import QtQuick
import Quickshell.Services.Notifications

QtObject {
  property string appName
  property string appIcon
  property string summary
  property string body
  property var actions
  property string image
  property real time
  property var urgency
  property int notificationId

  property Notification originalNotification
}
