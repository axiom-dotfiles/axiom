pragma Singleton
import QtQuick
import Quickshell.Io
import qs.config
import qs.components.methods

// The todo list: one list for every widget and module, kept in
// $XDG_DATA_HOME/axiom/todo.json ({ version, items }: TodoItems' shape),
// written atomically and watched, so an edit made elsewhere shows at once.
// Never read or written in the greeter.
//
//   qs -c axiom ipc call todo add "Buy milk"
QtObject {
  id: root

  // Every item, in order (see TodoItems)
  readonly property var items: root._items
  readonly property int openCount: TodoItems.openCount(root._items)
  readonly property bool loaded: root._loaded
  readonly property string path: Paths.userDataPath + "todo.json"

  // What a list shows (TodoItems.shown, with Todo.showCompleted)
  readonly property var shownItems: TodoItems.shown(root._items, TodoConfig.showCompleted)

  // Adds an open item; its uid, or "" for an empty text
  function add(text) {
    const uid = root._newUid();
    const next = TodoItems.add(root._items, text, Date.now(), uid);
    if (next === root._items)
      return "";
    root._set(next);
    return uid;
  }

  // Done ↔ open (`done` given: sets it)
  function toggle(uid, done) {
    root._set(TodoItems.toggle(root._items, uid, Date.now(), done));
  }

  function rename(uid, text) {
    root._set(TodoItems.rename(root._items, uid, text));
  }

  function remove(uid) {
    root._set(TodoItems.remove(root._items, uid));
  }

  // To `index` in `items`
  function move(uid, index) {
    root._set(TodoItems.move(root._items, uid, index));
  }

  function clearCompleted() {
    root._set(TodoItems.clearCompleted(root._items));
  }

  function find(uid) {
    return TodoItems.find(root._items, uid);
  }

  // -- Private --

  property var _items: []
  property bool _loaded: false
  property bool _retried: false
  property int _serial: 0

  function _newUid() {
    root._serial += 1;
    return Date.now().toString(36) + "-" + Math.floor(Math.random() * 0xffffff).toString(36) + "-" + root._serial;
  }

  function _set(items) {
    if (Paths.greeter || !root._loaded || items === root._items)
      return;
    root._items = items;
    root._view.setText(JSON.stringify({
      "version": 1,
      "items": items
    }, null, 2) + "\n");
  }

  function _parse(text) {
    try {
      const data = JSON.parse(text);
      root._items = TodoItems.normalize(data?.items);
    } catch (e) {
      console.warn("[TodoManager] Couldn't read", root.path + ":", e.message, "(keeping the list shown)");
    }
    root._loaded = true;
  }

  property FileView _view: FileView {
    path: Paths.greeter ? "" : root.path
    watchChanges: true
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onLoaded: root._parse(text())
    onFileChanged: reload()
    // Nothing saved yet: an empty list
    onLoadFailed: root._loaded = true
    onSaved: root._retried = false
    onSaveFailed: error => {
      // The data folder may not exist yet: make it and write again, once
      if (root._retried) {
        console.warn("[TodoManager] Couldn't save", root.path + ":", FileViewError.toString(error));
        return;
      }
      root._retried = true;
      CommandManager.run(["mkdir", "-p", "--", Paths.userDataPath], code => {
        if (code === 0)
          root._view.setText(JSON.stringify({
            "version": 1,
            "items": root._items
          }, null, 2) + "\n");
      });
    }
  }

  property IpcHandler _ipc: IpcHandler {
    target: "todo"
    enabled: !Paths.greeter

    // Adds an item; false for an empty text
    function add(text: string): bool {
      return root.add(text) !== "";
    }

    // The open items, one per line
    function list(): string {
      return TodoItems.shown(root._items, false).map(item => item.summary).join("\n");
    }

    // Ticks off (or reopens) the first item whose text is `text`
    function toggle(text: string): bool {
      const item = root._items.find(entry => entry.summary === text.trim());
      if (!item)
        return false;
      root.toggle(item.uid);
      return true;
    }

    function clearCompleted(): void {
      root.clearCompleted();
    }

    function count(): int {
      return root.openCount;
    }
  }
}
