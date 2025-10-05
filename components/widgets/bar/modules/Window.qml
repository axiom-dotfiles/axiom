pragma ComponentBehavior: Bound

import Quickshell.Wayland

import qs.config
import qs.components.reusable

IconTextWidget {
  id: root
  isVertical: barConfig.vertical
  icon: ""
  text: (ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.title) ? ToplevelManager.activeToplevel.title : "—"
  backgroundColor: Theme.accentAlt
  maxTextLength: 10
  elideText: true
}
