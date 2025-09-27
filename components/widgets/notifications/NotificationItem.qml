pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.config
import qs.components.reusable
import qs.components.widgets.notifications

Item {
  id: root

  property Notification notificationObject
  property bool expanded: false
  property bool onlyNotification: false

  property real dragConfirmThreshold: 70
  property real xOffset: 0

  property color backgroundColor: Theme.backgroundHighlight
  property color foregroundColor: Theme.foreground
  property color foregroundAltColor: Theme.foregroundAlt
  property color borderColor: Theme.border

  implicitHeight: mainLayout.implicitHeight

  Component.onCompleted: {
    if (!notificationObject) {
      console.error("NotificationItem requires a notificationObject property to be set.");
    }
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
    onFinished: root.notificationObject.dismiss()
  }

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

      color: backgroundColor
      border.color: borderColor
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
            color: foregroundColor
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
          color: foregroundAltColor
          wrapMode: Text.Wrap
          textFormat: Text.RichText
          text: root.notificationObject.body.replace(/\n/g, "<br/>")
          onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Flickable {
          Layout.fillWidth: true
          implicitHeight: actionRowLayout.implicitHeight
          contentWidth: actionRowLayout.implicitWidth
          interactive: contentWidth > width
          flickableDirection: Flickable.HorizontalFlick
          clip: true
          visible: root.expanded

          RowLayout {
            id: actionRowLayout
            spacing: Widget.spacing
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight

            Repeater {
              id: repeater
              model: root.notificationObject.actions
              Layout.alignment: Qt.AlignRight
              delegate: NotificationActionButton {
                required property var modelData
                buttonText: modelData.text
                urgency: root.notificationObject.urgency
                onClicked: root.notificationObject.invokeAction(modelData.identifier)
              }
            }

            // NotificationActionButton {
            //   id: copyButton
            //   visible: root.notificationObject.body ? true : false
            //   urgency: root.notificationObject.urgency
            //   onClicked: {
            //     Quickshell.clipboardText = root.notificationObject.summary + "\n" + root.notificationObject.body;
            //     copyIcon.text = "done";
            //     copyIconTimer.restart();
            //   }
            //
            //   content: Text {
            //     id: copyIcon
            //     text: "content_copy"
            //     font.family: "Material Symbols Outlined"
            //     font.pixelSize: Appearance.fontSize
            //     color: copyButton.urgency === NotificationUrgency.Critical ? Theme.base00 : Theme.foreground
            //   }
            //
            //   Timer {
            //     id: copyIconTimer
            //     interval: 1500
            //     onTriggered: copyIcon.text = "content_copy"
            //   }
            // }

            NotificationActionButton {
              buttonText: "X"
              Layout.alignment: Qt.AlignRight
              urgency: root.notificationObject.urgency
              onClicked: root.destroyWithNumberAnimation()
            }
          }
        }
      }
    }
  }
}
