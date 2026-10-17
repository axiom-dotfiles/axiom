pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

/*
 * Axiom's layer applied at runtime, for a compositor's config writer: the
 * detached mode, and the fallback of the file modes while their file isn't
 * loaded (docs/dev/compositor/config-modes.md). The compositor's binds are
 * read first, so a bind on a key the user's config already takes is
 * skipped (skippedKeys). Not a singleton: each backend's runtime layer
 * (HyprlandRuntimeLayer, SwayRuntimeLayer) is one, setting the hooks below,
 * and its config writer owns it.
 */
QtObject {
  id: root

  // The config writer's name, to start log lines with
  property string logTag: ""
  // The compositor's, as the user's config is named ("Hyprland", "sway")
  property string configName: ""

  // Reads the binds in effect that aren't this layer's (BindKeys' entries,
  // or null) and calls back with them and anything `send` needs too
  property var readBinds: callback => callback([], null)
  // Whether the compositor can bind a configured bind
  property var canBind: bind => false
  // Applies the binds that are free, and the rest of the layer (the look,
  // the input, …)
  property var send: (binds, context) => {}
  // Takes out what the layer bound
  property var takeOut: () => {}

  // A config reload dropped the layer: a backend forgets what it applied
  signal reloaded

  // Configured keys skipped because the user's config already binds them
  readonly property var skippedKeys: _skippedKeys
  property var _skippedKeys: []
  // axiom's binds this layer bound, for the Keybinds page
  readonly property var applied: _applied
  property var _applied: []

  // Keys skipped as taken, so each is only reported once
  property var _reportedTaken: ({})
  property bool _wanted: false
  property bool _busy: false
  // Config reloads seen, and how many when the layer last started reading
  // the binds: one in between makes what it read stale (another config's
  // keys, or none while the file was being replaced), and drops what it
  // bound since
  property int _reloads: 0
  property int _startedAt: 0

  // The compositor reloaded its config, dropping the layer
  function noteReload() {
    _reloads++;
    root.reloaded();
  }

  // Applies the layer: reads the binds, then binds the keys that are free
  // and sends the rest
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
    root.takeOut();
    KeybindManager.refreshSoon();
  }

  function _start() {
    _busy = true;
    _startedAt = _reloads;
    root.readBinds((entries, context) => {
      root._busy = false;
      root._finish(entries ?? [], context);
    });
  }

  function _finish(entries, context) {
    if (!_wanted)
      return;
    if (_startedAt !== _reloads) {
      _start();
      return;
    }
    const plan = BindKeys.runtimeBinds(KeybindsConfig.binds.filter(bind => root.canBind(bind)), entries);
    for (const key of plan.unreadable)
      console.warn(`[${root.logTag}] Can't read the key "${key}"; bind it as MODS + KEY`);
    for (const key of plan.skipped) {
      const id = BindKeys.keyId(key);
      if (!_reportedTaken[id])
        console.log(`[${root.logTag}] ${key} is bound by your ${root.configName} config; skipping axiom's bind`);
      _reportedTaken[id] = true;
    }
    _skippedKeys = plan.skipped;
    _applied = plan.apply;
    root.send(plan.apply, context);
    KeybindManager.refreshSoon();
  }
}
