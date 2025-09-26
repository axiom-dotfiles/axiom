// File: @modules/NotificationPopup.qml (or your preferred location)
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.services

import qs.components.reusable.notifications as NotificationComponents
import qs.config

Scope {
  id: rootScope

  ListModel {
    id: popupModel
  }

  Connections {
    target: Notifs

    function onShowPopup(notification) {
      console.log("Popup: Received new notification to show:", notification.summary);
      popupModel.insert(0, { "notificationObject": notification });
    }
  }

  PanelWindow {
    id: rootWindow
    visible: popupModel.count > 0
    screen: Quickshell.screens.find(s => s.active) ?? (Quickshell.screens.count > 0 ? Quickshell.screens.get(0) : null)

    // WlrLayershell.namespace: "quickshell:notificationPopup"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: 0

    anchors {
      top: true
      left: true
    }

    margins {
      top: Widget.spacing * 2
      left: Widget.spacing * 2
    }

    aboveWindows: true

    // implicitWidth: Appearance.sizes.notificationPopupWidth ?? 350
    // implicitHeight: listView.contentHeight + (rootWindow.anchors.topMargin * 2)
    implicitWidth: 350
    implicitHeight: 200
    color: "transparent"

    ListView {
      id: listView
      anchors.fill: parent
      anchors.margins: Widget.spacing

      model: popupModel
      spacing: Widget.spacing

      delegate: NotificationComponents.NotificationItem {
        required property var modelData
        readonly property int index: index
        width: listView.width
        notificationObject: modelData
        expanded: true
        // onlyNotification: popupModel.count === 1
        
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: 10
          color: Theme.foregroundAlt
          opacity: 0.1
          visible: index < popupModel.count - 1
        }

        Component.onCompleted: {
          notificationObject.closed.connect(function() {
            console.log("Popup: Closing notification:", notificationObject.summary);
            for (var i = 0; i < popupModel.count; i++) {
              if (popupModel.get(i).notificationObject.id === notificationObject.id) {
                popupModel.remove(i);
                break;
              }
            }
          })
        }
      }
    }
  }
}
