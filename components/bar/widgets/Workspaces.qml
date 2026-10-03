pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.bar.widgets.workspaces

// The workspace switcher, laid out as the Workspaces section says: a row of
// 1..count (WorkspaceStrip), or the active row or column of this monitor's
// grid with the whole grid as a popout (WorkspaceGridStrip). It sits on a
// background in the bar's widget style like any other widget, its cells
// (WorkspaceCell, in the same style) inset by the inner spacing within a
// box (filled, tinted or outlined). Without a box the cells sit straight on
// the bar, each underlined itself for underline.
BarWidget {
  id: root

  readonly property int priority: 10
  readonly property bool boxed: ["filled", "tinted", "outline"].includes(barConfig.widgetStyle)
  // Within a box
  readonly property real inset: boxed ? barConfig.widgetSpacing : 0

  hasBackground: true
  // Its box; an underline is each cell's own
  accentColor: boxed ? Theme.resolveColor(properties.backgroundColor) : "transparent"

  implicitWidth: loader.implicitWidth + (isVertical ? 0 : inset * 2)
  implicitHeight: loader.implicitHeight + (isVertical ? inset * 2 : 0)

  Loader {
    id: loader
    anchors.centerIn: parent
    sourceComponent: WorkspacesConfig.grid ? gridStrip : strip
  }

  Component {
    id: strip
    WorkspaceStrip {
      screen: root.screen
      barConfig: root.barConfig
      properties: root.properties
      inset: root.inset
    }
  }

  Component {
    id: gridStrip
    WorkspaceGridStrip {
      screen: root.screen
      popouts: root.popouts
      panel: root.panel
      barConfig: root.barConfig
      properties: root.properties
      inset: root.inset
    }
  }
}
