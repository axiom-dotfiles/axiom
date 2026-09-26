pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config

// One edge menu from EdgeMenusConfig, on its screen, in its mode. Only the
// host in use is created.
Scope {
  id: root

  required property string menuId
  readonly property var menu: EdgeMenusConfig.menuById(root.menuId)
  readonly property ShellScreen screen: EdgeMenusConfig.screenFor(root.menu)
  readonly property bool integrated: root.menu?.mode === "integrated"

  LazyLoader {
    active: !!root.menu && !!root.screen && !root.integrated

    FloatingEdgeMenu {
      menu: root.menu
      screen: root.screen
    }
  }

  LazyLoader {
    active: !!root.menu && !!root.screen && root.integrated

    IntegratedEdgeMenu {
      menu: root.menu
      screen: root.screen
    }
  }
}
