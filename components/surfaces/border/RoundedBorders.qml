pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
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

  // Corners sit in the space left once every edge is reserved, so a bar
  // or a dock inside the border (reserving their own space)
  // would push them in past it. Pull them back out to the border's corners.
  readonly property var edges: Bar.edgesFor(root.screen)
  function cornerMargin(edge) {
    const docks = DockManager.zoneOn(root.screen?.name ?? "", edge);
    const bar = root.edges[edge];
    if (!bar?.insideBorder || !bar.reserveSpace)
      return -root.strokeWidth - docks;
    // As far as the bar reserves (see BarPanel)
    const gap = Bar.reserveTrim(bar, HyprlandManager.gapsOut[edge] ?? 0);
    return -(bar.extent - gap) - docks;
  }
  // How far in from a screen edge the frame's inner edge lies: past a solid
  // bar reserving that edge (the strip is arranged after it, see
  // BarPanel), else the frame's own width
  function innerInset(edge) {
    const bar = root.edges[edge];
    const panel = bar?.solid && bar.reserveSpace ? ShellManager.barOn(root.screen?.name ?? "", bar.location) : null;
    return (panel?.reservedZone ?? 0) + root.frameWidth;
  }

  // A solid bar's strip lies over the bar's inner part (see
  // BarPanel.reservedZone): there it draws only its stroke, past the bar,
  // so the bar and its widgets show through
  function frameColorFor(edge) {
    const bar = root.edges[edge];
    return bar && bar.solid && bar.reserveSpace ? "transparent" : root.frameColor;
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

  // The border's shadow or glow (the BarStyle section's, as the bars
  // cast): the frame's shape blurred and kept only inside it, so it falls
  // on the windows all the way round. One window over the whole screen,
  // so it runs unbroken past the strips and corners. Its layer rule
  // (`order = 11`) stacks it under every other axiom surface, the overlay
  // backdrop included, so bars inside the border stay clear of it.
  PanelWindow {
    id: shadowWindow

    readonly property var look: BarStyle.values
    readonly property real left: root.innerInset("left")
    readonly property real right: root.innerInset("right")
    readonly property real top: root.innerInset("top")
    readonly property real bottom: root.innerInset("bottom")
    // The stroke's inner side, round the corner pieces' arcs
    readonly property real radius: Math.max(0, root.innerBorderRadius - root.strokeWidth)

    visible: look.shadow !== "none"
    screen: root.screen
    anchors {
      left: true
      right: true
      top: true
      bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    WlrLayershell.namespace: "axiom-border-shadow"

    // The inside of the frame
    Item {
      id: interior
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        x: shadowWindow.left
        y: shadowWindow.top
        width: Math.max(0, parent.width - shadowWindow.left - shadowWindow.right)
        height: Math.max(0, parent.height - shadowWindow.top - shadowWindow.bottom)
        radius: shadowWindow.radius
        color: "black"
      }
    }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: interior
      }

      // The frame, casting the shadow inward (it's cut away above)
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: Bar.shadowColor(shadowWindow.look)
          shadowBlur: 1
          blurMax: shadowWindow.look.shadowSize
        }

        ShapePath {
          fillColor: "black"
          fillRule: ShapePath.OddEvenFill
          strokeColor: "transparent"
          strokeWidth: 0

          PathSvg {
            readonly property real w: shadowWindow.width
            readonly property real h: shadowWindow.height
            readonly property real x0: shadowWindow.left
            readonly property real y0: shadowWindow.top
            readonly property real x1: w - shadowWindow.right
            readonly property real y1: h - shadowWindow.bottom
            readonly property real r: Math.min(shadowWindow.radius, (x1 - x0) / 2, (y1 - y0) / 2)

            path: `M 0 0 L ${w} 0 L ${w} ${h} L 0 ${h} Z M ${x0 + r} ${y0} L ${x1 - r} ${y0} A ${r} ${r} 0 0 1 ${x1} ${y0 + r} L ${x1} ${y1 - r} A ${r} ${r} 0 0 1 ${x1 - r} ${y1} L ${x0 + r} ${y1} A ${r} ${r} 0 0 1 ${x0} ${y1 - r} L ${x0} ${y0 + r} A ${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`
          }
        }
      }
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
