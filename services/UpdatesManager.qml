pragma Singleton
import QtQuick
import Quickshell.Io

import qs.config
import qs.components.methods

// Pending package updates, shared by every Updates widget, checked the way
// this distribution does (Packages.updates: checkupdates on Arch, dnf on
// Fedora; nothing on one it doesn't know, `supported` false). Only one
// check may run at a time: concurrent `checkupdates` runs share its
// temporary sync db and fail with "Cannot fetch updates". Widgets register
// with acquire(owner, {intervalMinutes, aurHelper}) (aurHelper "" for no
// AUR) and drop it with release(owner); checks run at the shortest
// requested interval, and the AUR is checked if any widget asks for it and
// the distribution has one.
QtObject {
  id: root

  // { check, found, none, format, upgrade, aur }, or null where updates
  // can't be checked
  readonly property var backend: Packages.updates(DependencyManager.distro)
  readonly property bool supported: root.backend !== null
  // An AUR helper's updates count here
  readonly property bool hasAur: root.backend?.aur === true

  // [{ name, from, to }]
  property var repoPackages: []
  property var aurPackages: []
  readonly property bool checking: _repo.running || _aur.running

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
    if (!root.supported)
      return;
    if (_repo.running) {
      _repoPending = true;
    } else {
      _repo.running = true;
    }
    if (_aurHelper === "" || !root.hasAur) {
      aurPackages = [];
    } else if (_aur.running) {
      _aurPending = true;
    } else {
      // The helper goes in as an argument, never into the script text
      _aur.command = ["sh", "-c", 'command -v "$1" >/dev/null || exit 127; "$1" -Qua', "sh", _aurHelper];
      _aur.running = true;
    }
  }

  // What upgrades by default: the AUR helper's -Syu (with `aurHelper` set
  // and an AUR here), else the distribution's own upgrade
  function upgradeCommand(aurHelper) {
    if (aurHelper && root.hasAur)
      return `${aurHelper} -Syu`;
    return root.backend?.upgrade ?? "";
  }

  // Runs `command` in a terminal (`terminal`, else Apps.inTerminal's) and
  // checks again once the terminal closes. Ignored while an upgrade is
  // already running.
  function upgrade(command, terminal) {
    if (_upgrader.running || command === "")
      return;
    _upgrader.command = Apps.inTerminal(["bash", "-c", `${command}; echo; read -n 1 -s -r -p "Press any key to close"`], terminal);
    _upgrader.running = true;
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
    running: root._active && root.supported
    onTriggered: root.refresh()
  }

  property Process _upgrader: Process {
    onExited: root.refresh()
  }

  property Process _repo: Process {
    command: root.backend?.check ?? []
    stdout: StdioCollector {
      id: repoOut
    }
    stderr: StdioCollector {
      id: repoErr
    }
    // The backend's `found` (updates listed) or `none` exit codes, anything
    // else: failed (offline, db locked)
    onExited: exitCode => {
      const backend = root.backend;
      if (!backend)
        return;
      if (backend.found.includes(exitCode) || backend.none.includes(exitCode))
        root.repoPackages = Packages.parseUpdates(backend.format, repoOut.text);
      else
        console.warn(`[UpdatesManager] ${backend.check[0]} failed (${exitCode}): ${repoErr.text.trim()}`);
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
        root.aurPackages = Packages.parseUpdates("pacman", aurOut.text);
      }
      if (root._aurPending) {
        root._aurPending = false;
        running = true;
      }
    }
  }
}
