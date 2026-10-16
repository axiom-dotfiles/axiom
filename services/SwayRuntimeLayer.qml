pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.components.methods

/*
 * Axiom's sway layer sent at runtime, for SwayConfigWriter: the detached
 * mode, and the fallback of the file modes while their file isn't loaded.
 * The user's own binds are read from their config files first (sway can't
 * list its binds), so a bind on a key their config already takes is skipped
 * (skippedKeys). Not a singleton: SwayConfigWriter owns one.
 *
 * The keys this layer bound are kept (as the commands unbinding them) in a
 * PersistentProperties, so a reload of the shell takes them out before
 * binding again; a sway reload drops them itself (noteReload).
 */
QtObject {
  id: root

  // What the bind commands need from outside the bind (SwayConf.command)
  property var bindCtx: ({})
  // A function returning the live lines (the look and the input)
  property var lookLines: () => []
  // A function calling back with the user's binds (SwayConf.configBinds
  // entries), or null when they couldn't be read
  property var readUserBinds: callback => callback([])

  // Configured keys skipped because the user's sway config binds them
  readonly property var skippedKeys: _skippedKeys
  property var _skippedKeys: []
  // axiom's binds this layer has bound, for the Keybinds page
  readonly property var applied: _applied
  property var _applied: []

  property PersistentProperties _state: PersistentProperties {
    id: persisted
    reloadableId: "axiomSwayRuntime"
    // The commands taking out what this layer bound (JSON)
    property string unbindJson: "[]"
  }

  // Keys skipped as taken, so each is only reported once
  property var _reportedTaken: ({})
  property bool _wanted: false
  property bool _busy: false
  // Sway config reloads seen, and how many when the layer last started
  // reading the user's binds: one in between drops what it bound since
  property int _reloads: 0
  property int _startedAt: 0

  // A sway config reload dropped the layer's binds
  function noteReload() {
    _reloads++;
    persisted.unbindJson = "[]";
  }

  // Applies the layer: reads the user's binds, then binds the keys that are
  // free (unbinding what it bound last) and sends the live lines
  function apply() {
    _wanted = true;
    if (!_busy)
      _start();
  }

  // Takes the layer's binds out (the file is loaded now)
  function clear() {
    _wanted = false;
    _skippedKeys = [];
    _applied = [];
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = "[]";
    if (unbind.length > 0)
      SwayManager.runCommands(unbind);
    KeybindManager.refreshSoon();
  }

  function _start() {
    _busy = true;
    _startedAt = _reloads;
    root.readUserBinds(entries => {
      root._busy = false;
      root._finish(entries ?? []);
    });
  }

  function _finish(entries) {
    if (!_wanted)
      return;
    if (_startedAt !== _reloads) {
      _start();
      return;
    }
    const binds = KeybindsConfig.binds.filter(bind => SwayConf.isComplete(bind, bindCtx));
    const plan = BindKeys.runtimeBinds(binds, entries);
    for (const key of plan.unreadable)
      console.warn(`[SwayConfigWriter] Can't read the key "${key}"; bind it as MODS + KEY`);
    for (const key of plan.skipped) {
      const id = BindKeys.keyId(key);
      if (!_reportedTaken[id])
        console.log(`[SwayConfigWriter] ${key} is bound by your sway config; skipping axiom's bind`);
      _reportedTaken[id] = true;
    }
    const unbind = JSON.parse(persisted.unbindJson);
    persisted.unbindJson = JSON.stringify(SwayConf.unbindLines(plan.apply, bindCtx));
    _skippedKeys = plan.skipped;
    _applied = plan.apply;
    // Sent apart, in order: sway stops a command list at an invalid
    // command, so a bind it refuses would take the look with it
    for (const lines of [unbind, SwayConf.bindLines(plan.apply, bindCtx, true)]) {
      if (lines.length > 0)
        SwayManager.runCommands(lines);
    }
    // Sway sends no event for a gap change: the windows are read again
    SwayManager.runCommands(lookLines(), () => SwayManager.refresh());
    KeybindManager.refreshSoon();
  }
}
