// components/reusable/StyledSlider.qml
import QtQuick

import qs.config // Assuming Theme and Appearance are defined here

Item {
  id: root

  // --- Public API ---
  // The main property to bind to for displaying the current state (0.0 to 1.0)
  property real value: 0.0

  // Signals for the parent component to react to user input
  signal moved(real value)   // Emitted continuously while dragging
  signal released(real value) // Emitted when the mouse button is released

  // --- Styling Properties ---
  property color grooveColor: Theme.backgroundHighlight
  property color fillColor: Theme.foreground
  property color handleColor: Theme.foreground
  property int grooveHeight: 4

  // --- Visuals ---
  // Groove (the background track)
  Rectangle {
    id: grooveRect
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.grooveHeight
    radius: height / 2
    color: root.grooveColor
  }

  // Fill (the progress part)
  Rectangle {
    id: fillRect
    anchors.verticalCenter: parent.verticalCenter
    // The width is now directly driven by the public 'value' property
    width: parent.width * root.value
    height: root.grooveHeight
    radius: height / 2
    color: root.fillColor
  }

  // Handle (visual indicator)
  Rectangle {
    id: handleRect
    x: fillRect.width - (width / 2) // Position based on the fill width
    anchors.verticalCenter: parent.verticalCenter
    width: 12
    height: 12
    radius: 6
    color: root.handleColor
    opacity: mouseArea.pressed || root.hovered ? 1 : 0 // Show on interaction
    Behavior on opacity {
      NumberAnimation {
        duration: 150
      }
    }
  }

  // --- Interaction Logic (from your working example) ---
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    property bool isDragging: false

    // This function calculates the ratio and emits the 'moved' signal
    function updatePosition(x) {
      let ratio = Math.max(0, Math.min(1, x / root.width));
      root.moved(ratio);
    }

    onPressed: {
      isDragging = true;
      updatePosition(mouseX);
    }

    onPositionChanged: {
      if (isDragging) {
        updatePosition(mouseX);
      }
    }

    onReleased: {
      if (isDragging) {
        isDragging = false;
        // Emit a final signal on release
        let ratio = Math.max(0, Math.min(1, mouseX / root.width));
        root.released(ratio);
      }
    }
  }
}
