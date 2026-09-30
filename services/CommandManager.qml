pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shell commands polled for their output (e.g. a bar Button's label),
// shared by every widget asking for the same command: each distinct
// command runs once per interval (the shortest asked for), only while
// something has acquire()d it.
//   CommandManager.acquire(owner, { command, interval })
//   CommandManager.outputs[command]    // last stdout, trimmed
// Also runs one-off commands for widgets (runDetached), so the UI starts
// no processes of its own.
QtObject {
  id: root

  // command -> last output (trimmed)
  property var outputs: ({})

  function acquire(owner, request) {
    if (!request?.command) {
      release(owner);
      return;
    }
    _registry.acquire(owner, {
      "command": request.command,
      "interval": Math.max(500, request.interval ?? 5000)
    });
  }

  function release(owner) {
    _registry.release(owner);
  }

  // Run a user-configured shell command once, detached (a widget's click
  // or middle-click command). An empty command does nothing.
  function runDetached(command) {
    if (command)
      Quickshell.execDetached(["sh", "-c", command]);
  }

  // Run a command again now (after an action that may change its output)
  function refresh(command) {
    _runners[command]?.run();
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  readonly property var _requests: _registry.requests
  on_RequestsChanged: _sync()

  // command -> runner
  property var _runners: ({})

  property Component _runnerComponent: Component {
    QtObject {
      id: runner
      property string command
      property int interval: 5000

      function run() {
        if (!process.running)
          process.running = true;
      }

      property Timer _timer: Timer {
        interval: runner.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.run()
      }

      property Process _process: Process {
        id: process
        command: ["sh", "-c", runner.command]
        stdout: StdioCollector {
          onStreamFinished: {
            const output = text.trim();
            if (root.outputs[runner.command] !== output)
              root.outputs = Object.assign({}, root.outputs, {
                [runner.command]: output
              });
          }
        }
      }
    }
  }

  function _sync() {
    const intervals = {};
    for (const r of root._requests)
      intervals[r.command] = Math.min(intervals[r.command] ?? r.interval, r.interval);
    const next = {};
    for (const command in intervals) {
      const runner = root._runners[command] ?? root._runnerComponent.createObject(root, {
        "command": command
      });
      runner.interval = intervals[command];
      next[command] = runner;
    }
    for (const command in root._runners) {
      if (!(command in next))
        root._runners[command].destroy();
    }
    root._runners = next;
  }
}
