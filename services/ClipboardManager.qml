pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

/*
 * The clipboard history the launcher searches (":" or /clipboard), while
 * Launcher.clipboard is on. Launcher.clipboardSource picks where it comes from:
 *   axiom     `wl-paste --watch` records text clips, in memory only (kept
 *             across QML reloads, gone on restart). Clips a password manager
 *             marks sensitive (CLIPBOARD_STATE=sensitive) are never recorded.
 *   cliphist  the user's own cliphist history, listed when the launcher asks.
 * `entries` is [{ id, text, time }], newest first (time is 0 for cliphist).
 * Copying back pipes the text to wl-copy's stdin, never through argv.
 */
Singleton {
  id: root

  readonly property bool enabled: LauncherConfig.clipboard
  readonly property bool cliphist: LauncherConfig.clipboardSource === "cliphist"
  // Whether axiom records the clipboard itself
  readonly property bool recording: enabled && !cliphist
  // undefined until checked
  readonly property var cliphistInstalled: DependencyManager.found.cliphist

  property var entries: []

  // Longer clips aren't recorded
  readonly property int _maxLength: 100000

  // Lists cliphist's history again (axiom's own is always current)
  function refresh() {
    if (!enabled || !cliphist)
      return;
    DependencyManager.check(["cliphist"]);
    if (!_list.running)
      _list.running = true;
  }

  function copy(entry) {
    if (!entry)
      return;
    if (cliphist)
      _run(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id], null);
    else
      _run(["wl-copy"], entry.text);
  }

  function remove(entry) {
    if (!entry)
      return;
    root.entries = root.entries.filter(e => e.id !== entry.id);
    // cliphist delete reads the listed line on stdin
    if (cliphist)
      _run(["cliphist", "delete"], entry.id + "\t" + entry.text + "\n");
  }

  function clear() {
    root.entries = [];
    if (cliphist)
      _run(["cliphist", "wipe"], null);
  }

  // --- axiom's own history ---

  // As JSON: a JS array can't cross into the reloaded engine
  PersistentProperties {
    id: _history
    reloadableId: "axiomClipboard"
    property string entries: "[]"
    property int nextId: 1

    // Before this, the saved history hasn't been restored yet: keep what was
    // recorded meanwhile on top of it
    onLoaded: {
      root._restored = true;
      if (root.cliphist)
        return;
      const texts = root.entries.map(e => e.text);
      root.entries = root.entries.concat(JSON.parse(_history.entries).filter(e => !texts.includes(e.text)));
    }
  }

  property bool _restored: false

  onEntriesChanged: {
    if (_restored && !cliphist)
      _history.entries = JSON.stringify(entries);
  }

  function _add(text) {
    if (text.trim() === "" || text.length > root._maxLength)
      return;
    const kept = root.entries.filter(e => e.text !== text).slice(0, Math.max(0, LauncherConfig.clipboardMaxEntries - 1));
    root.entries = [
      {
        "id": String(_history.nextId++),
        "text": text,
        "time": Date.now()
      }
    ].concat(kept);
  }

  // One text clip per ASCII RS; the first is whatever is on the clipboard now
  Process {
    id: _watch
    running: root.recording
    command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", '[ "$CLIPBOARD_STATE" = data ] || exit 0; cat; printf "\\036"']
    stdout: SplitParser {
      splitMarker: "\u001e"
      onRead: data => root._add(data)
    }
  }

  onEnabledChanged: {
    if (!enabled)
      root.entries = [];
  }

  onCliphistChanged: root.entries = []

  // --- cliphist ---

  Process {
    id: _list
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.cliphist)
          return;
        root.entries = text.split("\n").filter(line => line.includes("\t")).map(line => {
          const tab = line.indexOf("\t");
          return {
            "id": line.slice(0, tab),
            "text": line.slice(tab + 1),
            "time": 0
          };
        });
      }
    }
  }

  // --- Processes ---

  function _run(command, input) {
    const process = _processComponent.createObject(root, {
      "command": command,
      "input": input ?? "",
      "stdinEnabled": input !== null && input !== undefined
    });
    process.exited.connect(() => process.destroy());
    process.running = true;
  }

  property Component _processComponent: Component {
    Process {
      id: process
      property string input: ""
      onStarted: {
        if (!process.stdinEnabled)
          return;
        process.write(process.input);
        process.input = "";
        process.stdinEnabled = false;
      }
    }
  }

  Component.onCompleted: {
    if (cliphist)
      DependencyManager.check(["cliphist"]);
  }
}
