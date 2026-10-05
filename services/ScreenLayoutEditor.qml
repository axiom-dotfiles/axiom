pragma ComponentBehavior: Bound
import QtQuick

import qs.components.methods

// The layouts editor's draft of one screen layout (a ScreenLayout: the
// built-in lock screen's, LockManager.editor, or the greeter's,
// GreeterManager.editor): its modules on a bounded grid, edited through
// `layout`, its own fields, and its preview on screen. What really shows
// (a lock, the greeter) only ever reads the saved layout.
// Not a singleton: each owner holds one.
QtObject {
  id: root

  // The layout's config path, e.g. ["Lockscreen", "layout"]
  required property var path
  // The x-hosts name its modules must list ("lockscreen", "greeter")
  required property string host
  // What it's called in problems ("Lock screen")
  required property string name

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: root.path
  }
  readonly property alias localLayout: draft.local
  readonly property alias savedLayout: draft.saved
  readonly property alias isDirty: draft.isDirty

  property GridEditor layout: GridEditor {
    host: root.host
    area: GridPlacement.screenGrid(root.localLayout)
    sizeScale: root.localLayout?.fineGrid ? 2 : 1
    modulesOf: () => root.localLayout?.modules ?? null
    scopeKey: root.host
    onEdited: draft.changed()
  }

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: root.layout.problemsFor(root.localLayout?.modules, root.name)

  // Loads the draft unless it holds unsaved edits
  function ensureLoaded() {
    if (!draft.isDirty)
      root.resetChanges();
  }

  // One of the layout's own fields (columns, background, …). Doubling the
  // grid (fineGrid) rescales the modules' places so they stay put
  function updateLayoutField(key, value) {
    const layout = root.localLayout;
    if (!layout || JSON.stringify(layout[key]) === JSON.stringify(value))
      return;
    if (key === "fineGrid")
      (layout.modules ?? []).forEach(module => {
        if (module?.place)
          module.place = GridPlacement.scalePlace(module.place, value);
      });
    layout[key] = value;
    draft.changed();
  }

  // Merged onto the latest real config; stays dirty if rejected
  function saveChanges() {
    if (root.problems.length > 0)
      return false;
    return draft.save();
  }

  function resetChanges() {
    draft.load();
    root.layout.clearSelection();
  }

  // --- Preview ---

  // The draft shown on the target screen in a plain window, with every
  // field and action inert
  readonly property bool previewing: root._previewing
  property bool _previewing: false
  // The screen it shows on: the target when it started, so it stays put
  readonly property string previewScreen: root._previewScreen
  property string _previewScreen: ""

  // Closes the overlay to show it
  function startPreview() {
    if (root._previewing)
      return;
    ShellManager.closeOverlay();
    root._previewScreen = ShellManager.targetFor();
    root._previewing = true;
  }

  // Back to the layouts editor, unless `reopen` is false
  function stopPreview(reopen) {
    if (!root._previewing)
      return;
    root._previewing = false;
    if (reopen !== false)
      ShellManager.openOverlayPage("Layouts");
  }
}
