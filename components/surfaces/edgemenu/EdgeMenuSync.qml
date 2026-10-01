pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout

// What both edge menu hosts (FloatingEdgeMenu, IntegratedEdgeMenu) share:
// following EdgeMenuManager (opening and closing when it says, telling it
// when the menu closes by itself), being held open (pinned, or by the
// editor), and a reveal (EdgeMenuManager.reveal): held open until hovered,
// the cursor moved into it once shown (`warpRequested`).
QtObject {
  id: root

  required property PopoutWrapperBase host
  required property var menu
  required property ShellScreen screen
  // The host's window: a grab partner, and what must be mapped to warp
  required property var window

  // The cursor should move into the menu (it's being revealed and shown)
  signal warpRequested

  readonly property string menuId: root.menu.id
  // Pinned, or held open by the editor
  readonly property bool held: EdgeMenuManager.isHeld(root.menuId)
  readonly property bool wanted: EdgeMenuManager.openMenus[root.menuId] === true
  readonly property bool revealing: EdgeMenuManager.revealing[root.menuId] === true
  // Closes when the pointer leaves, unless held or being revealed
  readonly property bool autoDismiss: root.menu.closeOnLeave && !root.held && !root.revealing
  onAutoDismissChanged: root.host.updateDismissTimer()

  // The hover strip's length: the menu's own setting, else the body's
  // length (`body`, with `pad` on both ends), or from config until the
  // body has been loaded
  function triggerLength(body, vertical, pad) {
    if (root.menu.triggerLength > 0)
      return root.menu.triggerLength;
    if (body)
      return (vertical ? body.implicitHeight : body.implicitWidth) + pad * 2;
    return EdgeMenusConfig.lengthOf(root.menu, vertical, EdgeMenuManager.cardUnitOf(root.menu));
  }

  function _sync() {
    if (root.wanted && !root.host.isOpen)
      root.host.show({
        "anchorItem": EdgeMenuManager.anchors[root.menuId] ?? null
      });
    else if (!root.wanted && root.host.isOpen)
      root.host.hide();
  }
  onWantedChanged: root._sync()

  property Connections _host: Connections {
    target: root.host

    function onIsOpenChanged() {
      if (!root.host.isOpen)
        EdgeMenuManager.revealDone(root.menuId);
      if (!root.host.isOpen && root.wanted && !root.host.hasPendingOpen)
        EdgeMenuManager.close(root.menuId);
      else if (root.host.isOpen && !root.wanted)
        EdgeMenuManager.open(root.menuId, null);
    }

    function onContentHoveredChanged() {
      if (root.host.contentHovered)
        EdgeMenuManager.revealDone(root.menuId);
    }
  }

  property Timer _warp: Timer {
    interval: 150
    running: root.revealing && root.host.isOpen && root.window.visible
    onTriggered: root.warpRequested()
  }

  Component.onCompleted: {
    ShellManager.registerGrabPartner(root.window, root.screen?.name ?? "");
    Qt.callLater(root._sync);
  }
  Component.onDestruction: ShellManager.unregisterGrabPartner(root.window)
}
