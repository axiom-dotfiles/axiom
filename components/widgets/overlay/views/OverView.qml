pragma ComponentBehavior: Bound
import QtQuick
import qs.components.widgets.overlay.columns

BaseView {
  id: view

  readonly property int requiredVerticalCells: Math.max(col1.requiredVerticalCells, col2.requiredVerticalCells)
  readonly property int requiredHorizontalCells: col1.requiredHorizontalCells + col2.requiredHorizontalCells

  Component.onCompleted: {
    console.log("Overview: " + requiredHorizontalCells + "x" + requiredVerticalCells)
  }

  BaseColumn { id: col1 }
  SettingsPanel { id: col3 }
  ThemeEditor { id: col4 }
  ColorPreview { id: col2 }
}
