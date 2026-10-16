pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

/*
 * Axiom's Hyprland layer evaluated at runtime, for HyprlandConfigWriter:
 * the detached mode, and the fallback of the file modes while their file
 * isn't loaded. Hyprland's binds are read first, so a bind on a key the
 * user's config already takes is skipped (skippedKeys). Not a singleton:
 * HyprlandConfigWriter owns one.
 *
 * Keys this layer bound live in Hyprland's Lua state (AXIOM_RUNTIME_KEYS),
 * which a config reload resets along with the binds, and which outlives a
 * reload of the shell. They're unbound before the binds are read, so they
 * don't look like the user's.
 */
QtObject {
  id: root

  // What the bind Lua needs from outside the bind (HyprConfigLua.bindLua)
  property var bindCtx: ({})
  // Functions returning Lua lines: the window look and the blur
  // (HyprlandConfigWriter marks the look applied), and the strips
  property var lookLines: () => []
  property var stripsLines: () => []

  // Configured keys skipped because Hyprland's config already binds them
  readonly property var skippedKeys: _skippedKeys
  property var _skippedKeys: []

  readonly property string _unbindLua: "for _, key in ipairs(AXIOM_RUNTIME_KEYS or {}) do hl.unbind(key) end\nAXIOM_RUNTIME_KEYS = nil"
  // The monitor profiles (JSON) this layer last applied
  property var _monitorsApplied: null
  // Keys skipped as taken, so each is only reported once
  property var _reportedTaken: ({})
  property bool _wanted: false
  property bool _busy: false

  // Hyprland config reloads seen, and how many there were when the layer
  // last started reading Hyprland's binds: one in between makes what it
  // read stale (taken keys from another config, or none at all while
  // hyprland.lua was being replaced), and binding from it would leave
  // AXIOM_RUNTIME_KEYS naming the loaded config's own keys, which clear()
  // would then unbind
  property int _reloads: 0
  property int _startedAt: 0

  // A Hyprland config reload dropped the layer (and its monitors)
  function noteReload() {
    _reloads++;
    _monitorsApplied = null;
  }

  // Applies the layer: unbinds what it bound last, reads Hyprland's binds
  // and animations, then evaluates the binds that are free and the rest
  function apply() {
    _wanted = true;
    if (!_busy)
      _start();
  }

  // Takes the layer's binds out (the file is loaded now)
  function clear() {
    _wanted = false;
    _monitorsApplied = null;
    _skippedKeys = [];
    HyprlandManager.runLua(_unbindLua);
    KeybindManager.refreshSoon();
  }

  function _start() {
    _busy = true;
    _startedAt = _reloads;
    // Queued: binds still waiting to be evaluated would otherwise land
    // after the unbind and read as the user's
    HyprlandManager.runLua(_unbindLua, () => {
      HyprlandManager.withBinds(binds => {
        HyprlandManager.withAnimations(animations => {
          root._busy = false;
          root._finish(binds ?? [], animations);
        });
      });
    });
  }

  function _finish(bindList, animations) {
    if (!_wanted)
      return;
    if (_startedAt !== _reloads) {
      _start();
      return;
    }
    const binds = KeybindsConfig.binds.filter(bind => HyprConfigLua.bindLua(bind, bindCtx) !== "");
    const plan = BindKeys.runtimeBinds(binds, bindList);
    for (const key of plan.unreadable)
      console.warn(`[HyprlandConfigWriter] Can't read the key "${key}"; bind it as MODS + KEY`);
    for (const key of plan.skipped) {
      const id = BindKeys.keyId(key);
      if (!_reportedTaken[id])
        console.log(`[HyprlandConfigWriter] ${key} is bound by your Hyprland config; skipping axiom's bind`);
      _reportedTaken[id] = true;
    }
    const lines = HyprConfigLua.bindLines(plan.apply, bindCtx);
    const keys = plan.apply.map(bind => bind.key.trim());
    if (CompositorConfig.requiredSettings) {
      const anim = (Array.isArray(animations?.[0]) ? animations[0] : []).find(a => a.name === "workspaces");
      lines.push(...HyprConfigLua.requiredLua(!anim?.overridden));
    }
    lines.push(...lookLines());
    // Monitors only when their profiles changed, or a reload dropped them:
    // re-applying them unchanged could still flicker a mode set
    if (_monitorsApplied !== MonitorsConfig._profilesJson) {
      lines.push(...HyprLua.monitorsLua(MonitorsConfig.profiles));
      _monitorsApplied = MonitorsConfig._profilesJson;
    }
    lines.push(...stripsLines());
    lines.push(`AXIOM_RUNTIME_KEYS = { ${keys.map(key => HyprLua.string(key)).join(", ")} }`);
    _skippedKeys = plan.skipped;
    HyprlandManager.runLua(lines.join("\n"));
    HyprlandManager.refreshOptions();
    KeybindManager.refreshSoon();
  }
}
