// In qs/components/reusable/SizedIconButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config

Rectangle {
  id: button

  // --- Public API ---
  property string iconText: ""
  property string labelText: ""
  property int buttonSize: 120
  property int iconSize: 48
  property int labelSize: Appearance.fontSize
  property int spacing: 8

  // Colors
  property color backgroundColor: Theme.backgroundHighlight
  property color hoverColor: Theme.accent
  property color pressColor: Theme.accentAlt
  property color textColor: Theme.foreground
  property color textHoverColor: Theme.background

  // Border and radius
  property color borderColor: Theme.border
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Appearance.borderRadius

  signal clicked

  implicitWidth: buttonSize
  implicitHeight: buttonSize
  Layout.alignment: Qt.AlignCenter

  border.color: borderColor
  border.width: borderWidth
  radius: borderRadius

  Behavior on color {
    ColorAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: button.spacing

    StyledText {
      id: icon
      text: button.iconText
      textColor: button.textColor
      textSize: button.iconSize
      Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }

    StyledText {
      id: label
      text: button.labelText
      textColor: button.textColor
      textSize: button.labelSize
      font.bold: true
      Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
