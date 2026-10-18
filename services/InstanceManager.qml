pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

/*
 * Keeps one axiom per display. At start (and again 5 s later, for one
 * started in the same moment) lists this install's instances on this
 * display (`qs list`); the newest (ShellInstances) ends the others and an
 * older one quits. Two can start when the restart bind fires twice, or is
 * pressed again while axiom starts: `qs kill` ends only one of them
 * (scripts/restart.sh, which every restart bind runs now, ends them all).
 * Not in the greeter. Created from shell.qml's `_services`.
 */
Singleton {
  id: root

  function check() {
    if (!Paths.greeter && !list.running)
      list.running = true;
  }

  Component.onCompleted: {
    check();
    _again.start();
  }

  Timer {
    id: _again
    interval: 5000
    onTriggered: root.check()
  }

  Process {
    id: list
    command: ["qs", "list", "-p", Paths.axiomPath.replace(/\/$/, ""), "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        let instances = [];
        try {
          instances = JSON.parse(text);
        } catch (e) {
          return;
        }
        const decision = ShellInstances.decide(instances, Quickshell.processId);
        if (decision.end.length > 0) {
          console.warn(`InstanceManager: another axiom runs on this display; ending it (pid ${decision.end.join(", ")})`);
          Quickshell.execDetached(["sh", "-c", 'kill -TERM "$@"; sleep 3; kill -KILL "$@" 2>/dev/null; true', "sh"].concat(decision.end.map(String)));
        } else if (decision.quit) {
          console.warn("InstanceManager: a newer axiom runs on this display; quitting");
          Qt.quit();
        }
      }
    }
  }
}
