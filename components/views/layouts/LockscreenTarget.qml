pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// The layouts editor on the built-in lock screen (LockManager's draft of
// Lockscreen.layout).
ScreenLayoutTarget {
  id: root

  screenEditor: LockManager.editor
  icon: "lock"
  title: I18n.tr("Lock screen")
  description: I18n.tr("What the built-in locker shows. Modules here can't open apps or run anything.")
  fitText: LockscreenConfig.mode !== "quickshell" ? I18n.tr("Only the built-in locker shows this layout") : root.layout ? I18n.tr("{0} × {1} units, stretched to fill each monitor", root.grid.cols, root.grid.rows) : ""
  fitWarning: LockscreenConfig.mode !== "quickshell"
}
