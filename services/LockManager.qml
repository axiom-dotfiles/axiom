pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

// The one way to lock the session, whatever locks it (Lockscreen.mode):
//   "quickshell"  the built-in locker (shell/Lockscreen.qml: Wayland
//                 session lock + PAM through AuthManager)
//   "hyprlock"    hyprlock, with a config ThemeManager generates from the
//                 axiom theme
//   "none"        the user's own locker: runs Lockscreen.lockCommand
// Lock buttons call lock(); idle daemons call the `lockscreen` IPC target
// (`qs -c axiom ipc call lockscreen lock`), which exists only when axiom
// provides the locker, so "none" can't loop through loginctl lock-session.
//
// Also holds the layouts editor's draft of the built-in lock screen
// (Lockscreen.layout: its modules on a bounded grid, edited through
// `layout`) and its preview on screen. The lock itself only ever shows the
// saved layout (LockscreenConfig.layout).
QtObject {
  id: root

  readonly property string mode: LockscreenConfig.mode
  // Where ThemeManager writes the themed hyprlock config
  readonly property string hyprlockConfigPath: Paths.userStatePath + "hyprlock.conf"

  // The built-in lock is up (set by shell/Lockscreen.qml, which owns it)
  property bool builtinLocked: false

  // For the built-in locker
  signal lockRequested
  // Any lock started: menus and popups can close
  signal lockStarted

  function lock() {
    root.stopPreview(false);
    switch (root.mode) {
    case "quickshell":
      root.lockRequested();
      break;
    case "hyprlock":
      // Generated first if a theme change hasn't written it yet
      if (FileManager.read("file://" + root.hyprlockConfigPath))
        root._runHyprlock();
      else
        ThemeManager.generateHyprlockConfig(root._runHyprlock);
      break;
    default:
      if (LockscreenConfig.lockCommand)
        Quickshell.execDetached(["sh", "-c", LockscreenConfig.lockCommand]);
    }
    root.lockStarted();
  }

  function _runHyprlock() {
    Quickshell.execDetached(["sh", "-c", 'pidof hyprlock >/dev/null || exec hyprlock -c "$1"', "sh", root.hyprlockConfigPath]);
  }

  // --- The password field ---

  // Which lock surfaces show a Password module (by the key their host
  // gives it): a surface without one shows a fallback field of its own, so
  // a broken layout can never lock anyone out
  readonly property var passwordFields: root._passwordFields
  property var _passwordFields: ({})

  // A key for one lock surface, never reused: a screen that drops out and
  // comes back (a monitor turned off) gets a new surface while the old one
  // is still being torn down, and a key shared by screen name let the old
  // Password module's goodbye clear the new one's report, flickering in the
  // fallback field
  property int _surfaceCount: 0
  function newSurfaceKey(preview) {
    root._surfaceCount += 1;
    return (preview ? "preview:" : "lock:") + root._surfaceCount;
  }

  function reportPasswordField(key, present) {
    if (!key || (root._passwordFields[key] === true) === present)
      return;
    root._passwordFields = Utils.withEntry(root._passwordFields, key, present ? true : undefined);
  }

  // --- The layouts editor's draft (Lockscreen.layout) ---

  property ConfigDraft _draft: ConfigDraft {
    id: draft
    path: ["Lockscreen", "layout"]
  }
  readonly property alias localLayout: draft.local
  readonly property alias savedLayout: draft.saved
  readonly property alias isDirty: draft.isDirty

  property GridEditor layout: GridEditor {
    host: "lockscreen"
    area: LockscreenConfig.gridOf(root.localLayout)
    sizeScale: root.localLayout?.fineGrid ? 2 : 1
    modulesOf: () => root.localLayout?.modules ?? null
    scopeKey: "lockscreen"
    onEdited: draft.changed()
  }

  // Why the draft can't be saved as is (empty = savable)
  readonly property var problems: root.layout.problemsFor(root.localLayout?.modules, I18n.tr("Lock screen"))

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

  // The draft shown on the target screen in a plain window (shell/
  // Lockscreen.qml), with the password field inert: nothing is locked
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

  // Switching to hyprlock writes its config straight away
  onModeChanged: if (mode === "hyprlock")
    ThemeManager.generateHyprlockConfig()
  Component.onCompleted: if (mode === "hyprlock")
    ThemeManager.generateHyprlockConfig()

  property IpcHandler _ipc: IpcHandler {
    target: "lockscreen"
    enabled: root.mode !== "none"

    function lock(): void {
      root.lock();
    }
  }
}
