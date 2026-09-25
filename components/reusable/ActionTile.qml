import QtQuick
import Quickshell

import qs.config

// An action or toggle tile: an icon well over a label. Hovered (or
// `selected`, for keyboard focus) it takes `tone`; `active` (a toggle
// that's on, an action waiting to be confirmed) fills it with
// `activeColor`, and with a `countdown` a bar along the bottom runs down
// over that many ms. The label shows only where it fits whole; otherwise
// the tile is icon-only with the label as a tooltip.
Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property bool active: false
  property color activeColor: Theme.accent
  // Colour of the hover / selected highlight
  property color tone: root.activeColor
  // Highlighted as if hovered (keyboard selection)
  property bool selected: false
  // Allow the label at all (off: always icon-only)
  property bool showLabel: true
  // While active, run a bar down over this many ms (0: none)
  property int countdown: 0

  signal clicked
  signal hovered

  readonly property bool hot: root.selected || area.containsMouse
  readonly property color contentColor: root.active ? Theme.background : root.hot ? root.tone : Theme.foreground
  readonly property bool _labelShown: root.showLabel && root.label !== "" && labelMetrics.advanceWidth <= root.width - Widget.spacing * 2 && root.height >= Appearance.fontSize * 4.5
  // The well fills most of what the label leaves
  readonly property real _wellSize: Math.max(Appearance.fontSize * 1.6, Math.min(root.width - Widget.spacing * 2, root.height - Widget.spacing * 2 - (root._labelShown ? labelText.implicitHeight + Widget.spacing : 0)) * (root._labelShown ? 0.7 : 0.66))

  radius: Appearance.borderRadius
  color: root.active ? root.activeColor : root.hot ? Theme.backgroundHighlight : Theme.backgroundAlt
  border.color: root.active ? root.activeColor : root.hot ? root.tone : Theme.border
  border.width: Appearance.borderWidth
  clip: true

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }
  Behavior on border.color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  TextMetrics {
    id: labelMetrics
    text: root.label
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 1
  }

  Column {
    anchors.centerIn: parent
    spacing: Widget.spacing

    // Holds the well's resting size, so the well grows on hover without
    // moving the label. It grows by size, not scale: icons render natively
    // (see StyledIcon), and a scaled native glyph is resampled and blurs
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: root._wellSize
      height: width

      Rectangle {
        id: well
        anchors.centerIn: parent
        width: root._wellSize * (root.hot && !root.active ? 1.06 : 1)
        height: width
        radius: Math.min(Appearance.borderRadius * 1.5, width / 2)
        color: root.active ? Qt.rgba(0, 0, 0, 0.12) : root.hot ? Qt.alpha(root.tone, 0.16) : Theme.background

        Behavior on color {
          ColorAnimation {
            duration: Appearance.animFast
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: Appearance.animFast
            easing.type: Appearance.easing
          }
        }

        StyledIcon {
          anchors.centerIn: parent
          text: root.icon
          textColor: root.contentColor
          textSize: well.width * 0.5
          fill: root.hot || root.active ? 1 : 0
        }
      }
    }

    StyledText {
      id: labelText
      visible: root._labelShown
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.width - Widget.spacing * 2
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.label
      textColor: root.contentColor
      textSize: Appearance.fontSize - 1
    }
  }

  // Time left while active
  Rectangle {
    id: countdownBar
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    height: 3
    color: Theme.background
    opacity: 0.6
    visible: root.active && root.countdown > 0
    width: 0

    NumberAnimation {
      id: drain
      target: countdownBar
      property: "width"
      from: root.width
      to: 0
      duration: root.countdown
    }
  }

  onActiveChanged: {
    drain.stop();
    if (root.active && root.countdown > 0)
      drain.start();
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered()
    onClicked: root.clicked()
  }

  LazyLoader {
    active: area.containsMouse && !root._labelShown && root.label !== ""
    StyledToolTip {
      target: root
      text: root.label
    }
  }
}
