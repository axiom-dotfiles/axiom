pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.parts.notifications

PopupWindow {
  id: root

  required property var notification
  // Its history entry's uid ("" for a transient one), taken while it's
  // live: invoking an action can close it
  property string uid: ""
  property var anchorWindow: null

  property int toastWidth: 360
  property int toastMaxHeight: 220
  property int dismissDuration: 5000
  property real dragDismissThreshold: 150
  // The corner it stacks from: the anchor window is a 1px point there, so
  // a right-hand toast ends at it and a bottom one stacks upwards from it
  property bool alignRight: false
  property bool fromBottom: false
  // Distance from the corner along the stack
  property int targetY: 0

  signal dismissed
  // The user closed it (not a timeout): the host hides it on every screen
  signal userClosed

  readonly property bool closing: slideOut.running

  implicitWidth: toastWidth
  implicitHeight: Math.min(mainColumn.implicitHeight + Widget.padding * 2, toastMaxHeight)

  visible: false
  color: "transparent"

  anchor.window: anchorWindow
  // Placed exactly: the compositor mustn't slide it back on screen
  anchor.adjustment: PopupAdjustment.None
  anchor.rect.x: alignRight ? 1 - implicitWidth : 0
  anchor.rect.y: fromBottom ? 1 - targetY - implicitHeight : targetY
  anchor.rect.width: implicitWidth
  anchor.rect.height: implicitHeight

  Component.onCompleted: {
    visible = true;
    slideIn.start();
  }

  // Reposition instantly (used for stack reflow); the visual "movement"
  // reads fine since it's accompanied by other toasts sliding at once.
  function updatePosition(newTargetY) {
    targetY = newTargetY;
  }

  // Only hides the toast — the notification stays tracked so it's still
  // visible/actionable from the bell popout afterwards.
  function dismiss() {
    if (slideOut.running)
      return;
    slideOut.start();
  }

  // Closed by the user; `remove` also takes it out of the history
  function close(remove) {
    if (slideOut.running)
      return;
    if (remove && root.uid)
      NotificationManager.dismiss(root.uid);
    root.userClosed();
    root.dismiss();
  }

  ParallelAnimation {
    id: slideIn
    NumberAnimation {
      target: card
      property: "y"
      from: root.fromBottom ? 16 : -16
      to: 0
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: card
      property: "opacity"
      from: 0
      to: 1
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
  }

  NumberAnimation {
    id: slideOut
    target: card
    property: "opacity"
    to: 0
    duration: Appearance.animFast
    easing.type: Easing.InQuad
    onFinished: {
      root.visible = false;
      root.dismissed();
    }
  }

  // A drag short of the threshold: slide back and undo the fade
  ParallelAnimation {
    id: snapBack
    NumberAnimation {
      target: dragShift
      property: "x"
      to: 0
      duration: Appearance.animFast
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: card
      property: "opacity"
      to: 1
      duration: Appearance.animFast
      easing.type: Easing.OutCubic
    }
  }

  // expireTimeout: 0 is the freedesktop-spec signal for "never expire", a
  // positive one is the app's own duration (ms), -1 leaves it to us
  readonly property bool critical: notification.urgency === NotificationUrgency.Critical
  readonly property bool neverExpires: (NotificationsConfig.appTimeouts && notification.expireTimeout === 0) || (NotificationsConfig.criticalStays && critical)
  readonly property int duration: NotificationsConfig.appTimeouts && notification.expireTimeout > 0 ? notification.expireTimeout : root.dismissDuration

  Timer {
    id: dismissTimer
    interval: root.duration
    running: !root.neverExpires && root.visible && !dragArea.containsMouse
    onTriggered: root.dismiss()
  }

  Item {
    id: card
    anchors.fill: parent
    opacity: 0
    // Anchored, so the drag moves it with a transform rather than x
    transform: Translate {
      id: dragShift
    }

    StyledContainer {
      id: content
      anchors.fill: parent
      backgroundColor: Theme.background
      borderColor: root.critical ? Theme.error : Theme.backgroundAlt
      borderWidth: Appearance.borderWidth
      borderRadius: Appearance.borderRadius + 2
      clip: true

      // Critical urgency
      Rectangle {
        visible: root.critical
        x: 4
        width: 3
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Widget.padding
        radius: 1.5
        color: Theme.error
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true

        property real pressX: 0
        property real dragDelta: 0

        // In scene coordinates: local ones move with the card being dragged
        function sceneX(mouse) {
          return dragArea.mapToItem(null, mouse.x, mouse.y).x;
        }

        onPressed: mouse => {
          snapBack.stop();
          pressX = sceneX(mouse);
          dragDelta = 0;
        }

        onPositionChanged: mouse => {
          if (!pressed)
            return;
          dragDelta = sceneX(mouse) - pressX;
          dragShift.x = dragDelta * 0.5;
          card.opacity = 1 - Math.abs(dragDelta) / (root.dragDismissThreshold * 2);
          if (Math.abs(dragDelta) > root.dragDismissThreshold)
            root.close(NotificationsConfig.closeRemoves);
        }

        onReleased: {
          if (Math.abs(dragDelta) < root.dragDismissThreshold)
            snapBack.start();
        }

        ColumnLayout {
          id: mainColumn
          anchors.fill: parent
          anchors.margins: Widget.padding
          spacing: Widget.spacing / 2

          RowLayout {
            Layout.fillWidth: true
            spacing: Widget.spacing

            NotificationAvatar {
              Layout.alignment: Qt.AlignTop
              appIcon: root.notification.appIcon ?? ""
              desktopEntry: root.notification.desktopEntry ?? ""
              image: root.notification.image ?? ""
              size: 40
              badge: true
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              StyledText {
                Layout.fillWidth: true
                text: root.notification.appName || ""
                textColor: Theme.foregroundAlt
                textSize: Appearance.fontSize - 2
                font.bold: true
                elide: Text.ElideRight
              }

              NotificationText {
                notification: root.notification
                summaryLines: 2
                bodyLines: 3
                // Without a default action, a click opens its app (as in
                // the history)
                clickable: !!defaultAction || (root.notification.desktopEntry ?? "") !== ""
                onActivated: ranAction => {
                  if (!ranAction)
                    NotificationManager.openApp(root.notification);
                  root.close(NotificationsConfig.removeOnClick);
                }
              }
            }

            StyledIconButton {
              Layout.fillWidth: false
              Layout.fillHeight: false
              Layout.preferredWidth: 22
              Layout.preferredHeight: 22
              Layout.alignment: Qt.AlignTop

              iconText: "close"
              iconSize: 12
              borderRadius: 11
              iconColor: Theme.foregroundAlt
              hoverColor: Theme.backgroundHighlight

              onClicked: root.close(NotificationsConfig.closeRemoves)
            }
          }

          NotificationActions {
            notification: root.notification
            onInvoked: root.close(NotificationsConfig.removeOnClick)
          }
        }
      }
    }
  }
}
