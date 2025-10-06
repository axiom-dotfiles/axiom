pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.widgets.overlay.layouts
import qs.components.widgets.overlay.modules

ColumnLayout {
  spacing: Menu.cardSpacing

  property int requiredVerticalCells: topCell.requiredVerticalCells + bottomCell.requiredVerticalCells
  property int requiredHorizontalCells: Math.max(topCell.requiredHorizontalCells, bottomCell.requiredHorizontalCells)

  Cell2x2 {
    id: topCell
    topLeftCell: ColorSwatch {
      swatchColor: Theme.base08
      swatchName: "base08"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base09
      swatchName: "base09"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base0A
      swatchName: "base0A"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base0B
      swatchName: "base0B"
    }
  }

  Cell2x2 {
    id: bottomCell
    topLeftCell: ColorSwatch {
      swatchColor: Theme.base0C
      swatchName: "base0C"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base0D
      swatchName: "base0D"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base0E
      swatchName: "base0E"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base0F
      swatchName: "base0F"
    }
  }
}
