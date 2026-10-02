pragma ComponentBehavior: Bound
import QtQuick

// What a bar widget sits on, in its bar's widget style (Bars[].widgetFill):
// a fill or outline, or for underline a line along one side. WidgetGroup
// draws one under each widget that has a background, sized to it.
Item {
  id: root

  required property var barConfig
  // The widget's colors on this bar (Bar.widgetColors), or null for none
  property var colors: null

  readonly property string _fill: barConfig.widgetFill
  readonly property bool _boxed: ["filled", "tinted", "outline"].includes(_fill)

  Rectangle {
    anchors.fill: parent
    visible: root._boxed && root.colors !== null
    radius: root.barConfig.radius
    color: root.colors?.fill ?? "transparent"
    border.color: root.colors?.stroke ?? "transparent"
    border.width: root._fill === "outline" ? root.barConfig.outlineWidth : 0
  }

  // Along the side toward the windows (inner) or the screen edge (outer)
  Rectangle {
    readonly property real thickness: root.barConfig.indicatorWidth
    readonly property bool vertical: root.barConfig.vertical
    // The side further from the bar's outer edge, in item coordinates
    readonly property bool farSide: (root.barConfig.indicatorSide === "inner") !== (root.barConfig.right || root.barConfig.bottom)

    visible: root._fill === "underline" && root.colors !== null
    color: root.colors?.indicator ?? "transparent"
    radius: thickness / 2
    x: vertical && farSide ? root.width - thickness : 0
    y: !vertical && farSide ? root.height - thickness : 0
    width: vertical ? thickness : root.width
    height: vertical ? root.height : thickness
  }
}
