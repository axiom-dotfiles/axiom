pragma Singleton
import QtQuick
import Quickshell

import qs.config

/*
 * The emoji the launcher searches (";" or /emoji), while Launcher.emoji is on.
 * `entries()` is config/json/emoji.json (built by scripts/generate_emoji.py
 * from Unicode's emoji-test.txt and CLDR's keywords), read the first time
 * it's asked for: [{ e: emoji, n: name, g: group, k: [keywords] }], in
 * Unicode's order. `copy` puts one on the clipboard (wl-copy) and counts it
 * in `usage` ({ emoji: { count, last } }), for LauncherManager's frecency;
 * `type` also types it into the focused window (wtype, optional: `canType`).
 */
QtObject {
  id: root

  // { emoji: { count, last } }
  property var usage: ({})
  // undefined until checked
  readonly property var canType: DependencyManager.found.wtype

  // Every emoji, loaded on first use; [] when the file can't be read
  function entries() {
    if (root._entries === null) {
      const text = FileManager.read(Paths.configPath + "json/emoji.json");
      try {
        root._entries = text ? JSON.parse(text) : [];
      } catch (e) {
        console.warn("[EmojiManager] Could not parse emoji.json:", e);
        root._entries = [];
      }
      if (root._entries.length === 0)
        console.warn("[EmojiManager] No emoji: run scripts/generate_emoji.py");
      DependencyManager.check(["wtype"]);
    }
    return root._entries;
  }

  function copy(emoji) {
    _record(emoji);
    ClipboardManager.copyText(emoji);
  }

  // Types it once the launcher has closed and the window has the keyboard
  function type(emoji) {
    root._typing = emoji;
    _typeLater.restart();
  }

  // --- Private ---

  property var _entries: null
  property string _typing: ""

  property Timer _typeLater: Timer {
    interval: 150
    onTriggered: Quickshell.execDetached(["wtype", "--", root._typing])
  }

  property var _stateHandler: StateManager.createStateHandler("emoji")

  function _record(emoji) {
    const entry = usage[emoji] ?? {
      count: 0,
      last: 0
    };
    const updated = Object.assign({}, usage);
    updated[emoji] = {
      count: entry.count + 1,
      last: Date.now()
    };
    usage = updated;
    _stateHandler.save(usage);
  }

  Component.onCompleted: usage = _stateHandler.load({})
}
