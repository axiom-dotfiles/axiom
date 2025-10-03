// qs/components/widgets/CubeTimer.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell.Io

import qs.config
import qs.components.reusable
import qs.components.widgets.menu.cube

ColumnLayout {
  id: root

  readonly property int _required_width: mainContainer.implicitWidth

  property int timerFontSize: 72
  property int scrambleFontSize: Appearance.fontSize * 1.2
  property int buttonIconSize: 24
  property int scrambleImageSize: 10
  property bool hideTimeDuringSolve: false
  property int readyDelay: 500 // ms
  property string pythonScriptPath: Config.scriptsPath + "/cube.py"
  property string scrambleTextPath: "../../../../assets/cube/scramble.txt"
  property string scrambleImagePath: "../../../../assets/cube/scramble.png"

  property bool isRunning: false
  property bool isReady: false
  property bool wasStopped: false
  property int elapsedTime: 0

  // Model to store the history of solves
  ListModel {
    id: solveHistoryModel
  }

  Timer {
    id: stopwatch
    interval: 10
    repeat: true
    running: root.isRunning
    onTriggered: root.elapsedTime += stopwatch.interval
  }

  Timer {
    id: readyTimer
    interval: root.readyDelay
    repeat: false
    onTriggered: root.isReady = true
  }

  FileView {
    id: scrambleFileReader
    path: Qt.resolvedUrl(root.scrambleTextPath)
  }

  Process {
    id: cubeScriptProcess
    command: ["python3", root.pythonScriptPath]
    onExited: {
      console.log("Command:", command.join(" "));
      console.log("Stdout:", stdout);
      console.log("Stderr:", stderr);
      // After script finishes, reload the assets
      reloadScrambleAssets();
    }
  }

  function formatTime(ms) {
    var totalSeconds = Math.floor(ms / 1000);
    var minutes = Math.floor(totalSeconds / 60);
    var seconds = totalSeconds % 60;
    var milliseconds = ms % 1000;

    // Pad with leading zeros
    var paddedMinutes = String(minutes).padStart(2, '0');
    var paddedSeconds = String(seconds).padStart(2, '0');
    var paddedMilliseconds = String(Math.floor(milliseconds / 10)).padStart(2, '0'); // For hundredths

    return `${paddedMinutes}:${paddedSeconds}:${paddedMilliseconds}`;
  }

  function startTimer() {
    if (root.wasStopped) {
      resetTimerState();
    }
    root.isRunning = true;
  }

  function stopTimer() {
    // Capture the time and scramble before any state changes
    var solveTime = root.elapsedTime;
    var solveScramble = scrambleText.text;
    
    console.log("Stopping timer - Elapsed time:", solveTime, "ms");
    
    root.isRunning = false;
    root.wasStopped = true;

    // Add the completed solve to the history model
    if (solveTime > 0) { // Only add non-zero solves
        console.log("Adding solve to history - Time:", solveTime, "Scramble:", solveScramble);
        var newItem = {
            "scramble": solveScramble,
            "time": solveTime
        };
        solveHistoryModel.insert(0, newItem);
        
        // Verify the item was added correctly
        console.log("History count:", solveHistoryModel.count);
        if (solveHistoryModel.count > 0) {
            var firstItem = solveHistoryModel.get(0);
            console.log("First item in history - Time:", firstItem.time, "Scramble:", firstItem.scramble);
        }
    }

    regenerateScramble();
  }

  function resetTimerState() {
    root.isRunning = false;
    root.wasStopped = false;
    root.elapsedTime = 0;
  }

  function regenerateScramble() {
    cubeScriptProcess.running = true;
  }

  function reloadScrambleAssets() {
    scrambleFileReader.reload();

    scrambleImage.source = "";
    scrambleImage.source = Qt.resolvedUrl(root.scrambleImagePath) + "?cache_buster=" + new Date().getTime();
  }

  spacing: Widget.spacing

  // Main timer container (static, non-scrollable)
  StyledContainer {
    id: mainContainer
    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + (Widget.padding * 2)
    backgroundColor: Theme.foregroundAlt

    ColumnLayout {
      id: mainLayout
      anchors.fill: parent
      anchors.margins: Widget.padding

      Text {
        id: scrambleText
        text: scrambleFileReader.text()
        font.family: Appearance.fontFamily
        font.pixelSize: root.scrambleFontSize
        color: Theme.backgroundAlt
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
      }

      Text {
        id: timerDisplay
        text: root.hideTimeDuringSolve && root.isRunning ? "..." : formatTime(root.elapsedTime)
        font.family: Appearance.fontFamily
        font.pixelSize: root.timerFontSize
        font.bold: true
        color: root.isReady ? Theme.success : Theme.background
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Widget.spacing * 2
        Layout.bottomMargin: Widget.spacing

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }

      CubeTimerButton {
        id: controlButton
        Layout.preferredWidth: 300
        Layout.preferredHeight: 150
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Widget.spacing * 2
        Layout.bottomMargin: Widget.spacing * 2

        isRunning: root.isRunning
        readyDelay: root.readyDelay
        buttonText: root.isRunning ? "" : (root.wasStopped ? "" : "")
        buttonTextColor: root.isRunning ? Theme.accent : Theme.background

        fontSize: root.timerFontSize
        fontFamily: Appearance.fontFamily
        idleColor: Theme.accent
        pressedColor: Theme.base0A
        readyColor: Theme.successHighlight
        activeColor: Theme.background

        onStartTimer: root.startTimer()
        onStopTimer: root.stopTimer()
      }

      Image {
        id: scrambleImage
        source: Qt.resolvedUrl(root.scrambleImagePath)
        width: root.scrambleImageSize
        height: root.scrambleImageSize
        fillMode: Image.PreserveAspectFit
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Widget.spacing * 2
      }
    }
  }

  // History container (scrollable, separate background)
  StyledContainer {
    id: historyContainer
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 240
    Layout.alignment: Qt.AlignBottom
    backgroundColor: Theme.background
    visible: solveHistoryModel.count > 0

    ScrollView {
      id: historyScrollView
      anchors.fill: parent
      anchors.margins: Widget.padding
      clip: true
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      ListView {
        id: solveHistoryView
        model: solveHistoryModel
        spacing: Widget.spacing

        delegate: SolveHistoryItem {
          required property int index
          required property var model
          
          width: solveHistoryView.width
          scramble: model.scramble
          time: model.time
          
          Component.onCompleted: {
            console.log("SolveHistoryItem created - Index:", index, "Time:", model.time, "Scramble:", model.scramble);
          }
        }
      }
    }
  }
}
