pragma ComponentBehavior: Bound
import QtQuick

// What the layouts editor edits (OverlayManager.editTarget), as its canvas
// and inspector show it: PageTarget, MenuTarget, LockscreenTarget. See
// GridCanvas for what each field draws.
QtObject {
  // The grid being edited
  property var editor: null
  // Its modules, or null when there's nothing to edit (a tool page)
  property var modules: null
  property string icon: "dashboard"
  property string title: ""
  property string emptyText: ""
  // Drawn around the grid: an edge, a screen box in units and its size in
  // px, a band along the edge, other menus
  property string edge: ""
  property var screenBox: null
  property var screenSize: null
  property real reservedDepth: 0
  property string reservedLabel: ""
  property var ghosts: []
  // How it fits, under the canvas title
  property string fitText: ""
  property bool fitWarning: false
  // Whether modules can be added (else `notEditableHint` in the inspector)
  property bool editable: false
  property string notEditableHint: ""
}
