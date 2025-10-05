// PowerMenuButton.qml
pragma ComponentBehavior: Bound
import qs.config
import qs.services
import qs.components.widgets.bar
import qs.components.reusable

StyledRectButton {
    id: component
    
    // -- Signals --
    // null
    
    // -- Public API --
    property var barConfig
    property var popouts
    property var panel
    property var screen
    
    // -- Configurable Appearance --
    iconText: "󰣇"
    iconColor: Theme.background
    borderHoverColor: Theme.info
    backgroundColor: Theme.info
    
    // -- Implementation --
    onClicked: ShellManager.openPowerMenu()
}
