// In qs/components/reusable/StyledTextButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

Rectangle {
  id: button

  // --- Public API ---
  property alias text: label.text
  property int textPadding: 8
  
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

  // --- Layout ---
  implicitWidth: label.implicitWidth + (textPadding * 2)
  implicitHeight: label.implicitHeight + textPadding
  Layout.alignment: Qt.AlignVCenter

  // --- Internal Implementation ---
  color: mouseArea.pressed ? pressColor : (mouseArea.hovered ? hoverColor : backgroundColor)
  border.color: borderColor
  border.width: borderWidth
  radius: borderRadius

  Behavior on color {
    ColorAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  StyledText {
    id: label
    anchors.centerIn: parent
    textColor: mouseArea.hovered ? button.textHoverColor : button.textColor
    textSize: Appearance.fontSize
    font.bold: true
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
