// qs/components/reusable/notifications/NotificationItem.qml
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

  implicitHeight: background.implicitHeight

  function destroyWithAnimation() {
    background.anchors.leftMargin = background.anchors.leftMargin; // Break binding
    destroyAnimation.start();
  }

  SequentialAnimation {
    id: destroyAnimation
    NumberAnimation {
      target: background
      property: "anchors.leftMargin"
      to: root.width + 20
      duration: Widget.animationDuration
      easing.type: Easing.InQuad
    }
    ScriptAction {
      script: notificationObject.dismiss()
    }
  }

  NotificationIcon {
    id: notificationIcon
    visible: opacity > 0
    opacity: (!root.onlyNotification && root.notificationObject.image !== "" && root.expanded) ? 1 : 0
    image: notificationObject.image
    baseSize: Bar.height * 0.8
    anchors.right: background.left
    anchors.top: background.top
    anchors.rightMargin: Widget.padding
    // Behavior on opacity { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }
  }

  StyledContainer {
    id: background
    width: parent.width
    anchors.left: parent.left
    anchors.leftMargin: root.xOffset
    radius: Appearance.borderRadius
    clip: true

    Behavior on anchors.leftMargin {
      enabled: !mouseArea.drag.active && Widget.animations
      NumberAnimation {
        duration: Widget.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    color: {
      if (!expanded || onlyNotification)
        return "transparent";
      if (notificationObject.urgency === NotificationUrgency.Critical) {
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4);
      }
      return Theme.backgroundHighlight;
    }

    implicitHeight: expanded ? contentColumn.implicitHeight + (onlyNotification ? 0 : Widget.padding * 2) : summaryText.implicitHeight
    // Behavior on implicitHeight { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: (expanded && !onlyNotification) ? Widget.padding : 0
      spacing: Widget.spacing
      Layout.fillWidth: true

      // Behavior on anchors.margins { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

      RowLayout {
        Layout.fillWidth: true
        visible: !root.onlyNotification || !root.expanded
        implicitHeight: summaryText.implicitHeight
        Text {
          id: summaryText
          visible: !root.onlyNotification
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 2
          color: Theme.foreground
          elide: Text.ElideRight
          text: root.notificationObject.summary || ""
        }
        Text {
          opacity: !root.expanded ? 1 : 0
          visible: opacity > 0
          Layout.fillWidth: true
          // Behavior on opacity { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 2
          color: Theme.foregroundAlt
          elide: Text.ElideRight
          wrapMode: Text.Wrap
          maximumLineCount: 1
          text: root.notificationObject.body.replace(/\n/g, " ")
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        // Behavior on opacity { enabled: Widget.animations; Animation { duration: Widget.animationDuration } }

        Text {
          id: notificationBodyText
          Layout.fillWidth: true
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize - 2
          color: Theme.foregroundAlt
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

          RowLayout {
            id: actionRowLayout
            spacing: Widget.spacing

            Repeater {
              model: notificationObject.actions
              delegate: Comp.NotificationActionButton {
                buttonText: modelData.text
                urgency: notificationObject.urgency
                // FIX: Re-enabled action handler
                onClicked: notificationObject.invokeAction(modelData.identifier)
              }
            }

            Comp.NotificationActionButton {
              id: copyButton
              urgency: notificationObject.urgency
              // FIX: Re-enabled action handler
              onClicked: {
                Quickshell.clipboardText = notificationObject.body;
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

  MouseArea {
    id: mouseArea
    anchors.fill: background
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    // FIX: Removed drag.target to prevent binding loop
    drag.axis: Drag.XAxis

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) {
        root.destroyWithAnimation();
      }
    }
    // FIX: Manually update xOffset based on drag distance to prevent binding loop
    onPositionChanged: mouse => {
      if (drag.active) {
        root.xOffset = Math.max(0, mouse.x - pressPoint.x);
      }
    }

    onReleased: () => {
      if (root.xOffset > root.dragConfirmThreshold) {
        root.destroyWithAnimation();
      } else {
        root.xOffset = 0; // Animate back
      }
    }
  }
}
