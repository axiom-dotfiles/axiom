pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.bar.widgets.workspaces

// The workspace switcher, laid out as the Workspaces section says: a row of
// 1..count (WorkspaceStrip), or the active row or column of this monitor's
// grid with the whole grid as a popout (WorkspaceGridStrip).
BarWidget {
  id: root

  readonly property int priority: 10

  implicitWidth: loader.implicitWidth
  implicitHeight: loader.implicitHeight

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
    }
  }
}
