pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.methods

/*
 * Axiom's Hyprland layer evaluated at runtime (RuntimeLayer), for
 * HyprlandConfigWriter, which owns it.
 *
 * Keys this layer bound live in Hyprland's Lua state (AXIOM_RUNTIME_KEYS),
 * which a config reload resets along with the binds, and which outlives a
 * reload of the shell. They're unbound before the binds are read, so they
 * don't look like the user's.
 */
RuntimeLayer {
  id: root

  // What the bind Lua needs from outside the bind (HyprConfigLua.bindLua)
  property var bindCtx: ({})
  // Functions returning Lua lines: the window look and the blur
  // (HyprlandConfigWriter marks the look applied), and the strips
  property var lookLines: () => []
  property var stripsLines: () => []

  readonly property string _unbindLua: "for _, key in ipairs(AXIOM_RUNTIME_KEYS or {}) do hl.unbind(key) end\nAXIOM_RUNTIME_KEYS = nil"
  // The monitor profiles (JSON) this layer last applied
  property var _monitorsApplied: null

  logTag: "HyprlandConfigWriter"
  configName: "Hyprland"
  canBind: bind => HyprConfigLua.bindLua(bind, root.bindCtx) !== ""
  // Unbinding first, queued: binds still waiting to be evaluated would
  // otherwise land after the unbind and read as the user's. The
  // animations say whether the user's config sets the workspaces' own.
  readBinds: callback => HyprlandManager.runLua(root._unbindLua, () => {
      HyprlandManager.withBinds(binds => {
        HyprlandManager.withAnimations(animations => callback(binds, animations));
      });
    })
  send: (binds, animations) => {
    const lines = HyprConfigLua.bindLines(binds, root.bindCtx);
    if (CompositorConfig.requiredSettings) {
      const anim = (Array.isArray(animations?.[0]) ? animations[0] : []).find(a => a.name === "workspaces");
      lines.push(...HyprConfigLua.requiredLua(!anim?.overridden));
    }
    lines.push(...root.lookLines());
    // Monitors only when their profiles changed, or a reload dropped them:
    // re-applying them unchanged could still flicker a mode set
    if (root._monitorsApplied !== MonitorsConfig._profilesJson) {
      lines.push(...HyprLua.monitorsLua(MonitorsConfig.profiles));
      root._monitorsApplied = MonitorsConfig._profilesJson;
    }
    lines.push(...root.stripsLines());
    lines.push(`AXIOM_RUNTIME_KEYS = { ${binds.map(bind => HyprLua.string(HyprConfigLua.bindKey(bind.key))).join(", ")} }`);
    HyprlandManager.runLua(lines.join("\n"));
    HyprlandManager.refreshOptions();
  }
  takeOut: () => {
    root._monitorsApplied = null;
    HyprlandManager.runLua(root._unbindLua);
  }
  // A reload dropped its monitors too
  onReloaded: root._monitorsApplied = null
}
