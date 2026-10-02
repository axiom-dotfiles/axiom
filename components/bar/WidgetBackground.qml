pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

import qs.config
import qs.components.methods

// What a bar widget sits on, in its bar's widget style (widgetStyle,
// widgetShape): a fill or outline shaped by its caps (BarShapes), or for
// underline a line along one side. Its hover outline and the bar editor's
// highlight take the same shape. WidgetGroup draws one under each widget
// with a background, and one under each merged run.
Item {
  id: root

  required property var barConfig
  // The colors to draw in (Bar.widgetColors), or null for none
  property var colors: null
  property string startCap: "round"
  property string endCap: "round"
  // Ends that meet a powerline neighbour edge to edge (BarShapes.segment)
  property bool seamStart: false
  property bool seamEnd: false
  // Corner radius of round caps: the bar's widget radius, unless it
  // reaches a floating bar's island end and follows its corners
  property real radius: barConfig.radius
  // A clickable widget under the pointer (its hoverOutline)
  property bool hovered: false
  // The bar editor's selected widget
  property bool highlighted: false

  readonly property string _fill: barConfig.widgetStyle
  readonly property bool _boxed: ["filled", "tinted", "outline"].includes(_fill)

  // The shape in one fill and stroke: a Rectangle when both ends are
  // alike and rounded (or square), else a path
  component ShapedBox: Item {
    id: box

    required property var bar
    required property real radius
    required property string startCap
    required property string endCap
    property bool seamStart: false
    property bool seamEnd: false
    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    readonly property bool vertical: bar.vertical
    readonly property real across: vertical ? width : height
    readonly property real length: vertical ? height : width
    readonly property real rectRadius: {
      if (startCap !== endCap || seamStart || seamEnd)
        return -1;
      switch (startCap) {
      case "round":
        return box.radius;
      case "capsule":
        return across / 2;
      case "flat":
        return 0;
      default:
        return -1;
      }
    }

    anchors.fill: parent

    Rectangle {
      anchors.fill: parent
      visible: box.rectRadius >= 0
      radius: Math.max(0, box.rectRadius)
      color: box.fillColor
      border.color: box.strokeColor
      border.width: box.strokeWidth
    }

    Loader {
      anchors.fill: parent
      active: box.visible && box.rectRadius < 0 && box.width > 0 && box.height > 0
      sourceComponent: Shape {
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          fillColor: box.fillColor
          strokeColor: box.strokeWidth > 0 ? box.strokeColor : "transparent"
          strokeWidth: box.strokeWidth
          joinStyle: ShapePath.MiterJoin

          // Inset by half the stroke, which is centred on the path
          PathSvg {
            path: BarShapes.path(box.length, box.across, box.radius, box.startCap, box.endCap, box.vertical, box.strokeWidth / 2, box.seamStart, box.seamEnd)
          }
        }
      }
    }
  }

  ShapedBox {
    visible: root._boxed && root.colors !== null
    bar: root.barConfig
    radius: root.radius
    startCap: root.startCap
    endCap: root.endCap
    seamStart: root.seamStart
    seamEnd: root.seamEnd
    fillColor: root.colors?.fill ?? "transparent"
    strokeColor: root.colors?.stroke ?? "transparent"
    strokeWidth: root._fill === "outline" ? root.barConfig.outlineWidth : 0
  }

  // Along the side toward the windows (inner) or the screen edge (outer)
  Rectangle {
    readonly property real thickness: root.barConfig.lineWidth
    readonly property bool vertical: root.barConfig.vertical
    // The side further from the bar's outer edge, in item coordinates
    readonly property bool farSide: (root.barConfig.lineSide === "inner") !== (root.barConfig.right || root.barConfig.bottom)

    visible: root._fill === "underline" && root.colors !== null
    color: root.colors?.indicator ?? "transparent"
    radius: thickness / 2
    x: vertical && farSide ? root.width - thickness : 0
    y: !vertical && farSide ? root.height - thickness : 0
    width: vertical ? thickness : root.width
    height: vertical ? root.height : thickness
  }

  ShapedBox {
    visible: root.highlighted
    bar: root.barConfig
    radius: root.radius
    startCap: root.startCap
    endCap: root.endCap
    seamStart: root.seamStart
    seamEnd: root.seamEnd
    fillColor: Qt.alpha(Theme.accent, 0.15)
    strokeColor: Theme.accent
    strokeWidth: 2
  }

  ShapedBox {
    // Built only while it shows, fading out included
    visible: strokeColor.a > 0
    bar: root.barConfig
    radius: root.radius
    startCap: root.startCap
    endCap: root.endCap
    seamStart: root.seamStart
    seamEnd: root.seamEnd
    strokeColor: root.hovered ? Theme.border : Qt.alpha(Theme.border, 0)
    strokeWidth: Appearance.borderWidth

    Behavior on strokeColor {
      ColorAnimation {
        duration: Appearance.animNormal
      }
    }
  }
}
