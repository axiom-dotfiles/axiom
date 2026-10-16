pragma ComponentBehavior: Bound
import QtQuick

import qs.config

/*
 * Taking ~/.config/sway/config over for the managed mode, and giving it
 * back (scripts/claim_sway.sh), for SwayConfigWriter, which acts on the
 * results (claimed, blocked, released). HyprlandTakeover's counterpart.
 * Not a singleton: SwayConfigWriter owns one.
 */
QtObject {
  id: root

  // CompositorConfig.mode, to tell what the results are for
  property string mode: ""
  // ~/.config/sway/, the managed config in it and its user/ folder
  property string swayPath: ""
  property string managedPath: ""
  property string userDir: ""
  // The generated files' first line, and the config a release writes when
  // nothing was set aside (SwayConf.releasedText)
  property string header: ""
  property string releasedText: ""

  // The takeover worked ("ours", "adopted", "created" or "replaced"), the
  // old config adopted as user/`adopted` (or "")
  signal claimed(string result, string adopted)
  // The config is a symlink or git-tracked, so it's never taken over
  signal blocked
  // A release finished: "restored", "written", "notours" or "blocked"
  signal released(string result)

  // What switching to managed would do (claim_sway.sh check): "ours",
  // "adopt", "stock", "released", "new" or "blocked"; "" until checked
  readonly property string managedCheck: _managedCheck.split(":")[0]
  // Why it's blocked: "link" or "git" (in the repository `managedBlockedRepo`)
  readonly property string managedBlockedBy: managedCheck === "blocked" ? _managedCheck.split(":")[1] ?? "" : ""
  readonly property string managedBlockedRepo: managedBlockedBy === "git" ? _managedCheck.split(":").slice(2).join(":") : ""
  property string _managedCheck: ""

  // Managed mode: the files in user/ that set outputs themselves. They load
  // after axiom's config, and MonitorManager's profiles only apply once
  // axiom runs.
  readonly property var monitorConflicts: _monitorConflicts
  property var _monitorConflicts: []

  property bool _checking: false
  property bool _claiming: false
  property bool _finding: false
  // Callers waiting for a check's answer
  property var _checkWaiting: []

  function _script(verb) {
    return [Paths.scriptsPath + "claim_sway.sh", verb, swayPath, header, releasedText];
  }

  // Looks again what a takeover would do (`managedCheck`), then calls back
  // with it
  function checkManaged(callback) {
    if (callback)
      _checkWaiting.push(callback);
    if (_checking)
      return;
    _checking = true;
    CommandManager.run(_script("check"), (code, out) => {
      root._checking = false;
      root._managedCheck = out.trim();
      const waiting = root._checkWaiting;
      root._checkWaiting = [];
      waiting.forEach(callback => callback(root.managedCheck));
    });
  }

  function findMonitorConflicts() {
    if (_finding)
      return;
    _finding = true;
    CommandManager.run(["sh", "-c", 'cd "$1" 2>/dev/null && grep -lE "^[[:space:]]*output[[:space:]]+[^[:space:]]+[[:space:]]+(mode|res|resolution|pos|position|scale|transform|enable|disable|power)" -- * 2>/dev/null', "sh", userDir], (code, out) => {
      root._finding = false;
      root._monitorConflicts = root.mode === "managed" ? out.split("\n").filter(name => name !== "").map(name => root.userDir + "/" + name) : [];
    });
  }

  function clearConflicts() {
    _monitorConflicts = [];
  }

  // Makes ~/.config/sway/config axiom's (claim_sway.sh claim)
  function claim() {
    if (_claiming)
      return;
    _claiming = true;
    CommandManager.run(_script("claim"), (code, out, err) => {
      root._claiming = false;
      if (err.trim() !== "")
        console.warn("[SwayConfigWriter] Taking over the sway config:", err.trim());
      const words = out.trim().split(":");
      const result = words[0];
      if (result === "blocked") {
        root.blocked();
        return;
      }
      if (result === "adopted")
        console.log(`[SwayConfigWriter] Took over ${root.managedPath}; your previous one is ${root.userDir}/${words[1]}`);
      else if (result === "replaced")
        console.log(`[SwayConfigWriter] Replaced ${root.managedPath} (sway's example config is kept as a dated backup beside it)`);
      if (["ours", "adopted", "created", "replaced"].includes(result))
        root.claimed(result, result === "adopted" ? words[1] ?? "" : "");
    });
  }

  // Gives ~/.config/sway/config back on leaving managed (claim_sway.sh
  // release)
  function release() {
    CommandManager.run(_script("release"), (code, out, err) => {
      if (err.trim() !== "")
        console.warn("[SwayConfigWriter] Giving back the sway config:", err.trim());
      const words = out.trim().split(":");
      const result = words[0];
      if (result === "restored") {
        console.log(`[SwayConfigWriter] Gave back ${root.managedPath}: it's ${words[1]} again`);
        if (Number(words[2]) > 0)
          console.warn(`[SwayConfigWriter] ${root.managedPath} is your previous config again, which doesn't include ${root.userDir}/ (${words[2]} files): include them from it if you still want them`);
      } else if (result === "written") {
        console.log(`[SwayConfigWriter] Gave back ${root.managedPath}: it now starts axiom and includes ${root.userDir}/, and is yours to edit`);
      } else if (result === "blocked") {
        console.warn(`[SwayConfigWriter] ${root.managedPath} is a symlink or in a git repository, so axiom didn't give it back: it still is axiom's managed config`);
      }
      root.released(result);
    });
  }
}
