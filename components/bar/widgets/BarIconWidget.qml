pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.reusable

// Base for icon + label bar modules: the inputs every module gets from
// BarWidgetHost, orientation from the bar, and the configured colors (modules
// override backgroundColor for their states)
IconTextWidget {
  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  isVertical: barConfig.vertical
  crossSize: barConfig.widgetSize
  // Sized by the bar, not the Widget section (that's for panels)
  padding: barConfig.widgetPadding
  radius: barConfig.radius
  fontSize: barConfig.fontSize
  // The icon's gap to its label (6 px at the default inner spacing of 4)
  spacing: barConfig.widgetSpacing * 1.5
  backgroundColor: Theme.resolveColor(properties.backgroundColor)
  foregroundColor: Theme.resolveColor(properties.foregroundColor)
}
