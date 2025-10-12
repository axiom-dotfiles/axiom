pragma ComponentBehavior: Bound
import QtQuick
import qs.components.widgets.overlay.columns

BaseView {
  id: view

  // readonly property int requiredVerticalCells: Math.max(col1.requiredVerticalCells, col2.requiredVerticalCells)
  // readonly property int requiredHorizontalCells: col1.requiredHorizontalCells + col2.requiredHorizontalCells

  SettingsPanel {}
  ThemeEditor {}
  ColorPreview {}
}
