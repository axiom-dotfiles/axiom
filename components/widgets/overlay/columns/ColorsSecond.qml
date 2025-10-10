pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules
import qs.components.widgets.overlay.modules.theme

ColumnLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: topCell.requiredVerticalCells + bottomCell.requiredVerticalCells
  property int requiredHorizontalCells: Math.max(topCell.requiredHorizontalCells, bottomCell.requiredHorizontalCells)

  Cell2x2 {
    id: topCell
    topLeftCell: ColorSwatch {
      swatchColor: Theme.base08
      swatchName: "base08"
      swatchSemantic: "error"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base09
      swatchName: "base09"
      swatchSemantic: "warning"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base0A
      swatchName: "base0A"
      swatchSemantic: "info"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base0B
      swatchName: "base0B"
      swatchSemantic: "success"
    }
  }

  Cell2x2 {
    id: bottomCell
    topLeftCell: ColorSwatch {
      swatchColor: Theme.base0C
      swatchName: "base0C"
      swatchSemantic: "accentAlt"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base0D
      swatchName: "base0D"
      swatchSemantic: "accentHighlight"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base0E
      swatchName: "base0E"
      swatchSemantic: "accent"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base0F
      swatchName: "base0F"
      swatchSemantic: "decorative"
    }
  }
}
