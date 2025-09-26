pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
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
  implicitHeight: mainColumn.implicitHeight

  radius: Appearance.borderRadius
  color: Theme.backgroundAlt
  clip: true

  transform: Translate {
    x: root.xOffset
  }

  Behavior on xOffset {
    enabled: !mouseArea.drag.active && Widget.animations
    NumberAnimation {
      duration: Widget.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  function destroyWithNumberAnimation() {
    dismissNumberAnimation.start();
  }

  NumberAnimation {
    id: dismissNumberAnimation
    target: root
    property: "xOffset"
    to: root.width + 20
    duration: Widget.animationDuration
    easing.type: Easing.InQuad
    onFinished: {
      root.notifications.forEach(notif => notif.dismiss());
    }
  }

  function toggleExpanded() {
    if (multipleNotifications) {
      root.expanded = !root.expanded;
    }
  }

  // FIX: MouseArea moved to be the FIRST child.
  // In QML, items declared later are drawn on top. By putting this first,
  // all other UI controls (like the expand button) are drawn on top of it,
  // ensuring they receive mouse clicks first.
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    property point pressPoint

    drag.axis: Drag.XAxis
    drag.filterChildren: true // Allow children to handle clicks

    onPressed: mouse => {
      pressPoint = Qt.point(mouse.x, mouse.y);
    }

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        root.toggleExpanded();
      } else if (mouse.button === Qt.MiddleButton) {
        destroyWithNumberAnimation();
      } else if (multipleNotifications) {
        // Only toggle on left click if there are multiple notifications
        root.toggleExpanded();
      }
    }

    onPositionChanged: mouse => {
      if (drag.active) {
        root.xOffset = mouse.x - pressPoint.x;
      }
    }

    onReleased: () => {
      if (root.xOffset > root.dragConfirmThreshold) {
        destroyWithNumberAnimation();
      } else {
        root.xOffset = 0; // Animate back
      }
    }
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    spacing: 0

    // A more subtle accent bar
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 3
      Layout.bottomMargin: Widget.spacing
      color: Theme.accent
      radius: 1.5
    }

    // Header Section
    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      Comp.NotificationIcon {
        Layout.alignment: Qt.AlignTop
        appIcon: groupData?.appIcon
        summary: groupData?.notifications[root.notificationCount - 1]?.summary
        image: root.multipleNotifications ? "" : groupData?.notifications[0]?.image ?? ""
        baseSize: 32
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: root.groupData?.appName || ""
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize + 1
          font.weight: Font.Bold
          color: Theme.foreground
        }
        Text {
          text: new Date(root.groupData?.time).toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
          })
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 3
          color: Theme.foregroundAlt
        }
      }

      Comp.NotificationActionButton {
        buttonText: "Close All"
        onClicked: root.destroyWithNumberAnimation()
      }

      Comp.NotificationActionButton {
        visible: root.multipleNotifications
        buttonText: root.expanded ? "Collapse" : "Expand"
        onClicked: root.toggleExpanded()
      }

      // Comp.NotificationExpandButton {
      //   count: root.notificationCount
      //   expanded: root.expanded
      //   visible: root.multipleNotifications
      //   onClicked: root.toggleExpanded()
      //   onAltAction: root.toggleExpanded()
      // }
    }

    // Notifications List Section
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: root.multipleNotifications ? Widget.spacing : 0

      Layout.leftMargin: Widget.padding * 1.5
      Layout.rightMargin: Widget.padding * 1.5

      spacing: Widget.spacing / 2 // Spacing between individual notifications

      Behavior on Layout.leftMargin {
        enabled: Widget.animations
        NumberAnimation {}
      }
      Behavior on Layout.rightMargin {
        enabled: Widget.animations
        NumberAnimation {}
      }

      Repeater {
        model: {
          if (notificationCount === 0) {
            return [];
          }
          return root.notifications.slice().reverse();
        }
        delegate: Comp.NotificationItem {
          required property var modelData
          Layout.fillWidth: true
          notificationObject: modelData
          // When part of a group, the item is "expanded" if the group is.
          // If it's the only notification, it should always appear expanded.
          expanded: root.expanded || !root.multipleNotifications
          onlyNotification: !root.multipleNotifications
        }
      }
    }
  }
}
