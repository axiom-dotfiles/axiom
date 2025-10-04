pragma ComponentBehavior: Bound

import QtQuick

import qs.config
import qs.services
import qs.components.reusable
import qs.components.widgets.bar

BarModule {
  content: StyledRectButton {
    id: component

    // -- Signals --
    // null

    // -- Public API --
    // null

    // -- Configurable Appearance --
    iconText: ""
    iconColor: Theme.background
    borderHoverColor: Theme.accent
    backgroundColor: Theme.accent

    // -- Implementation --
    onClicked: ShellManager.togglePinnedPanel("mainMenu")
  }
}
