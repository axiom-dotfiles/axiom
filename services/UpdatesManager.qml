pragma Singleton
import QtQuick
import Quickshell.Io

import qs.config

// Pending package updates, shared by every Updates widget. Only one check
// may run at a time: concurrent `checkupdates` runs share its temporary sync
// db and fail with "Cannot fetch updates". Widgets register with
// acquire(owner, {intervalMinutes, aurHelper}) (aurHelper "" for no AUR)
// and drop it with release(owner); checks run at the shortest requested
// interval, and the AUR is checked if any widget asks for it.
QtObject {
  id: root

  // [{ name, from, to }]
  property var repoPackages: []
  property var aurPackages: []
  readonly property bool checking: _repo.running || _aur.running
  readonly property bool upgrading: _upgrader.running

  function acquire(owner, request) {
    _registry.acquire(owner, {
      "interval": (request?.intervalMinutes ?? 30) * 60000,
      "aurHelper": request?.aurHelper ?? ""
    });
  }

  function release(owner) {
    _registry.release(owner);
  }

  function refresh() {
    if (_repo.running) {
      _repoPending = true;
    } else {
      _repo.running = true;
    }
    if (_aurHelper === "") {
      aurPackages = [];
    } else if (_aur.running) {
      _aurPending = true;
    } else {
      // The helper goes in as an argument, never into the script text
      _aur.command = ["sh", "-c", 'command -v "$1" >/dev/null || exit 127; "$1" -Qua', "sh", _aurHelper];
      _aur.running = true;
    }
  }

  // Runs `command` in a terminal (`terminal`, else Apps.inTerminal's) and
  // checks again once the terminal closes. Ignored while an upgrade is
  // already running.
  function upgrade(command, terminal) {
    if (_upgrader.running)
      return;
    _upgrader.command = Apps.inTerminal(["bash", "-c", `${command}; echo; read -n 1 -s -r -p "Press any key to close"`], terminal);
    _upgrader.running = true;
  }

  function parse(text) {
    return text.split("\n").map(line => line.trim().split(/\s+/)).filter(f => f.length >= 4 && f[2] === "->").map(f => ({
          "name": f[0],
          "from": f[1],
          "to": f[3]
        }));
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  readonly property var _requests: _registry.requests
  property bool _repoPending: false
  property bool _aurPending: false

  readonly property bool _active: _registry.active
  readonly property int _interval: _active ? Math.min(..._requests.map(r => r.interval)) : 1800000
  readonly property string _aurHelper: _requests.find(r => r.aurHelper !== "")?.aurHelper ?? ""

  // Check straight away when the first widget appears or the AUR setting
  // changes; the Timer coalesces a burst of registrations into one check
  on_ActiveChanged: if (_active)
    _settle.restart()
  on_AurHelperChanged: if (_active)
    _settle.restart()

  property Timer _settle: Timer {
    interval: 500
    onTriggered: root.refresh()
  }

  property Timer _poll: Timer {
    interval: root._interval
    repeat: true
    running: root._active
    onTriggered: root.refresh()
  }

  property Process _upgrader: Process {
    onExited: root.refresh()
  }

  property Process _repo: Process {
    command: ["checkupdates", "--nocolor"]
    stdout: StdioCollector {
      id: repoOut
    }
    stderr: StdioCollector {
      id: repoErr
    }
    // 0: updates listed, 2: none, anything else: failed (offline, db locked)
    onExited: exitCode => {
      if (exitCode === 0 || exitCode === 2)
        root.repoPackages = root.parse(repoOut.text);
      else
        console.warn(`[UpdatesManager] checkupdates failed (${exitCode}): ${repoErr.text.trim()}`);
      if (root._repoPending) {
        root._repoPending = false;
        running = true;
      }
    }
  }

  property Process _aur: Process {
    stdout: StdioCollector {
      id: aurOut
    }
    // -Qua exits 1 when nothing is outdated
    onExited: exitCode => {
      if (exitCode === 127) {
        console.warn(`[UpdatesManager] AUR helper '${root._aurHelper}' is not installed`);
        root.aurPackages = [];
      } else {
        root.aurPackages = root.parse(aurOut.text);
      }
      if (root._aurPending) {
        root._aurPending = false;
        running = true;
      }
    }
  }
}
