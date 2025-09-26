pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.config
import qs.components.reusable
import qs.components.reusable.notifications as Comp

Item {
  id: root

  property var notificationObject
  property bool expanded: false
  property bool onlyNotification: false

  property real dragConfirmThreshold: 70
  property real xOffset: 0

  implicitHeight: mainLayout.implicitHeight
  implicitWidth: parent.width

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
    onFinished: root.notificationObject.dismiss()
  }

  // FIX: MouseArea moved to be the FIRST child.
  // This places it "behind" the content, allowing the action buttons
  // to receive clicks while still enabling drag-to-dismiss.
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    property point pressPoint

    drag.axis: Drag.XAxis
    drag.filterChildren: true

    onPressed: mouse => {
      pressPoint = Qt.point(mouse.x, mouse.y);
    }

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) {
        root.destroyWithNumberAnimation();
      }
    }

    onPositionChanged: mouse => {
      if (drag.active) {
        root.xOffset = mouse.x - pressPoint.x;
      }
    }

    onReleased: () => {
      if (root.xOffset > root.dragConfirmThreshold) {
        root.destroyWithNumberAnimation();
      } else {
        root.xOffset = 0; // Animate back
      }
    }
  }

  // CLEANUP: Using a RowLayout as the main container is cleaner and more
  // robust than managing multiple anchored items.
  RowLayout {
    id: mainLayout
    width: parent.width
    spacing: Widget.spacing
    transform: Translate {
      x: root.xOffset
    }
    Behavior on transform {
      enabled: !mouseArea.drag.active && Widget.animations
      NumberAnimation {
        duration: Widget.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    NotificationIcon {
      visible: root.onlyNotification && root.notificationObject.image
      image: root.notificationObject.image
      baseSize: Bar.height * 1.2
      Layout.alignment: Qt.AlignTop
    }

    StyledContainer {
      id: background
      Layout.fillWidth: true
      radius: Appearance.borderRadius
      clip: true

      color: Theme.backgroundHighlight
      implicitHeight: contentColumn.implicitHeight

      Behavior on color {
        enabled: Widget.animations
        NumberAnimation {}
      }

      ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: Widget.spacing

        RowLayout {
          Layout.fillWidth: true
          visible: true
          spacing: Widget.spacing

          Text {
            id: summaryText
            Layout.fillWidth: true
            topPadding: Widget.padding / 2
            bottomPadding: Widget.padding / 2
            horizontalAlignment: Text.AlignHCenter
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
            color: Theme.foreground
            text: root.notificationObject.summary || ""
          }
        }

        Text {
          id: notificationBodyText
          Layout.fillWidth: true
          visible: root.expanded
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 1
          topPadding: Widget.padding / 2
          leftPadding: Widget.padding
          color: Theme.foregroundAlt
          wrapMode: Text.Wrap
          textFormat: Text.RichText
          text: root.notificationObject.body.replace(/\n/g, "<br/>")
          onLinkActivated: link => Qt.openUrlExternally(link)
          Component.onCompleted: {
            console.log("Full notifi opbject:")
            console.log(root.notificationObject);
            console.log("Notification body text:", root.notificationObject.body);
            console.log("Summary text:", root.notificationObject.summary);
            console.log("App name:", root.notificationObject.appName);
            console.log("Urgency:", root.notificationObject.urgency);
            console.log("Actions:", root.notificationObject.actions);
            console.log("Timestamp:", root.notificationObject.time);
            console.log("Image:", root.notificationObject.image);

          }
        }

        Flickable {
          Layout.fillWidth: true
          implicitHeight: actionRowLayout.implicitHeight
          contentWidth: actionRowLayout.implicitWidth
          interactive: contentWidth > width
          flickableDirection: Flickable.HorizontalFlick
          clip: true
          visible: root.expanded && (copyButton.visible || repeater.count > 0)

          RowLayout {
            id: actionRowLayout
            spacing: Widget.spacing

            Repeater {
              model: root.notificationObject.actions
              delegate: Comp.NotificationActionButton {
                required property var modelData
                buttonText: modelData.text
                urgency: root.notificationObject.urgency
                onClicked: root.notificationObject.invokeAction(modelData.identifier)
              }
            }

            Comp.NotificationActionButton {
              id: copyButton
              visible: root.notificationObject.body.length > 0
              urgency: root.notificationObject.urgency
              onClicked: {
                Quickshell.clipboardText = root.notificationObject.summary + "\n" + root.notificationObject.body;
                copyIcon.text = "done";
                copyIconTimer.restart();
              }

              content: Text {
                id: copyIcon
                text: "content_copy"
                font.family: "Material Symbols Outlined"
                font.pixelSize: Appearance.fontSize
                color: copyButton.urgency === NotificationUrgency.Critical ? Theme.base00 : Theme.foreground
              }

              Timer {
                id: copyIconTimer
                interval: 1500
                onTriggered: copyIcon.text = "content_copy"
              }
            }
          }
        }
      }
    }
  }
}
