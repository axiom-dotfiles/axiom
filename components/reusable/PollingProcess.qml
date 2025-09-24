// PollingProcess.qml
import QtQuick
import Quickshell.Io

Item {
  id: root

  // Configuration
  property int interval: 2000
  property var command: []
  property bool autoStart: true
  property bool treatExitCodeAsStatus: false  // Use exit code as primary signal

  // State
  property int exitCode: -1
  property string stdout: ""
  property string stderr: ""
  property bool running: false

  // Signals
  signal dataReceived(string data)
  signal statusChanged(int exitCode, string stdout, string stderr)
  signal error(string message)

  // Public API
  function start() {
    pollTimer.start();
    refresh();
  }

  function stop() {
    pollTimer.stop();
    process.running = false;
  }

  function refresh() {
    if (root.command.length > 0) {
      process.command = root.command;
      process.running = true;
      root.running = true;
    }
  }

  Component.onCompleted: {
    if (autoStart && command.length > 0) {
      refresh();  // Initial run
    }
  }

  Timer {
    id: pollTimer
    interval: root.interval
    running: root.autoStart && root.command.length > 0
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: process

    property string capturedStdout: ""
    property string capturedStderr: ""

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        process.capturedStdout = text.trim();
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        process.capturedStderr = text.trim();
      }
    }

    onExited: (code, status) => {
      root.exitCode = code;
      root.stdout = process.capturedStdout;
      root.stderr = process.capturedStderr;
      root.running = false;

      // Emit signals
      root.dataReceived(root.stdout);
      root.statusChanged(code, root.stdout, root.stderr);

      // Only emit error for unexpected exit codes if not treating as status
      if (!root.treatExitCodeAsStatus && code !== 0 && root.stderr) {
        root.error(root.stderr);
      }

      // Clear captured data for next run
      process.capturedStdout = "";
      process.capturedStderr = "";
    }
  }
}
