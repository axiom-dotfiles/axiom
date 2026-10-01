pragma Singleton
import QtQuick

// The editors' unsaved edits, by overlay page: which pages hold a dirty
// draft (the navigator's dots and the unsaved-changes strip), and saving
// or discarding them all at once. Drafts survive leaving a page or closing
// the overlay, so this reminds rather than blocks.
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
      "type": "EdgeMenuEditor",
      "dirty": EdgeMenuManager.isDirty
    },
    {
      "type": "Monitors",
      "dirty": MonitorManager.isDirty
    },
    {
      "type": "OverlayEditor",
      "dirty": OverlayManager.isDirty
    }
  ].filter(page => page.dirty).map(page => page.type)

  // Pages Save all and Discard all leave alone: Monitors applies with a
  // keep/revert step, so it's saved on its page
  readonly property var separate: ["Monitors"]
  readonly property bool canActOnAll: root.unsaved.some(type => !root.separate.includes(type))

  function isUnsaved(type) {
    return root.unsaved.includes(type);
  }

  // Each save merges onto the latest config, so they don't undo each other.
  // A rejected one stays dirty (and listed).
  function saveAll() {
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
  }

  function discardAll() {
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
  }
}
