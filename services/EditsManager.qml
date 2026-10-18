pragma Singleton
import QtQuick

// The editors' unsaved edits, by overlay page: which pages hold a dirty
// draft (the navigator's dots and the unsaved-changes strip), and saving
// or discarding them all at once. Drafts survive leaving a page or closing
// the overlay, so this reminds rather than blocks.
//
// Also the text or number box holding typed text not committed yet (only
// the focused one can): its page shows Save at once, and Save / Reset
// commit or drop it first, while it reaches the running shell only on
// Enter or focus loss (a half-typed command or folder never runs).
//
// Also how the editors are laid out, which outlives their pages (saved in
// state/editors.json): whether the libraries group their types, and
// whether the bar editor stacks a horizontal bar's sections.
QtObject {
  id: root

  // View types with unsaved edits
  readonly property var unsaved: [
    {
      "type": "Settings",
      "dirty": SettingsManager.isDirty
    },
    {
      "type": "BarEditor",
      "dirty": BarManager.isDirty
    },
    {
      "type": "Keybinds",
      "dirty": KeybindManager.isDirty
    },
    {
      "type": "Monitors",
      "dirty": MonitorManager.isDirty
    },
    {
      "type": "Layouts",
      "dirty": OverlayManager.isDirty || EdgeMenuManager.isDirty || DesktopManager.editor.isDirty || LockManager.editor.isDirty || GreeterManager.editor.isDirty
    }
  ].filter(page => page.dirty).map(page => page.type)

  // Pages Save all and Discard all leave alone: Monitors applies with a
  // keep/revert step, so it's saved on its page
  readonly property var separate: ["Monitors"]
  readonly property bool canActOnAll: root.unsaved.some(type => !root.separate.includes(type))

  // The widget and module libraries show their types by group (the
  // schema's `x-libraryGroups`), else by name
  readonly property bool libraryGrouped: root._libraryGrouped
  // The bar editor draws a top or bottom bar's sections stacked down the
  // side of the page, as a side bar's, rather than across it
  readonly property bool barStacked: root._barStacked
  property bool _libraryGrouped: false
  property bool _barStacked: false
  readonly property var _state: StateManager.createStateHandler("editors")

  function setLibraryGrouped(value) {
    root._libraryGrouped = value;
    root._saveState();
  }

  function setBarStacked(value) {
    root._barStacked = value;
    root._saveState();
  }

  function _saveState() {
    root._state.save({
      "libraryGrouped": root._libraryGrouped,
      "barStacked": root._barStacked
    });
  }

  Component.onCompleted: {
    const saved = root._state.load({});
    root._libraryGrouped = saved.libraryGrouped === true;
    root._barStacked = saved.barStacked === true;
  }

  // The box holding typed text (var: callers use commitTyped() and
  // discardTyped()), and the window it's in, so only that window's Save
  // shows it
  readonly property var typingField: root._typingField
  readonly property var typingWindow: root._typingWindow
  property var _typingField: null
  property var _typingWindow: null

  function holdTyping(field, window) {
    root._typingField = field;
    root._typingWindow = window;
  }

  function releaseTyping(field) {
    if (root._typingField !== field)
      return;
    root._typingField = null;
    root._typingWindow = null;
  }

  // Before a save: the typed text commits (dropped if it isn't valid yet)
  function commitTyping() {
    root._typingField?.commitTyped();
  }

  function discardTyping() {
    root._typingField?.discardTyped();
  }

  function isUnsaved(type) {
    return root.unsaved.includes(type);
  }

  // Each save merges onto the latest config, so they don't undo each other.
  // A rejected one stays dirty (and listed).
  function saveAll() {
    root.commitTyping();
    if (SettingsManager.isDirty)
      SettingsManager.saveChanges();
    if (BarManager.isDirty)
      BarManager.saveChanges();
    if (KeybindManager.isDirty)
      KeybindManager.save();
    if (EdgeMenuManager.isDirty)
      EdgeMenuManager.saveChanges();
    if (OverlayManager.isDirty)
      OverlayManager.saveChanges();
    if (DesktopManager.editor.isDirty)
      DesktopManager.editor.saveChanges();
    if (LockManager.editor.isDirty)
      LockManager.editor.saveChanges();
    if (GreeterManager.editor.isDirty)
      GreeterManager.editor.saveChanges();
  }

  function discardAll() {
    root.discardTyping();
    if (SettingsManager.isDirty)
      SettingsManager.resetChanges();
    if (BarManager.isDirty)
      BarManager.resetChanges();
    if (KeybindManager.isDirty)
      KeybindManager.reset();
    if (EdgeMenuManager.isDirty)
      EdgeMenuManager.resetChanges();
    if (OverlayManager.isDirty)
      OverlayManager.resetChanges();
    if (DesktopManager.editor.isDirty)
      DesktopManager.editor.resetChanges();
    if (LockManager.editor.isDirty)
      LockManager.editor.resetChanges();
    if (GreeterManager.editor.isDirty)
      GreeterManager.editor.resetChanges();
  }
}
