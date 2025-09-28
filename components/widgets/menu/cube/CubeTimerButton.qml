// qs/components/widgets/CubeTimerButton.qml
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
  id: root

  //=========================================================================
  //== Public API
  //=========================================================================
  // -- Properties
  property bool isRunning: false // Input: Is the parent timer running?
  property int readyDelay: 500   // Input: How long to hold before it's "ready"
  property string buttonText: ""  // Input: The text to display (e.g., the time)
  property color buttonTextColor: "black" // Input: Color for the text

  property color idleColor: "#f0f0f0"
  property color pressedColor: "#c0c0c0"
  property color readyColor: "#66ff66" // A green to indicate "ready to start"
  property color activeColor: "#ff6666" // A red to indicate "stop"

  // Font properties for customization
  property int fontSize: 72
  property bool fontBold: true
  property string fontFamily: "sans-serif"

  // -- Signals
  signal startTimer
  signal stopTimer

  //=========================================================================
  //== State
  //=========================================================================
  property bool isReady: false // Internal state: True when held for readyDelay

  //=========================================================================
  //== Timers
  //=========================================================================
  Timer {
    id: readyTimer
    interval: root.readyDelay
    repeat: false
    onTriggered: {
      // This fires only when the button has been held long enough
      root.isReady = true;
    }
  }

  //=========================================================================
  //== UI & Logic
  //=========================================================================
  width: 400 // Example size, parent can override
  height: 200 // Example size, parent can override
  radius: 12

  color: {
    if (!mouseArea.pressed) {
      if (root.isRunning) {
        isReady = false;
        return root.activeColor;
      }
      isReady = false;
      return root.idleColor;
    }
    if (root.isRunning) {
      return root.pressedColor;
    } else {
      return root.isReady ? root.readyColor : root.pressedColor;
    }
  }

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.buttonText
    color: root.buttonTextColor
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.bold: root.fontBold
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true

    onPressed: {
      if (root.isRunning) {
        // If the timer is already running, a simple press is enough to stop it.
        // We emit the signal immediately.
        root.stopTimer();
      } else {
        // If the timer is stopped, we begin the "ready" sequence.
        // Start the timer that will fire after `readyDelay`.
        readyTimer.start();
      }
    }

    onReleased: {
      // The release action is only relevant for starting the timer.
      if (!root.isRunning && root.isReady) {
        // If we were not running AND we successfully reached the ready state...
        // ...then the release of the button is the signal to start.
        root.startTimer();
      }

      // Always clean up state on release
      readyTimer.stop();
      root.isReady = false;
    }

    onExited: {
      // If the mouse leaves the area while pressed, cancel the ready sequence.
      readyTimer.stop();
      root.isReady = false;
    }

    onCanceled: {
      // Same as exited, ensure cleanup
      onExited();
    }
  }
}
