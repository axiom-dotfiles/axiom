// PowerMenuButton.qml
pragma ComponentBehavior: Bound
import qs.config
import qs.services
import qs.components.widgets.bar
import qs.components.reusable

BarModule {
  content: StyledRectButton {
    id: component
    
    // -- Signals --
    // null
    
    // -- Public API --
    // null
    
    // -- Configurable Appearance --
    iconText: "󰣇"
    iconColor: Theme.background
    borderHoverColor: Theme.info
    backgroundColor: Theme.info
    
    // -- Implementation --
    onClicked: ShellManager.openPowerMenu()
  }
}
