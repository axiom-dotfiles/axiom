pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

// A window's blur region (BackgroundEffect.blurRegion, where the compositor
// blurs only what a window asks: supports.blurRegion), from `pieces` in the
// window's coordinates (SurfaceOutline.blurRegion, placed by placeRegion):
// each a rect with rounded corners, less its own cuts. Modelled by count, so
// pieces changing as a surface slides update the regions there, never
// remake them.
Region {
  id: root

  property var pieces: []

  regions: pieceRegions.instances

  property Variants _pieces: Variants {
    id: pieceRegions
    model: root.pieces.map((_, i) => i)

    delegate: Region {
      id: piece
      required property int modelData
      readonly property var spec: root.pieces[piece.modelData] ?? null
      readonly property var cuts: piece.spec?.cuts ?? []
      x: piece.spec?.x ?? 0
      y: piece.spec?.y ?? 0
      width: piece.spec?.width ?? 0
      height: piece.spec?.height ?? 0
      topLeftRadius: piece.spec?.topLeft ?? 0
      topRightRadius: piece.spec?.topRight ?? 0
      bottomLeftRadius: piece.spec?.bottomLeft ?? 0
      bottomRightRadius: piece.spec?.bottomRight ?? 0
      regions: cutRegions.instances

      property Variants _cuts: Variants {
        id: cutRegions
        model: piece.cuts.map((_, i) => i)

        delegate: Region {
          id: cut
          required property int modelData
          readonly property var spec: piece.cuts[cut.modelData] ?? null
          shape: cut.spec?.ellipse ? RegionShape.Ellipse : RegionShape.Rect
          intersection: Intersection.Subtract
          x: cut.spec?.x ?? 0
          y: cut.spec?.y ?? 0
          width: cut.spec?.width ?? 0
          height: cut.spec?.height ?? 0
          radius: cut.spec?.radius ?? 0
        }
      }
    }
  }
}
