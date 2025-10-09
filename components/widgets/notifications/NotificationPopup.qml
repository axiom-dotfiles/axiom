import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.config

PopupWindow {
  id: popup

  // Configuration properties
  property int popupWidth: 350
  property int popupMaxHeight: 150
  property int dismissDuration: 5000
  property real dragDismissThreshold: 150
  property int borderRadius: Appearance.borderRadius
  property int borderWidth: Appearance.borderWidth
  property int contentMargin: 10
  property int headerSpacing: 5
  property int contentSpacing: 5
  property int closeButtonSize: 20
  property int appNameFontSize: 11
  property int summaryFontSize: 14
  property int bodyFontSize: 12
  property int maxSummaryLines: 2
  property int maxBodyLines: 3
  property int leftOffset: 20  // Distance from left edge
  property int topOffset: 20   // Distance from top edge

  // Required properties
  required property var notification
  property int index: 0
  property int totalNotifications: 1
  property int targetY: 0
  property var anchorWindow: null

  // Animation properties
  property int animationDuration: Appearance.animations ? Appearance.animationDuration : 0
  property real currentY: -popupMaxHeight
  property real opacity: 0

  // Set dimensions
  implicitWidth: popupWidth
  implicitHeight: Math.min(contentLayout.implicitHeight + (contentMargin * 2), popupMaxHeight)

  visible: false
  color: "transparent" // Window background is transparent, content has the color

  // Position and anchor setup
  anchor.window: anchorWindow

  Component.onCompleted: {
    // Set position relative to anchor window with offsets
    anchor.rect.x = leftOffset;
    anchor.rect.y = currentY;
    anchor.rect.width = implicitWidth;
    anchor.rect.height = implicitHeight;

    // Make visible and start animation
    visible = true;
    slideIn();
  }

  // Slide in animation
  function slideIn() {
    slideInAnimation.start();
  }

  // Slide out animation
  function slideOut() {
    slideOutAnimation.start();
  }

  // Animations - optimized with property bindings instead of constant updates
  ParallelAnimation {
    id: slideInAnimation

    NumberAnimation {
      target: contentRect
      property: "y"
      from: -popup.implicitHeight
      to: 0
      duration: animationDuration
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: contentRect
      property: "opacity"
      from: 0
      to: 0.95
      duration: animationDuration
      easing.type: Easing.OutCubic
    }

    onStarted: {
      anchor.rect.y = targetY;
    }
  }

  // Fade out animation only
  NumberAnimation {
    id: slideOutAnimation
    target: contentRect
    property: "opacity"
    from: 0.95
    to: 0
    duration: animationDuration / 2  // Faster fade out
    easing.type: Easing.InQuad

    onFinished: {
      dismissComplete();
    }
  }

  // Auto-dismiss timer
  Timer {
    id: dismissTimer
    interval: notification && !notification.persistent ? dismissDuration : 0
    running: notification && !notification.persistent && popup.visible && !mouseArea.containsMouse
    onTriggered: {
      popup.dismissPopup();
    }
  }

  // Dismiss function - only closes the popup, doesn't dismiss the notification
  function dismissPopup() {
    if (slideOutAnimation.running)
      return;
    slideOut();
  }

  // Called when dismiss animation completes
  function dismissComplete() {
    // Don't call notification.dismiss() - let the notification system handle that
    popup.visible = false;
  }

  // Update position for stacking
  function updatePosition(newIndex, totalCount) {
    index = newIndex;
    totalNotifications = totalCount;
    targetY = newIndex * (implicitHeight + 10) + topOffset; // Stack with 10px gap, using topOffset

    if (!slideInAnimation.running && !slideOutAnimation.running) {
      // Animate to new position if already visible
      positionAnimation.start();
    }
  }

  NumberAnimation {
    id: positionAnimation
    target: contentRect
    property: "y"
    to: 0  // Always animate content to its normal position
    duration: animationDuration
    easing.type: Easing.InOutCubic

    onStarted: {
      anchor.rect.y = targetY;  // Update anchor position immediately
    }
  }

  // Main content
  Rectangle {
    id: contentRect
    anchors.fill: parent
    color: Theme.background
    opacity: 0
    radius: borderRadius
    border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.1)
    border.width: borderWidth

    // Performance optimization - disable when not visible
    visible: opacity > 0
    layer.enabled: opacity > 0 && opacity < 0.95  // Only during animations
    layer.smooth: false  // Faster rendering

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true

      property real startX: 0
      property real dragDelta: 0

      onContainsMouseChanged: {
        if (containsMouse) {
          dismissTimer.stop();
        } else if (!notification.persistent) {
          dismissTimer.restart();
        }
      }

      onPressed: mouse => {
        startX = mouse.x;
        dragDelta = 0;
      }

      onPositionChanged: mouse => {
        if (pressed) {
          dragDelta = mouse.x - startX;

          // Visual feedback during drag - lighter computation
          contentRect.x = dragDelta * 0.5;
          contentRect.opacity = 0.95 * (1 - Math.abs(dragDelta) / (dragDismissThreshold * 2));

          // If dragged far enough, dismiss
          if (Math.abs(dragDelta) > dragDismissThreshold) {
            popup.dismissPopup();
          }
        }
      }

      onReleased: {
        if (Math.abs(dragDelta) < dragDismissThreshold) {
          // Snap back if not dismissed
          snapBackAnimation.start();
        }
      }

      NumberAnimation {
        id: snapBackAnimation
        target: contentRect
        property: "x"
        to: 0
        duration: animationDuration / 2
        easing.type: Easing.OutCubic
      }

      ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: contentMargin
        spacing: contentSpacing

        // Header row
        RowLayout {
          Layout.fillWidth: true
          spacing: headerSpacing

          // App name
          Label {
            text: notification && notification.appName ? notification.appName : ""
            color: Theme.foregroundAlt
            font.pixelSize: appNameFontSize
            font.family: Appearance.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
          }

          // Close button
          Rectangle {
            Layout.preferredWidth: closeButtonSize
            Layout.preferredHeight: closeButtonSize
            color: closeMouseArea.containsMouse ? Theme.red : "transparent"
            opacity: closeMouseArea.containsMouse ? 0.2 : 1
            radius: borderRadius

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: closeMouseArea.containsMouse ? Theme.red : Theme.foregroundAlt
              font.pixelSize: 14
              font.family: Appearance.fontFamily
            }

            MouseArea {
              id: closeMouseArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: popup.dismissPopup()
            }
          }
        }

        // Summary/Title
        Label {
          text: notification && notification.summary ? notification.summary : ""
          color: Theme.foreground
          font.pixelSize: summaryFontSize
          font.bold: true
          font.family: Appearance.fontFamily
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: maxSummaryLines
          elide: Text.ElideRight
        }

        // Body text
        Label {
          visible: notification && notification.body && notification.body !== ""
          text: notification && notification.body ? notification.body : ""
          color: Theme.foregroundAlt
          font.pixelSize: bodyFontSize
          font.family: Appearance.fontFamily
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: maxBodyLines
          elide: Text.ElideRight
          textFormat: notification && notification.bodyMarkup ? Text.RichText : Text.PlainText
        }
      }
    }
  }
}
