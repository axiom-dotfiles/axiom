pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

/*
 * Moves the user's binds into axiom (managed mode), through the daemon
 * (`compositor.binds`: backend/internal/compositor/binds, the same verbs
 * and JSON on every compositor), for that compositor's config writer. Not
 * a singleton: each config writer owns one (docs/dev/hyprland/bind-merge.md).
 *
 * Every bind in user/ that can move becomes one of axiom's binds (an
 * action where one does the same, else the compositor's raw command),
 * saved first, then it's taken out of its file (a dated backup kept). A
 * bind that couldn't be has its binds taken back out of axiom's, so no
 * key is ever bound twice. A key axiom binds too stays one bind, the
 * user's replacing axiom's (BindKeys.mergeBinds). Runs by itself on the
 * adopted file when a takeover adopts the previous config, so managed mode
 * starts with no conflicts; the Keybinds page's Merge runs it on all of
 * user/.
 */
QtObject {
  id: root

  // Merging only happens in managed mode
  property bool enabled: false
  // The compositor (`kind`: hyprland, sway or niri), its config folder,
  // and its user/ folder
  property string kind: ""
  property string configDir: ""
  property string userDir: ""
  // The config writer's name, to start log lines with
  property string logTag: ""

  readonly property bool merging: _extracting || _removing
  // The last merge: { moved, removed, kept: [{ file, line, key, reason,
  // detail }], failed: [{ file, line, reason, detail }], remapped: [{ from,
  // to, action }], tracked: [file], errors: [text], saveFailed }, or null.
  // Reasons are codes (the merge's, and "crashed"), which the
  // Keybinds page translates
  property var lastMerge: null
  // How many binds a Merge of all of user/ would move (previewMerge());
  // -1 until looked
  property int mergeable: -1
  // The binds a merge moved in for good (KeybindManager adds them to a
  // draft with unsaved edits)
  signal bindsMerged(var binds)

  // `only`: one file name in user/ (the adopted one), else all of them
  function mergeUserBinds(only) {
    if (!enabled || merging)
      return;
    _preview = false;
    _extract(only);
  }

  // Counts what a Merge would move, changing nothing (`mergeable`)
  function previewMerge() {
    if (!enabled || merging)
      return;
    _preview = true;
    _extract("");
  }

  property bool _extracting: false
  property bool _removing: false
  property bool _preview: false
  property var _merged: null
  // The saved binds before a merge, and its sites, to take back what
  // couldn't be deleted
  property var _before: []
  property var _sites: []

  // Runs a merge verb, calling back with the daemon's error (or null) and
  // its JSON
  function _call(verb, params, callback) {
    BackendManager.call("compositor.binds", Object.assign({
      "verb": verb,
      "kind": root.kind,
      "dir": root.configDir
    }, params), callback);
  }

  function _extract(only) {
    _extracting = true;
    _call("extract", {
      "only": only || ""
    }, (err, found) => {
      root._extracting = false;
      root._extracted(err, found);
    });
  }

  function _extracted(err, found) {
    if (err) {
      if (_preview) {
        mergeable = 0;
        return;
      }
      console.warn(`[${root.logTag}] Reading your binds failed:`, err.message);
      lastMerge = {
        "moved": 0,
        "removed": 0,
        "kept": [],
        "failed": [],
        "remapped": [],
        "tracked": [],
        "errors": [err.message]
      };
      return;
    }
    if (_preview) {
      mergeable = found.binds.length;
      return;
    }
    _merged = {
      "moved": found.binds.length,
      "removed": 0,
      "kept": found.kept,
      "failed": [],
      "remapped": found.remapped,
      "tracked": found.tracked,
      "errors": found.errors
    };
    if (found.binds.length === 0) {
      lastMerge = _merged;
      mergeable = 0;
      return;
    }
    // Saved before the calls go, so no bind is ever missing
    _before = KeybindsConfig.binds;
    _sites = found.sites;
    if (!SettingsManager.commitValues({
      "Keybinds.binds": BindKeys.mergeBinds(_before, found.binds)
    })) {
      _merged.moved = 0;
      _merged.saveFailed = true;
      lastMerge = _merged;
      return;
    }
    _removing = true;
    _call("remove", {
      "sites": found.sites
    }, (err, result) => {
      root._removing = false;
      let done = result;
      if (err) {
        // Nothing is known to be deleted: every file's binds go back
        done = {
          "removed": 0,
          "files": []
        };
        done.failed = root._sites.map(site => ({
              "file": site.file,
              "line": 0,
              "reason": "crashed",
              "detail": err.message
            })).filter((f, i, all) => all.findIndex(other => other.file === f.file) === i);
      }
      root._removed(done);
    });
  }

  // After the removal: the binds whose call is still in its file go back
  // out of axiom's (the saved binds from before, with only the rest merged)
  function _removed(done) {
    const left = site => done.failed.some(f => f.file === site.file && (f.line === 0 || f.line === site.line));
    const moved = [].concat(..._sites.filter(site => !left(site)).map(site => site.binds));
    if (done.failed.length > 0 && !SettingsManager.commitValues({
      "Keybinds.binds": BindKeys.mergeBinds(_before, moved)
    }))
      console.warn(`[${root.logTag}] Couldn't take the binds left in your config back out of axiom's`);
    _merged.moved = moved.length;
    _merged.removed = done.removed;
    _merged.failed = done.failed;
    for (const failure of done.failed)
      console.warn(`[${root.logTag}] Left the binds in`, failure.file, failure.line > 0 ? `(line ${failure.line})` : "", "where they were:", failure.reason, failure.detail);
    if (moved.length > 0)
      bindsMerged(moved);
    lastMerge = _merged;
    mergeable = -1;
    console.log(`[${root.logTag}] Moved ${moved.length} binds from ${userDir} into axiom; ${_merged.kept.length} stay there`);
  }
}
