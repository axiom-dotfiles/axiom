import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell

import qs.services
import qs.config
import qs.components.widgets.notifications

// TODO: Fix this entire mess

Scope {
  id: root

  // Configuration properties
  property int maxVisibleNotifications: 5
  property int stackSpacing: 10
  property int topOffset: Appearance.containerWidth + 20
  property int leftOffset: Bar.extent + 20
  property int popupWidth: 350
  property int popupMaxHeight: 150
  property int dismissDuration: 5000
  property real dragDismissThreshold: 150

  // List to track active popup windows
  property var activePopups: []

  // Create an invisible panel window for anchoring popups
  PanelWindow {
    id: anchorPanel
    visible: true  // Must be visible for popups to work

    // Make it minimal and out of the way
    implicitWidth: 1
    implicitHeight: 1

    anchors {
      top: true
      left: true
    }

    // Transparent and non-interactive
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    Component.onCompleted: {
      console.log("[Notifs] NotificationManager: Anchor panel created");
    }
  }

  // Component for creating popups
  Component {
    id: popupComponent

    NotificationPopup {
      notification: null  // Will be set on creation
      anchorWindow: anchorPanel

      // Pass through configuration including offsets
      popupWidth: root.popupWidth
      popupMaxHeight: root.popupMaxHeight
      dismissDuration: root.dismissDuration
      dragDismissThreshold: root.dragDismissThreshold
      leftOffset: root.leftOffset
      topOffset: root.topOffset
    }
  }

  Component.onCompleted: {
    console.log("[Notifs] NotificationManager: Initialized");
    // Connect to the Notifs singleton
    if (typeof Notifs !== "undefined") {
      Notifs.showPopup.connect(createPopup);
      console.log("[Notifs] NotificationManager: Connected to Notifs service");
    } else {
      console.error("NotificationManager: Notifs singleton not found!");
    }
  }

  // Create a new popup for the notification
  function createPopup(notification) {
    console.log("[Notifs] NotificationManager: Creating popup for:", notification.summary);

    // Check if we're at max capacity
    if (activePopups.length >= maxVisibleNotifications) {
      // Dismiss the oldest notification
      const oldest = activePopups[0];
      if (oldest && oldest.popup) {
        oldest.popup.dismissPopup();
      }
    }

    try {
      // Calculate position based on current stack
      const stackIndex = activePopups.length;
      const targetY = calculateTargetY(stackIndex);

      // Create the popup instance
      const popup = popupComponent.createObject(root, {
        notification: notification,
        index: stackIndex,
        totalNotifications: activePopups.length + 1,
        targetY: targetY
      });

      if (popup) {
        console.log("[Notifs] NotificationManager: Popup created successfully");

        // Add to active popups
        activePopups.push({
          popup: popup,
          notification: notification
        });

        // Update all popup positions
        updatePopupPositions();

        // Connect to notification dismissal
        if (notification && notification.closed) {
          notification.closed.connect(() => {
            removePopup(popup);
          });
        }

        // Watch for popup becoming invisible
        popup.visibleChanged.connect(() => {
          if (!popup.visible) {
            removePopup(popup);
          }
        });
      } else {
        console.error("NotificationManager: Failed to create popup object");
      }
    } catch (error) {
      console.error("NotificationManager: Error creating popup:", error);
    }
  }

  // Calculate target Y position for a notification at given index
  function calculateTargetY(index) {
    let y = topOffset;

    // Stack notifications with spacing
    for (let i = 0; i < index && i < activePopups.length; i++) {
      if (activePopups[i] && activePopups[i].popup) {
        y += activePopups[i].popup.implicitHeight + stackSpacing;
      } else {
        // Fallback if popup not available
        y += popupMaxHeight + stackSpacing;
      }
    }

    return y;
  }

  // Remove a popup and update positions
  function removePopup(popupToRemove) {
    const index = activePopups.findIndex(item => item.popup === popupToRemove);

    if (index !== -1) {
      console.log("[Notifs] Removing popup at index:", index);
      activePopups.splice(index, 1);
      updatePopupPositions();

      // Destroy the popup after a delay to allow animations to complete
      Qt.callLater(() => {
        if (popupToRemove && !popupToRemove.visible) {
          popupToRemove.destroy();
        }
      });
    }
  }

  // Update positions of all active popups
  function updatePopupPositions() {
    for (let i = 0; i < activePopups.length; i++) {
      const item = activePopups[i];
      if (item.popup && item.popup.updatePosition) {
        const targetY = calculateTargetY(i);
        item.popup.targetY = targetY;
        item.popup.updatePosition(i, activePopups.length);
      }
    }
  }

  // Clear all notifications
  function clearAll() {
    console.log("[Notifs] NotificationManager: Clearing all notifications");
    const popupsCopy = [...activePopups];
    for (const item of popupsCopy) {
      if (item.popup) {
        item.popup.dismissPopup();
      }
    }
  }

  // Get count of active notifications
  function getActiveCount() {
    return activePopups.length;
  }
}
