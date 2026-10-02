pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.reusable

// One screen's border (Appearance.screenBorder): an edge strip per side
// (BorderPanel), reserving `frameWidth`, and a concave corner piece
// (CornerPiece) in each corner joining their inner strokes. A solid bar's
// edge draws only the stroke, so the bar shows through.
Item {
  id: root

  property var screen: null
  property int frameWidth: Appearance.screenMargin
  property int innerBorderRadius: Appearance.borderRadius
  property color frameColor: Theme.background
  property color innerStrokeColor: Theme.foreground
  property int strokeWidth: Appearance.borderWidth
  // The corner's curve plus its stroke
  readonly property int cornerSize: root.innerBorderRadius + root.strokeWidth

  // Corners sit in the space left once every edge is reserved, so a
  // floating bar or a dock (inside the border, reserving their own space)
  // would push them in past it. Pull them back out to the border's corners.
  readonly property var edges: Bar.edgesFor(root.screen)
  function cornerMargin(edge) {
    const docks = DockManager.zoneOn(root.screen?.name ?? "", edge);
    const bar = root.edges[edge];
    if (!bar?.floating || !bar.reserveSpace)
      return -root.strokeWidth - docks;
    // A transparent bar reserves gaps_out less (see BarPanel)
    const gap = bar.background === "transparent" ? (HyprlandManager.gapsOut[edge] ?? 0) : 0;
    return -(bar.extent - gap) - docks;
  }
  // A solid bar's strip lies over the bar's inner part (see
  // BarPanel.reservedZone): there it draws only its stroke, past the bar,
  // so the bar and its widgets show through
  function frameColorFor(edge) {
    const bar = root.edges[edge];
    return bar && bar.background === "solid" && bar.reserveSpace ? "transparent" : root.frameColor;
  }

  // An edge strip per side
  Variants {
    model: ["top", "bottom", "left", "right"]

    delegate: BorderPanel {
      required property string modelData
      edge: modelData
      screen: root.screen
      frameWidth: root.frameWidth
      innerBorderRadius: root.innerBorderRadius
      frameColor: root.frameColorFor(modelData)
      endFillColor: root.frameColor
      innerStrokeColor: root.innerStrokeColor
      strokeWidth: root.strokeWidth
    }
  }

  // A corner piece in each corner
  Variants {
    model: [
      {
        "isLeft": true,
        "isTop": true
      },
      {
        "isLeft": false,
        "isTop": true
      },
      {
        "isLeft": true,
        "isTop": false
      },
      {
        "isLeft": false,
        "isTop": false
      }
    ]

    delegate: PanelWindow {
      id: corner

      required property var modelData
      readonly property bool isLeft: modelData.isLeft
      readonly property bool isTop: modelData.isTop

      screen: root.screen
      anchors {
        left: corner.isLeft
        right: !corner.isLeft
        top: corner.isTop
        bottom: !corner.isTop
      }
      margins {
        left: corner.isLeft ? root.cornerMargin("left") : 0
        right: corner.isLeft ? 0 : root.cornerMargin("right")
        top: corner.isTop ? root.cornerMargin("top") : 0
        bottom: corner.isTop ? 0 : root.cornerMargin("bottom")
      }
      implicitWidth: root.cornerSize
      implicitHeight: root.cornerSize
      color: "transparent"
      mask: Region {}
      aboveWindows: true
      WlrLayershell.namespace: "axiom-border"

      CornerPiece {
        borderRadius: root.innerBorderRadius
        fillColor: root.frameColor
        strokeColor: root.innerStrokeColor
        strokeWidth: root.strokeWidth
        isLeft: corner.isLeft
        isTop: corner.isTop
      }
    }
  }
}
