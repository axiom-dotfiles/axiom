pragma ComponentBehavior: Bound
import QtQuick

// Base for bar widgets that draw their own content (icon + label widgets
// extend BarIconWidget instead): the inputs every widget gets from
// BarWidgetHost, and its orientation from the bar
Item {
  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  readonly property bool isVertical: barConfig.vertical
}
