pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.reusable

// One workspace on the bar, in the bar's widget style (Bar.cellColors): a
// filled, tinted or outlined box inside the widget's own; on a bar whose
// widgets have no boxes, its number (or a dot) straight on the bar, under a
// line of its color for underline. Shows an app icon or a glyph instead of
// the label when given one.
Item {
  id: root

  required property var barConfig
  // Bar.cellColors for its state
  required property var look
  required property bool isActive
  // Across the bar, and along it (`restLength` when not widened)
  required property real thickness
  required property real length
  property real restLength: length
  property real radius: 0
  // "numbers" or "dots"
  property string labels: "numbers"
  property string label: ""
  property string iconPath: ""
  property string glyph: ""
  property bool clickable: true
  // Off until its inputs have settled (a popout's payload lands after
  // creation), so it doesn't animate from fallbacks
  property bool animated: true
  // Its box and underline while active are drawn by the row's sliding
  // ActiveCellIndicator instead
  property bool indicated: false
  readonly property bool _ownActive: root.isActive && !root.indicated

  signal clicked

  readonly property bool isVertical: barConfig.vertical
  readonly property bool boxed: ["filled", "tinted", "outline"].includes(barConfig.widgetStyle)
  readonly property bool hovered: cellArea.containsMouse

  width: isVertical ? thickness : length
  height: isVertical ? length : thickness

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.hovered && !root.isActive ? Theme.backgroundHighlight : root.isActive && !root._ownActive ? Qt.alpha(root.look.fill, 0) : root.look.fill
    border.color: root.isActive && !root._ownActive ? Qt.alpha(root.look.stroke, 0) : root.look.stroke
    border.width: root.barConfig.widgetStyle === "outline" ? root.barConfig.outlineWidth : 0

    Behavior on color {

      enabled: root.animated
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
    Behavior on border.color {
      enabled: root.animated
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  // Underline: along the side the bar's widget lines take
  Rectangle {
    readonly property real lineWidth: root.barConfig.lineWidth
    readonly property bool farSide: (root.barConfig.lineSide === "inner") !== (root.barConfig.right || root.barConfig.bottom)

    visible: root.barConfig.widgetStyle === "underline"
    color: root.isActive && !root._ownActive ? Qt.alpha(root.look.indicator, 0) : root.look.indicator
    radius: lineWidth / 2
    x: root.isVertical && farSide ? root.width - lineWidth : 0
    y: !root.isVertical && farSide ? root.height - lineWidth : 0
    width: root.isVertical ? lineWidth : root.width
    height: root.isVertical ? root.height : lineWidth

    Behavior on color {

      enabled: root.animated
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  // A dot (a pill when widened) for a cell with no box of its own to show
  Rectangle {
    readonly property real size: Math.max(4, Math.round(root.thickness * 0.35))
    readonly property real along: size + root.length - root.restLength

    anchors.centerIn: parent
    visible: !root.boxed && root.labels === "dots" && root.iconPath === "" && root.glyph === ""
    width: root.isVertical ? size : along
    height: root.isVertical ? along : size
    radius: size / 2
    color: root.look.content

    Behavior on color {

      enabled: root.animated
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  StyledIcon {
    anchors.centerIn: parent
    visible: root.glyph !== ""
    text: root.glyph
    font.pixelSize: root.barConfig.fontSize * 1.2
    color: root.look.content
  }

  Image {
    anchors.centerIn: parent
    width: root.thickness * 0.65
    height: width
    sourceSize: Qt.size(64, 64)
    source: root.glyph === "" ? root.iconPath : ""
    visible: root.glyph === "" && root.iconPath !== ""
    opacity: root.boxed || root.isActive ? 1 : 0.7
  }

  StyledText {
    anchors.centerIn: parent
    visible: root.labels === "numbers" && root.glyph === "" && root.iconPath === ""
    text: root.label
    textColor: root.look.content
    textSize: root.barConfig.fontSize - 1
    font.bold: root.isActive && !root.boxed

    Behavior on color {

      enabled: root.animated
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
  }

  MouseArea {
    id: cellArea
    anchors.fill: parent
    enabled: root.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Behavior on width {

    enabled: root.animated
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Easing.OutCubic
    }
  }
  Behavior on height {
    enabled: root.animated
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Easing.OutCubic
    }
  }
}
