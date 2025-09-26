// qs/components/reusable/StyledRectButton.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls // Needed for ToolTip
import QtQuick.Layouts

import qs.config
import qs.components.reusable

Rectangle {
  id: button

  // --- Public API ---
  property string iconText: ""
  property int iconSize: Appearance.fontSize
  property string tooltipText: ""
  property color iconColor: Theme.foreground

  // Colors for different states
  property color hoverColor: Theme.backgroundHighlight
  property color pressColor: Theme.backgroundAlt
  property color backgroundColor: "transparent"

  // Border and radius
  property color borderColor: "transparent"
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Appearance.borderRadius

  // The main signal to notify parent components of a click
  signal clicked

  // --- Layout Properties ---
  Layout.fillHeight: true
  Layout.fillWidth: true
  Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

  // --- Internal Implementation ---

  // The rectangle's color is now bound to the mouse area's state
  color: mouseArea.pressed ? pressColor : (mouseArea.hovered ? hoverColor : backgroundColor)
  border.color: borderColor
  border.width: borderWidth
  radius: borderRadius

  // Add a smooth transition for color changes
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  // The icon displayed in the center of the button
  StyledText {
    anchors.centerIn: parent
    text: button.iconText
    textSize: button.iconSize
    textColor: button.iconColor
    // The font family from StyledText will be used, perfect for icon fonts
  }

  // The interactive area that captures mouse events
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true // This is required for 'hovered' to work
    cursorShape: Qt.PointingHandCursor // Standard cursor for buttons

    // When the area is clicked, emit the button's 'clicked' signal
    onClicked: {
      button.clicked();
    }
  }

  // A tooltip that appears on hover, if tooltipText is provided
  ToolTip {
    text: button.tooltipText
    // Only show the tooltip if the button is hovered and has text to display
    // visible: mouseArea.hovered && button.tooltipText !== "" ? true : false
    visible: false
    delay: 500 // A small delay before showing
  }
}
