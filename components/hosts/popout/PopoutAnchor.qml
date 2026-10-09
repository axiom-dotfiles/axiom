pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config

/**
 * Drop this into any bar widget that wants to open a bar popout on hover.
 * Handles hover detection, open-delay timing, position/size computation,
 * and the popoutOpen guard flag.
 *
 * Usage:
 *   PopoutAnchor {
 *     id: anchor
 *     popoutName: "WorkspaceGrid"
 *     extraData: ({ monitor: root.monitor, workspaceBase: root.workspaceBase })
 *   }
 *
 * The content-type name travels as a `name` field inside the payload
 * (not a separate argument) so Popout.qml's open/close/queue logic can
 * stay fully generic — see PopoutWrapperBase.qml.
 */
Item {
  id: root

  required property string popoutName
  // The window it's in, and the popouts host showing what it opens there
  // (BarPanel.popoutHost): found by itself, so anything in a bar can open
  // a popout without being handed either
  readonly property var panel: root.QsWindow.window
  readonly property var popouts: root.panel?.popoutHost ?? null

  property var extraData: ({})
  property int openDelay: PopoutConfig.openDelay
  property bool active: true
  // A bar widget's hitArea: hovered in its background's shape (its
  // `hovered`) rather than in this item's bounds
  property var hitArea: null

  readonly property bool hovered: hitArea ? hitArea.hovered : hoverHandler.hovered
  onHoveredChanged: {
    if (root.hovered && root.active) {
      if (root.popouts)
        openTimer.restart();
    } else {
      openTimer.stop();
    }
  }
  // This widget's popout is up (and not closing) or queued to open next.
  // Read from the wrapper rather than kept as a flag: a queued open that
  // another widget's hover replaced never opened, so nothing would clear it
  readonly property bool popoutOpen: {
    const popouts = root.popouts;
    if (!popouts)
      return false;
    return (popouts.isOpen && popouts.currentData?.anchorItem === root) || (popouts.hasPendingOpen && popouts.pendingOpenData?.anchorItem === root);
  }

  anchors.fill: parent

  function open() {
    if (!root.active || !root.popouts || !root.panel || root.popoutOpen)
      return;

    let parentPosition = root.mapToItem(null, 0, 0);

    let payload = {
      name: root.popoutName,
      anchorX: parentPosition.x,
      anchorY: parentPosition.y,
      anchorWidth: root.width,
      anchorHeight: root.height,
      anchorItem: root
    };

    for (let key in root.extraData) {
      payload[key] = root.extraData[key];
    }

    root.popouts.safeOpenPopout(root.panel, payload);
  }

  HoverHandler {
    id: hoverHandler
    enabled: !root.hitArea
  }

  Timer {
    id: openTimer
    interval: root.openDelay
    repeat: false
    onTriggered: {
      if (root.hovered && root.active)
        root.open();
    }
  }
}
