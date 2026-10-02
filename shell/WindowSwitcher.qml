pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout
import qs.components.surfaces.switcher

// The window switcher (WindowSwitcherManager): a box of window tiles in
// the middle of the monitor that was focused when it opened. It takes no
// keyboard: Hyprland's submap holds the keys, so focus stays on the window
// until one is picked.
Scope {
  Variants {
    model: General.screensFor("focused")

    delegate: FloatingPopout {
      id: host
      required property ShellScreen modelData

      readonly property bool wanted: WindowSwitcherManager.shown && host.modelData.name === WindowSwitcherManager.screenName

      screen: modelData
      layerNamespace: "axiom-switcher"
      // Closes when the switcher does, not on hover loss
      autoDismiss: false

      onWantedChanged: host.wanted ? host.show() : host.hide()

      content: Component {
        // Wraps to more rows past 80% of the screen's width
        SwitcherStrip {
          maxWidth: host.modelData.width * 0.8
        }
      }
    }
  }
}
