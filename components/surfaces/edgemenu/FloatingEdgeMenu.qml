pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout

// A floating edge menu: an EdgePopout over the windows, growing out of the
// border or a solid bar on its edge. On a pill or transparent bar there's
// no strip to grow out of, so it's a detached box beside the bar, as bar
// popouts are on a transparent bar.
EdgePopout {
  id: root

  required property var menu
  readonly property string menuId: root.menu?.id ?? ""
  readonly property bool pinned: EdgeMenuManager.pinnedMenus[root.menuId] === true
  readonly property bool wanted: EdgeMenuManager.openMenus[root.menuId] === true

  // The bar on this edge, if any
  readonly property var edgeBar: Bar.edgesFor(root.screen)[["top", "bottom", "left", "right"][root.edge]]

  edge: EdgeMenusConfig.edgeOf(root.menu)
  position: (root.menu?.position ?? 50) / 100
  detached: !!root.edgeBar && root.edgeBar.background !== "solid"
  triggerEnabled: root.menu?.openOnHover ?? false
  triggerLength: root.vertical ? (root.contentItem?.implicitHeight ?? 200) : (root.contentItem?.implicitWidth ?? 200)
  keyboardOnDemand: true
  closeOnClickOutside: (root.menu?.closeOnOutsideClick ?? false) && !root.pinned
  autoDismiss: (root.menu?.closeOnLeave ?? true) && !root.pinned
  onAutoDismissChanged: root.updateDismissTimer()

  // Follow EdgeMenuManager, and tell it when the popout closes by itself
  function _sync() {
    if (root.wanted && !root.isOpen)
      root.show({
        "anchorItem": EdgeMenuManager.anchors[root.menuId] ?? null
      });
    else if (!root.wanted && root.isOpen)
      root.hide();
  }
  onWantedChanged: _sync()
  onIsOpenChanged: {
    if (!root.isOpen && root.wanted && !root.hasPendingOpen)
      EdgeMenuManager.close(root.menuId);
    else if (root.isOpen && !root.wanted)
      EdgeMenuManager.open(root.menuId, null);
  }
  Component.onCompleted: {
    ShellManager.registerGrabPartner(root.window, root.screen?.name ?? "");
    Qt.callLater(root._sync);
  }
  Component.onDestruction: ShellManager.unregisterGrabPartner(root.window)

  content: Component {
    EdgeMenuBody {
      menu: root.menu
      vertical: root.vertical
      maxLength: root.maxBoxLength - Widget.spacing * 2
    }
  }
}
