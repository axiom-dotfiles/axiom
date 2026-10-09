pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services

/**
 * Drop this into any bar widget that wants to open a bar popout on hover
 * (or, given a `menu`, an edge menu).
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

  property string popoutName: ""
  // An edge menu's id to open instead of a popout (a widget's menu popout,
  // EdgeMenusConfig.popoutMenuOf): opened with this as its anchor, so a
  // floating one stays open while this is hovered
  property string menu: ""
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
      if (root.popouts || root.menu !== "")
        openTimer.restart();
    } else {
      openTimer.stop();
    }
  }
  // This widget's popout is up (and not closing) or queued to open next.
  // Read from the wrapper rather than kept as a flag: a queued open that
  // another widget's hover replaced never opened, so nothing would clear it
  readonly property bool popoutOpen: {
    // Covered by a popout over it, it's brought forward
    if (root.menu !== "")
      return EdgeMenuManager.isOpen(root.menu) && !EdgeMenuManager.covered(root.menu);
    const popouts = root.popouts;
    if (!popouts)
      return false;
    return (popouts.isOpen && popouts.currentData?.anchorItem === root) || (popouts.hasPendingOpen && popouts.pendingOpenData?.anchorItem === root);
  }

  anchors.fill: parent

  function open() {
    if (!root.active || root.popoutOpen)
      return;
    if (root.menu !== "") {
      EdgeMenuManager.open(root.menu, root);
      return;
    }
    if (!root.popouts || !root.panel)
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
