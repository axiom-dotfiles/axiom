// PollingProcess.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
  id: component
  
  // -- Signals --
  signal dataReceived(string data)
  signal statusChanged(int exitCode, string stdout, string stderr)
  signal error(string message)
  
  // -- Public API --
  property var command: []
  property bool autoStart: true
  property bool treatExitCodeAsStatus: false
  
  property int exitCode: -1
  property string stdout: ""
  property string stderr: ""
  property bool running: false
  
  // -- Configurable Appearance --
  property int interval: 2000
  
  // -- Implementation --
  function start() {
    pollTimer.start();
    refresh();
  }
  
  function stop() {
    pollTimer.stop();
    process.running = false;
  }
  
  function refresh() {
    if (component.command.length > 0) {
      process.command = component.command;
      process.running = true;
      component.running = true;
    }
  }
  
  Component.onCompleted: {
    if (autoStart && command.length > 0) {
      refresh();
    }
  }
  
  Timer {
    id: pollTimer
    interval: component.interval
    running: component.autoStart && component.command.length > 0
    repeat: true
    onTriggered: component.refresh()
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
      component.exitCode = code;
      component.stdout = process.capturedStdout;
      component.stderr = process.capturedStderr;
      component.running = false;
      
      component.dataReceived(component.stdout);
      component.statusChanged(code, component.stdout, component.stderr);
      
      if (!component.treatExitCodeAsStatus && code !== 0 && component.stderr) {
        component.error(component.stderr);
      }
      
      process.capturedStdout = "";
      process.capturedStderr = "";
    }
  }
}
