import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services
import qs.config
import qs.components.widgets.reusable

IconTextWidget {
  id: root
  icon: ""
  text: (ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.title) 
    ? ToplevelManager.activeToplevel.title 
    : "—";
  backgroundColor: Theme.accentAlt
  maxTextLength: 10
  elideText: true
}
