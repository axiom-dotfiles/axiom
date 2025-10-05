pragma ComponentBehavior: Bound

import Quickshell.Wayland

import qs.config
import qs.components.reusable

IconTextWidget {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen

  isVertical: barConfig.vertical
  icon: ""
  text: (ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.title) ? ToplevelManager.activeToplevel.title : "—"
  backgroundColor: Theme.accentAlt
  maxTextLength: 10
  elideText: true
}
