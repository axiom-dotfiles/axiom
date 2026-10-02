pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.reusable

// Base for icon + label bar modules: the inputs every module gets from
// BarWidgetHost, orientation from the bar, and the configured colors (modules
// override backgroundColor for their states; a bar with widget backgrounds
// off draws none, and its own text color).
//
// Clicks: set `clickable` (and `acceptedButtons` beyond the left one) and
// handle clicked(button); a clickable widget shows a pointer and dims while
// pressed, and does nothing while `hidden`. Set `scrollable` to get
// scrolled(steps), +1 per wheel notch up. `dim` fades the widget (e.g. stale
// data, a pulse) on top of the press.
IconTextWidget {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  property bool clickable: false
  property int acceptedButtons: Qt.LeftButton
  property bool scrollable: false
  property real dim: 1
  readonly property bool pressed: clickArea.pressed
  // The pointer is over it (an edge menu this opened stays open meanwhile)
  readonly property bool hovered: clickArea.containsMouse

  signal clicked(int button)
  signal scrolled(real steps)

  isVertical: barConfig.vertical
  crossSize: barConfig.widgetSize
  // Sized by the bar, not the Widget section (that's for panels)
  padding: barConfig.widgetPadding
  radius: barConfig.radius
  fontSize: barConfig.fontSize
  // The icon's gap to its label (6 px at the default inner spacing of 4)
  spacing: barConfig.widgetSpacing * 1.5
  showBackground: barConfig.widgetBackgrounds
  backgroundColor: Theme.resolveColor(properties.backgroundColor)
  foregroundColor: Bar.widgetForeground(barConfig, properties.foregroundColor)
  opacity: (root.pressed ? 0.8 : 1) * root.dim

  MouseArea {
    id: clickArea
    anchors.fill: parent
    enabled: (root.clickable || root.scrollable) && !root.hidden
    hoverEnabled: true
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: root.clickable ? root.acceptedButtons : Qt.NoButton
    onClicked: mouse => root.clicked(mouse.button)
    onWheel: wheel => {
      if (root.scrollable)
        root.scrolled(wheel.angleDelta.y / 120);
      else
        wheel.accepted = false;
    }
  }
}
