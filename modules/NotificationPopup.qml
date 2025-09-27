// File: @modules/NotificationPopup.qml (or your preferred location)
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.services

import qs.components.widgets.notifications as NotificationComponents
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
    implicitHeight: 1400 // TODO FIX
    color: "transparent"

    ListView {
      id: listView
      anchors.fill: parent
      anchors.margins: Widget.spacing

      model: popupModel
      spacing: Widget.spacing

      delegate: NotificationComponents.NotificationItem {
        id: notif
        required property var modelData
        readonly property int index: index
        backgroundColor: Theme.background
        foregroundColor: Theme.foreground
        width: listView.width
        notificationObject: modelData
        expanded: true
        // onlyNotification: popupModel.count === 1
        
        // Rectangle {
        //   anchors.bottom: parent.bottom
        //   anchors.left: parent.left
        //   anchors.right: parent.right
        //   height: 10
        //   color: Theme.backgroundAlt
        //   visible: index < popupModel.count - 1
        // }

        Timer {
          interval: (notif.modelData.timeout > 0 ? notif.modelData.timeout : 5000)
          running: true
          repeat: false
          onTriggered: {
            notif.notificationObject.close();
          }
        }



        Component.onCompleted: {
          notificationObject.closed.connect(function() {
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
