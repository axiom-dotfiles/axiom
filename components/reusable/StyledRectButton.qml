// qs/components/reusable/StyledRectButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

Rectangle {
  id: component

  // -- Signals --
  signal clicked

  // -- Public API --
  property string iconText: ""
  property string tooltipText: ""

  // -- Configurable Appearance --
  property alias iconSize: iconLabel.textSize
  property alias iconColor: iconLabel.textColor
  property color backgroundColor: Theme.backgroundAlt
  property color hoverColor: component.backgroundColor
  property color pressColor: component.backgroundColor
  property color borderColor: "transparent"
  property color borderHoverColor: component.borderColor
  property color borderPressColor: component.borderColor
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Widget.radius

  property string badgeText: ""
  property bool badgeVisible: component.badgeText !== ""
  property color badgeBackgroundColor: Theme.error
  property color badgeTextColor: Theme.background

  // -- Implementation --
  // UHH maybe having one button for layouts and not layouts is not the move
  Layout.fillHeight: true
  Layout.fillWidth: true
  Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
  // TODO: different bar extents break this
  implicitWidth: Widget.height
  implicitHeight: Widget.height

  color: mouseArea.pressed ? component.pressColor : (mouseArea.containsMouse ? component.hoverColor : component.backgroundColor)
  border.color: mouseArea.pressed ? component.borderPressColor : (mouseArea.containsMouse ? component.borderHoverColor : component.borderColor)
  border.width: component.borderWidth
  radius: component.borderRadius

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animNormal
    }
  }

  Behavior on border.color {
    ColorAnimation {
      duration: Appearance.animNormal
    }
  }

  StyledIcon {
    id: iconLabel
    anchors.centerIn: parent
    text: component.iconText
    textSize: Appearance.fontSize
    textColor: Theme.foreground
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: component.clicked()
  }

  LazyLoader {
    active: mouseArea.containsMouse && component.tooltipText !== ""
    StyledToolTip {
      target: component
      text: component.tooltipText
    }
  }

  Rectangle {
    id: badge
    visible: component.badgeVisible
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: -2
    anchors.rightMargin: -2
    implicitWidth: Math.max(14, badgeLabel.implicitWidth + 6)
    implicitHeight: 14
    radius: height / 2
    color: component.badgeBackgroundColor

    StyledText {
      id: badgeLabel
      anchors.centerIn: parent
      text: component.badgeText
      textSize: Appearance.fontSize - 4
      textColor: component.badgeTextColor
    }
  }
}
