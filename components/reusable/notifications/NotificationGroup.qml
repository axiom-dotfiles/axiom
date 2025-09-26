// qs/components/reusable/notifications/NotificationGroup.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

import qs.config
import qs.services
import qs.components.reusable
import qs.components.reusable.notifications as Comp

StyledContainer {
  id: root

  required property var groupData

  readonly property var notifications: groupData?.notifications ?? []
  readonly property int notificationCount: notifications.length
  readonly property bool multipleNotifications: notificationCount > 1

  property bool expanded: false
  property real dragConfirmThreshold: 70
  property real xOffset: 0

  implicitWidth: 350
  implicitHeight: mainColumn.implicitHeight + (2 * Widget.padding)

  radius: Appearance.borderRadius
  color: Theme.backgroundAlt
  clip: true
  anchors.leftMargin: root.xOffset

  function destroyWithAnimation() {
    anchors.leftMargin = anchors.leftMargin;
    destroyAnimation.start();
  }

  SequentialAnimation {
    id: destroyAnimation
    NumberAnimation {
      target: root
      property: "anchors.leftMargin"
      to: root.width + 20
      duration: Widget.animationDuration
      easing.type: Easing.InQuad
    }
    ScriptAction {
      script: {
        root.notifications.forEach(notif => notif.dismiss());
      }
    }
  }

  function toggleExpanded() {
    if (multipleNotifications) {
      root.expanded = !root.expanded;
    }
  }

  // RowLayout {
  //   id: mainColumn
  //   anchors.fill: parent
  //   spacing: 0

  // Comp.NotificationIcon {
  //   Layout.alignment: Qt.AlignTop
  //   appIcon: groupData?.appIcon // <-- Changed
  //   summary: groupData?.notifications[root.notificationCount - 1]?.summary // <-- Changed
  //   image: root.multipleNotifications ? "" : groupData?.notifications[0]?.image ?? "" // <-- Changed
  // }
  //
  // Rectangle {
  //   Layout.fillWidth: true
  //   Layout.preferredHeight: 10
  //   color: Theme.accent
  // }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    spacing: 0

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 10
      color: Theme.accent
    }

    RowLayout {
      Layout.fillWidth: true

      // Rectangle {
      //   Layout.fillWidth: true
      //   Layout.preferredHeight: 10
      //   color: Theme.error
      // }

      Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        elide: Text.ElideRight
        text: (root.multipleNotifications ? root.groupData?.appName : root.groupData?.notifications[0]?.summary) || "" // <-- Changed
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
        color: Theme.foreground
      }

      Text {
        text: new Date(root.groupData?.time).toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit'
        })
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize - 4
        color: Theme.foregroundAlt
      }

      Comp.NotificationExpandButton {
        count: root.notificationCount
        expanded: root.expanded
        visible: root.multipleNotifications
        onClicked: root.toggleExpanded()
        onAltAction: root.toggleExpanded()
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing
      Repeater {
        model: root.expanded ? root.notifications.slice().reverse() : root.notifications.slice().reverse().slice(0, 2)
        delegate: Comp.NotificationItem {
          required property var modelData
          required property int index  // ADD THIS LINE
          Layout.fillWidth: true

          notificationObject: modelData
          expanded: root.expanded || !root.multipleNotifications  // REMOVED DUPLICATE LINE
          onlyNotification: !root.multipleNotifications
          // opacity: (!root.expanded && index === 1 && root.notificationCount > 2) ? 0.5 : 1
          visible: root.expanded || (index < 2)
          // expanded: true
          // visible: true

          Component.onCompleted: {
            console.log("NotificationItem created for notification:", notificationObject.summary);
          }
        }
      }
    }
    // }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    property point pressPoint  // ADD THIS LINE - was missing
    drag.axis: Drag.XAxis
    // drag.enabled: !expanded

    onPressed: mouse => {  // ADD THIS HANDLER
      pressPoint = Qt.point(mouse.x, mouse.y);
    }

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        root.toggleExpanded();
      } else if (mouse.button === Qt.MiddleButton) {
        root.destroyWithAnimation();
      } else if (!expanded) {
        root.toggleExpanded();
      }
    }

    onPositionChanged: mouse => {
      if (drag.active) {
        root.xOffset = Math.max(0, mouse.x - pressPoint.x);
      }
    }

    onReleased: () => {
      if (root.xOffset > root.dragConfirmThreshold) {
        root.destroyWithAnimation();
      } else {
        root.xOffset = 0;
      }
    }
  }
}
