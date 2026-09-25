import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services
import qs.config
import qs.components.surfaces.notifications

// Stacks incoming notifications as toasts from a corner of the primary
// monitor's work area (NotificationsConfig), driven by
// NotificationManager.showPopup. Dismissing a toast
// only hides it — the notification stays tracked and remains visible/
// actionable from the bell popout.
Scope {
  id: root

  property int maxVisibleToasts: 5
  property int stackSpacing: 10
  property int toastWidth: 360
  property int toastMaxHeight: 220
  property int dismissDuration: 5000
  property real dragDismissThreshold: 150

  property var activeToasts: []

  readonly property var screen: Quickshell.screens.find(s => s.name === General.primaryMonitor) ?? Quickshell.screens[0] ?? null

  // Invisible anchor window the toast PopupWindows position relative to,
  // in the chosen corner of the work area. Normal exclusion with no zone of
  // its own keeps it inside the space the bars, the border (and any other
  // app's panels) reserve, as OverlayPanel does, so the gaps are measured
  // from whatever is at each edge. A transparent bar reserves Hyprland's
  // gaps_out less than it draws (see BarPanel) and shows only its widgets,
  // `inset` inside its window: the gap starts at their inner edge instead.
  readonly property var _edges: Bar.edgesFor(root.screen)
  function _edgeGap(side, gap) {
    const bar = root._edges[side];
    if (bar?.background !== "transparent")
      return gap;
    return gap + (HyprlandManager.gapsOut[side] ?? 0) - (bar.inset ?? 0);
  }

  PanelWindow {
    id: anchorPanel
    visible: true
    screen: root.screen

    implicitWidth: 1
    implicitHeight: 1

    anchors {
      top: NotificationsConfig.top
      bottom: !NotificationsConfig.top
      left: NotificationsConfig.left
      right: !NotificationsConfig.left
    }
    margins {
      top: root._edgeGap("top", NotificationsConfig.gapTop)
      bottom: root._edgeGap("bottom", NotificationsConfig.gapBottom)
      left: root._edgeGap("left", NotificationsConfig.gapLeft)
      right: root._edgeGap("right", NotificationsConfig.gapRight)
    }

    color: "transparent"
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "axiom-notifications"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    // Where NotificationManager renders images to cache them: grabbing
    // needs an item in a window (items may lie outside this 1x1 one)
    Item {
      id: imageHost
      x: 1
    }
  }

  Component {
    id: toastComponent

    NotificationToast {
      notification: null // set on creation
      anchorWindow: anchorPanel

      toastWidth: root.toastWidth
      toastMaxHeight: root.toastMaxHeight
      dismissDuration: root.dismissDuration
      dragDismissThreshold: root.dragDismissThreshold
      alignRight: !NotificationsConfig.left
      fromBottom: !NotificationsConfig.top
    }
  }

  Component.onCompleted: {
    if (typeof NotificationManager !== "undefined") {
      NotificationManager.showPopup.connect(createToast);
      NotificationManager.imageHost = imageHost;
    }
  }

  function createToast(notification) {
    if (activeToasts.length >= maxVisibleToasts) {
      const oldest = activeToasts[0];
      if (oldest)
        oldest.dismiss();
    }

    const toast = toastComponent.createObject(root, {
      notification: notification,
      targetY: calculateTargetY(activeToasts.length)
    });

    if (!toast) {
      console.error("Notifications: failed to create toast for", notification.summary);
      return;
    }

    activeToasts.push(toast);

    // If the notification is dismissed elsewhere (e.g. from the bell
    // popout) while its toast is still showing, animate the toast out too.
    // Disconnected once the toast is gone, so a later close doesn't call
    // into a destroyed toast.
    const onClosed = () => {
      if (activeToasts.includes(toast))
        toast.dismiss();
    };
    notification.closed.connect(onClosed);
    toast.dismissed.connect(() => {
      try {
        notification.closed.disconnect(onClosed);
      } catch (e) {
        // The notification itself is already gone
      }
      removeToast(toast);
    });
  }

  function calculateTargetY(index) {
    let y = 0;
    for (let i = 0; i < index && i < activeToasts.length; i++) {
      y += activeToasts[i].implicitHeight + stackSpacing;
    }
    return y;
  }

  function removeToast(toast) {
    const index = activeToasts.indexOf(toast);
    if (index === -1)
      return;
    activeToasts.splice(index, 1);
    updateToastPositions();
    Qt.callLater(() => {
      if (!toast.visible)
        toast.destroy();
    });
  }

  function updateToastPositions() {
    for (let i = 0; i < activeToasts.length; i++) {
      activeToasts[i].updatePosition(calculateTargetY(i));
    }
  }
}
