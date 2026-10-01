pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// The layouts editor on the built-in lock screen (LockManager's draft of
// Lockscreen.layout): its modules on a bounded grid of columns × rows
// units inside the screen's outline, which every monitor's lock surface
// stretches to fill.
EditTarget {
  id: root

  readonly property var layout: LockManager.localLayout
  readonly property var grid: LockscreenConfig.gridOf(root.layout)

  editor: LockManager.layout
  modules: root.layout ? root.layout.modules : null
  icon: "lock"
  title: I18n.tr("Lock screen")
  screenBox: root.layout ? ({
      "x": 0,
      "y": 0,
      "w": root.grid.cols,
      "h": root.grid.rows
    }) : null
  fitText: LockscreenConfig.mode !== "quickshell" ? I18n.tr("Only the built-in locker shows this layout") : root.layout ? I18n.tr("{0} × {1} units, stretched to fill each monitor", root.grid.cols, root.grid.rows) : ""
  fitWarning: LockscreenConfig.mode !== "quickshell"
  editable: root.layout !== null
}
