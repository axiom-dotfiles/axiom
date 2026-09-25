pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services // TEMP-SCREENSHOT

/**
 * Drop this into any bar widget that wants to open a bar popout on hover.
 * Handles hover detection, open-delay timing, position/size computation,
 * and the popoutOpen guard flag.
 *
 * Usage:
 *   PopoutAnchor {
 *     id: anchor
 *     popouts: root.popouts
 *     panel: root.panel
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

  required property var popouts
  required property var panel
  required property string popoutName

  property var extraData: ({})
  property int openDelay: PopoutConfig.openDelay
  property bool active: true
  // Centre the popout on the widget as it is when opened, then keep it
  // there while open: a widget that resizes doesn't drag its popout along
  property bool pinWhileOpen: false

  // TEMP-SCREENSHOT: was `property alias hovered: hoverHandler.hovered`
  property bool _debugHold: false
  readonly property bool hovered: hoverHandler.hovered || _debugHold
  property bool popoutOpen: false

  anchors.fill: parent

  function open() {
    if (!root.active || !root.popouts || !root.panel || root.popoutOpen)
      return;

    let parentPosition = root.mapToItem(null, 0, 0);
    root.popoutOpen = true;

    let payload = {
      name: root.popoutName,
      pinned: root.pinWhileOpen,
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

  // TEMP-SCREENSHOT
  Connections {
    target: ShellManager
    function onDebugPopout(name) {
      root._debugHold = name !== "" && (name === root.popoutName || name === root.popoutName + ":" + root.extraData.mode);
      if (root.popoutOpen || root.popouts?.currentData?.anchorItem === root)
        console.log("[TEMP-SCREENSHOT]", root.popoutName, "open", root.popoutOpen, "mine", root.popouts?.currentData?.anchorItem === root, "occupied", root.popouts?.occupied, "closing", root.popouts?.isClosing);
      if (root._debugHold)
        root.open();
      else if (root.popouts?.currentData?.anchorItem === root)
        root.popouts.requestDismiss();
    }
  }

  HoverHandler {
    id: hoverHandler
    onHoveredChanged: {
      if (hovered && root.active) {
        if (root.popouts)
          openTimer.restart();
      } else {
        openTimer.stop();
      }
    }
  }

  Timer {
    id: openTimer
    interval: root.openDelay
    repeat: false
    onTriggered: {
      if (hoverHandler.hovered && root.active)
        root.open();
    }
  }
}
