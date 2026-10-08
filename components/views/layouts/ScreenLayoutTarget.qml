pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.methods

// The layouts editor on a screen layout (a ScreenLayoutEditor's draft:
// the desktop's, the lock screen's, the greeter's): its modules on a
// bounded grid of columns × rows units inside the screen's outline, which
// every monitor stretches to fill. DesktopTarget, LockscreenTarget and
// GreeterTarget name it and hand in its editor and field groups.
EditTarget {
  id: root

  // The ScreenLayoutEditor being edited
  required property var screenEditor
  // What it is, over its fields in the side panel
  property string description: ""
  // Its layout's own fields in groups (`x-group`), for the side panel
  required property var fieldGroups
  // Whether Show on screen is offered (the editor's startPreview): not for
  // a draft that already shows live (`previewSection`)
  readonly property bool canPreview: root.screenEditor.previewSection === ""
  readonly property var layout: root.screenEditor.localLayout
  readonly property var grid: GridPlacement.screenGrid(root.layout)
  // The fit line for a layout stretched to each monitor, "" without one
  readonly property string stretchText: root.layout ? I18n.tr("{0} × {1} units, stretched to fill each monitor", root.grid.cols, root.grid.rows) : ""

  editor: root.screenEditor.layout
  modules: root.layout ? root.layout.modules : null
  screenBox: root.layout ? ({
      "x": 0,
      "y": 0,
      "w": root.grid.cols,
      "h": root.grid.rows
    }) : null
  fitText: root.stretchText
  editable: root.layout !== null
}
