// In qs/components/reusable/StyledPopupWindow.qml
import QtQuick
import Quickshell

import qs.config

// A styled popup window that can be anchored to another window.
PopupWindow {
  id: popupRoot

  // --- Configuration ---
  // These properties allow styling from the outside.
  property color containerColor: Theme.background
  property color containerBorderColor: Theme.border
  property int containerBorderWidth: Appearance.borderWidth
  property int containerRadius: Appearance.borderRadius
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
    color: popupRoot.containerColor
    border.color: popupRoot.containerBorderColor
    border.width: popupRoot.containerBorderWidth
    radius: popupRoot.containerRadius
    clip: popupRoot.clip

    // This item will hold the content passed in via the 'contentData' alias.
    Item {
      id: contentHolder
      anchors.fill: parent
    }
  }
}
