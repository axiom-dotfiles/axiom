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
  property var properties

  // -- Configurable Appearance --
  iconText: properties.icon ? properties.icon : "󰍃"
  iconColor: Theme.background
  borderHoverColor: Theme.info
  backgroundColor: properties.backgroundColor ? Theme.resolveColor(properties.backgroundColor) : Theme.accent
  
  // -- Implementation --
  onClicked: ShellManager.openPowerMenu()
}
