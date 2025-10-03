// In qs/components/reusable/StyledPopupWindow.qml
import QtQuick
import Quickshell

import qs.config

// A styled popup window that can be anchored to another window.
PopupWindow {
  id: popupRoot

  // --- Configuration ---
  // These properties allow styling from the outside.
  property color backgroundColor: Theme.background
  property color borderColor: Theme.border
  property int borderWidth: Appearance.borderWidth
  property int borderRadius: Appearance.borderRadius
  property bool clip: true

  // --- Setup ---
  // Allow child items to be declared inside this component's tags in QML.
  default property alias contentData: contentHolder.data

  // Make the underlying PopupWindow surface transparent.
  color: "transparent"

  // This Rectangle provides the visible appearance (background, border, radius).
  Rectangle {
    id: backgroundRect
    anchors.fill: parent
    color: popupRoot.backgroundColor
    border.color: popupRoot.borderColor
    border.width: popupRoot.borderWidth
    radius: popupRoot.borderRadius
    clip: popupRoot.clip

    // This item will hold the content passed in via the 'contentData' alias.
    Item {
      id: contentHolder
      anchors.fill: parent
    }
  }
}
