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
      swatchColor: Theme.base00
      swatchName: "base00"
      swatchSemantic: "bg0"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base01
      swatchName: "base01"
      swatchSemantic: "bg1"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base02
      swatchName: "base02"
      swatchSemantic: "bg2"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base03
      swatchName: "base03"
      swatchSemantic: "bg3"
    }
  }

  Cell2x2 {
    id: bottomCell
    topLeftCell: ColorSwatch {
      swatchColor: Theme.base04
      swatchName: "base04"
      swatchSemantic: "fg4"
    }
    topRightCell: ColorSwatch {
      swatchColor: Theme.base05
      swatchName: "base05"
      swatchSemantic: "fg3"
    }
    bottomLeftCell: ColorSwatch {
      swatchColor: Theme.base06
      swatchName: "base06"
      swatchSemantic: "fg2"
    }
    bottomRightCell: ColorSwatch {
      swatchColor: Theme.base07
      swatchName: "base07"
      swatchSemantic: "fg1"
    }
  }

  // CellVert1x1 {
  //   rightCell: ColorSwatch {
  //     swatchColor: Theme.base00
  //     swatchName: "base00"
  //   }
  //   leftCell: Rectangle {
  //     color: Theme.accentAlt
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  // }

  // CellHoriz2x1 {
  //   topLeft: Rectangle {
  //     color: Theme.accent
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  //   topRight: Rectangle {
  //     color: Theme.accent
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  //   bottomCell: Rectangle {
  //     color: Theme.accentAlt
  //     anchors.fill: parent
  //     radius: Appearance.borderRadius
  //   }
  // }

  // Cell {
  //   cell: Media {}
  // }
}
