// Abstracts/StyledNotificationBox.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Frame {
  id: root

  // --- Data Property ---
  property var notification

  // --- Style Properties (to be provided by parent) ---
  property color backgroundColor
  property color headerTextColor
  property color bodyTextColor
  property color actionButtonColor
  property color actionButtonTextColor
  property color actionButtonBorderColor
  property color criticalHighlightColor
  property real borderRadius
  property real borderWidth
  property string fontFamily
  property int appNameFontSize
  property int summaryFontSize
  property int bodyFontSize
  property int actionButtonFontSize
  property int contentPadding
  property int actionSpacing

  background: Rectangle {
    color: root.backgroundColor
    implicitHeight: 100
    radius: root.borderRadius
    border.width: root.notification.urgency === NotificationUrgency.Critical ? root.borderWidth + 1 : root.borderWidth
    border.color: root.notification.urgency === NotificationUrgency.Critical ? root.criticalHighlightColor : "transparent"
  }
  padding: contentPadding

  // Main layout for the notification content
  ColumnLayout {
    Layout.fillWidth: true

    // Header: App Name, Summary, and Dismiss Button
    RowLayout {
      Layout.fillWidth: true

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Label {
          text: notification.appName
          color: headerTextColor
          font.family: root.fontFamily
          font.pixelSize: root.appNameFontSize
        }
        Label {
          text: notification.summary
          color: bodyTextColor
          font.bold: true
          font.family: root.fontFamily
          font.pixelSize: root.summaryFontSize
          wrapMode: Text.Wrap
        }
      }

      // Dismiss button
      Button {
        icon.source: "image://theme/window-close"
        icon.color: headerTextColor
        flat: true
        Layout.alignment: Qt.AlignTop
        onClicked: notification.dismiss()
      }
    }

    // Body Text (if it exists)
    Label {
      visible: notification.body.length > 0
      text: notification.body
      color: bodyTextColor
      font.family: root.fontFamily
      font.pixelSize: root.bodyFontSize
      wrapMode: Text.Wrap
      textFormat: Text.RichText
      Layout.topMargin: 4
      Layout.fillWidth: true
    }

    // Action Buttons (if they exist)
    RowLayout {
      visible: root.notification.actions.length > 0
      spacing: root.actionSpacing
      Layout.topMargin: 12

      Repeater {
        model: root.notification.actions
        delegate: Button {
          text: modelData.text
          flat: true
          font.family: root.fontFamily
          font.pixelSize: root.actionButtonFontSize

          background: Rectangle {
            color: root.actionButtonColor
            radius: root.borderRadius > 2 ? root.borderRadius - 2 : root.borderRadius
            border.width: root.borderWidth
            border.color: root.actionButtonBorderColor
          }

          contentItem: Label {
            text: parent.text
            color: root.actionButtonTextColor
            font: parent.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          onClicked: modelData.invoke()
        }
      }
    }
  }
}
