pragma ComponentBehavior: Bound
import QtQuick

import qs.config

/*
 * Taking ~/.config/hypr/hyprland.lua over for the managed mode, and giving
 * it back (scripts/claim_hyprland.sh), for HyprlandConfigWriter, which
 * acts on the results (claimed, blocked, released). Not a singleton:
 * HyprlandConfigWriter owns one.
 */
QtObject {
  id: root

  // HyprlandConfigWriter.mode, to tell what the results are for
  property string mode: ""
  // ~/.config/hypr/, the managed hyprland.lua in it and its user/ folder
  property string hyprlandPath: ""
  property string managedPath: ""
  property string userDir: ""
  // The generated files' first line, and the hyprland.lua a release
  // writes when nothing was set aside (HyprConfigLua.releasedLua)
  property string header: ""
  property string releasedLua: ""

  // The takeover worked ("ours", "adopted", "created" or "replaced"), the
  // old config adopted as user/`adopted` (or "")
  signal claimed(string result, string adopted)
  // The config is a symlink or git-tracked, so it's never taken over
  signal blocked
  // A release finished: "restored", "written", "notours" or "blocked"
  signal released(string result)

  // What switching to managed would do, from checkManaged(): "ours" (the
  // file is already axiom's), "adopt" (an existing hyprland.lua is moved to
  // user/), "stock" (it's Hyprland's example config, maybe with install.sh's
  // autostart line, only backed up), "released" (the one leaving managed
  // wrote, unedited: replaced, not kept), "new" (there's none) or
  // "blocked" (a symlinked or git-tracked config is never taken over); ""
  // until checked
  readonly property string managedCheck: _managedCheck.split(":")[0]
  // Why it's blocked: "link" or "git" (in the repository `managedBlockedRepo`)
  readonly property string managedBlockedBy: managedCheck === "blocked" ? _managedCheck.split(":")[1] ?? "" : ""
  readonly property string managedBlockedRepo: managedBlockedBy === "git" ? _managedCheck.split(":").slice(2).join(":") : ""
  property string _managedCheck: ""

  // Managed mode: the user/*.lua files that set monitors themselves. They
  // load after axiom's profiles, so their rules win.
  readonly property var monitorConflicts: _monitorConflicts
  property var _monitorConflicts: []

  property bool _checking: false
  property bool _claiming: false
  property bool _finding: false

  function _script(verb) {
    return [Paths.scriptsPath + "claim_hyprland.sh", verb, hyprlandPath, header, releasedLua];
  }

  function checkManaged() {
    if (_checking)
      return;
    _checking = true;
    CommandManager.run(_script("check"), (code, out) => {
      root._checking = false;
      root._managedCheck = out.trim();
    });
  }

  // Looks for user/*.lua files that set monitors (managed mode only)
  function findMonitorConflicts() {
    if (_finding)
      return;
    _finding = true;
    CommandManager.run(["sh", "-c", 'cd "$1" 2>/dev/null && grep -lE "^[[:space:]]*hl\\.monitor[[:space:]]*\\(" -- *.lua 2>/dev/null', "sh", userDir], (code, out) => {
      root._finding = false;
      root._monitorConflicts = root.mode === "managed" ? out.split("\n").filter(name => name !== "").map(name => root.userDir + "/" + name) : [];
    });
  }

  function clearConflicts() {
    _monitorConflicts = [];
  }

  // Makes ~/.config/hypr/hyprland.lua axiom's: "ours" (already),
  // "adopted:<name>" (the old one moved to user/<name>, its lines starting
  // or loading axiom commented out, a dated backup beside it), "created"
  // (there was none), "replaced" (Hyprland's example config, only kept as
  // the backup: its binds and monitor rule would fight axiom's) or
  // "blocked" (a symlinked or git-tracked config is never taken over)
  function claim() {
    if (_claiming)
      return;
    _claiming = true;
    CommandManager.run(_script("claim"), (code, out, err) => {
      root._claiming = false;
      if (err.trim() !== "")
        console.warn("[HyprlandConfigWriter] Taking over hyprland.lua:", err.trim());
      const words = out.trim().split(":");
      const result = words[0];
      if (result === "blocked") {
        root.blocked();
        return;
      }
      if (result === "adopted")
        console.log(`[HyprlandConfigWriter] Took over ${root.managedPath}; your previous one is ${root.userDir}/${words[1]}`);
      else if (result === "replaced")
        console.log(`[HyprlandConfigWriter] Replaced ${root.managedPath} (Hyprland's example config is kept as a dated backup beside it; the one axiom gave back isn't kept)`);
      if (["ours", "adopted", "created", "replaced"].includes(result))
        root.claimed(result, result === "adopted" ? words[1] ?? "" : "");
    });
  }

  // Gives ~/.config/hypr/hyprland.lua back on leaving managed:
  // "restored:<from>:<n>" (what the takeover set aside: the adopted
  // user/00-previous*.lua, its lines that start or load axiom enabled
  // again, or the example config's backup; <n> files left in user/ that it
  // doesn't load), "written" (nothing was set aside: releasedLua),
  // "notours" (already the user's) or "blocked" (a symlinked or
  // git-tracked one, never written)
  function release() {
    CommandManager.run(_script("release"), (code, out, err) => {
      if (err.trim() !== "")
        console.warn("[HyprlandConfigWriter] Giving back hyprland.lua:", err.trim());
      const words = out.trim().split(":");
      const result = words[0];
      if (result === "restored") {
        console.log(`[HyprlandConfigWriter] Gave back ${root.managedPath}: it's ${words[1]} again`);
        if (Number(words[2]) > 0)
          console.warn(`[HyprlandConfigWriter] ${root.managedPath} is your previous config again, which doesn't load ${root.userDir}/*.lua (${words[2]} files): load them from it if you still want them`);
      } else if (result === "written") {
        console.log(`[HyprlandConfigWriter] Gave back ${root.managedPath}: it now starts axiom and loads ${root.userDir}/*.lua, and is yours to edit`);
      } else if (result === "blocked") {
        console.warn(`[HyprlandConfigWriter] ${root.managedPath} is a symlink or in a git repository, so axiom didn't give it back: it still loads axiom's managed layer`);
      }
      root.released(result);
    });
  }
}
