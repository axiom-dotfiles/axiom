pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.methods

// The layouts editor on a screen layout (a ScreenLayoutEditor's draft:
// the lock screen's, the greeter's): its modules on a bounded grid of
// columns × rows units inside the screen's outline, which every monitor
// stretches to fill. LockscreenTarget and GreeterTarget name it.
EditTarget {
  id: root

  // The ScreenLayoutEditor being edited
  required property var screenEditor
  // What it is, over its fields in the side panel
  property string description: ""
  readonly property var layout: root.screenEditor.localLayout
  readonly property var grid: GridPlacement.screenGrid(root.layout)

  editor: root.screenEditor.layout
  modules: root.layout ? root.layout.modules : null
  screenBox: root.layout ? ({
      "x": 0,
      "y": 0,
      "w": root.grid.cols,
      "h": root.grid.rows
    }) : null
  fitText: root.layout ? I18n.tr("{0} × {1} units, stretched to fill each monitor", root.grid.cols, root.grid.rows) : ""
  editable: root.layout !== null
}
