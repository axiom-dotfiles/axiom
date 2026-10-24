pragma ComponentBehavior: Bound
import QtQuick

/*
 * Taking a compositor's config over for the managed mode, and giving it
 * back, through the daemon (`compositor.takeover`: backend/internal/
 * compositor/takeover, the same verbs and results on every compositor),
 * for that compositor's config writer,
 * which acts on the results (claimed, blocked, released). Not a singleton:
 * each config writer owns one (docs/dev/compositor/config-modes.md).
 */
QtObject {
  id: root

  // CompositorConfig.mode, to tell what the results are for
  property string mode: ""
  // The compositor (`takeover.KindNamed`'s name), and its config folder
  property string kind: ""
  property string configDir: ""
  // The managed config in it, its user/ folder, and the user's files there
  // as the managed config loads them ("user/*.lua")
  property string managedPath: ""
  property string userDir: ""
  property string userFiles: ""
  // The generated files' first line, and the config a release writes when
  // nothing was set aside
  property string header: ""
  property string releasedText: ""
  // What sets monitors in a user file (an extended regex, matched per
  // line), and which of user/'s files load (a glob)
  property string monitorPattern: ""
  property string monitorGlob: "*"
  // The config writer's name, to start log lines with
  property string logTag: ""

  // The takeover worked ("ours", "adopted", "created" or "replaced"), the
  // old config adopted as user/`adopted` (or "")
  signal claimed(string result, string adopted)
  // The config is a symlink or git-tracked, so it's never taken over
  signal blocked
  // A release finished: "restored", "written", "notours" or "blocked"
  signal released(string result)

  // What switching to managed would do, from checkManaged(): "ours" (the
  // file is already axiom's), "adopt" (an existing config is moved to
  // user/), "stock" (it's the compositor's example config, maybe with an
  // autostart line, only backed up), "released" (the one leaving managed
  // wrote, unedited: replaced, not kept), "new" (there's none) or
  // "blocked" (a symlinked or git-tracked config is never taken over); ""
  // until checked
  readonly property string managedCheck: _managedCheck.split(":")[0]
  // Why it's blocked: "link" or "git" (in the repository `managedBlockedRepo`)
  readonly property string managedBlockedBy: managedCheck === "blocked" ? _managedCheck.split(":")[1] ?? "" : ""
  readonly property string managedBlockedRepo: managedBlockedBy === "git" ? _managedCheck.split(":").slice(2).join(":") : ""
  property string _managedCheck: ""

  // Managed mode: the files in user/ that set monitors themselves. They
  // load after axiom's layer, so their settings win.
  readonly property var monitorConflicts: _monitorConflicts
  property var _monitorConflicts: []

  property bool _checking: false
  property bool _claiming: false
  property bool _finding: false
  // Callers waiting for a check's answer
  property var _checkWaiting: []

  // Runs a takeover verb, calling back with its one-word result ("" when it
  // failed) and the error's message
  function _takeover(verb, callback) {
    BackendManager.call("compositor.takeover", {
      "verb": verb,
      "kind": root.kind,
      "dir": root.configDir,
      "header": root.header,
      "fallback": root.releasedText
    }, (err, result) => callback(err ? "" : result.result, err ? err.message : ""));
  }

  // Looks again what a takeover would do (`managedCheck`), then calls back
  // with it
  function checkManaged(callback) {
    if (callback)
      _checkWaiting.push(callback);
    if (_checking)
      return;
    _checking = true;
    _takeover("check", out => {
      root._checking = false;
      root._managedCheck = out;
      const waiting = root._checkWaiting;
      root._checkWaiting = [];
      waiting.forEach(callback => callback(root.managedCheck));
    });
  }

  // Looks for files in user/ that set monitors (managed mode only)
  function findMonitorConflicts() {
    if (_finding)
      return;
    _finding = true;
    CommandManager.run(["sh", "-c", 'cd "$1" 2>/dev/null && grep -lE -- "$2" $3 2>/dev/null', "sh", root.userDir, root.monitorPattern, root.monitorGlob], (code, out) => {
      root._finding = false;
      root._monitorConflicts = root.mode === "managed" ? out.split("\n").filter(name => name !== "").map(name => root.userDir + "/" + name) : [];
    });
  }

  function clearConflicts() {
    _monitorConflicts = [];
  }

  // Makes the config axiom's: "ours" (already), "adopted:<name>" (the old
  // one moved to user/<name>, its lines starting or loading axiom
  // commented out, a dated backup beside it), "created" (there was none),
  // "replaced" (the example config, only kept as the backup: its binds and
  // monitor rules would fight axiom's) or "blocked" (a symlinked or
  // git-tracked config is never taken over)
  function claim() {
    if (_claiming)
      return;
    _claiming = true;
    _takeover("claim", (out, err) => {
      root._claiming = false;
      if (err !== "")
        console.warn(`[${root.logTag}] Taking over ${root.managedPath}:`, err);
      const words = out.split(":");
      const result = words[0];
      if (result === "blocked") {
        root.blocked();
        return;
      }
      if (result === "adopted")
        console.log(`[${root.logTag}] Took over ${root.managedPath}; your previous one is ${root.userDir}/${words[1]}`);
      else if (result === "replaced")
        console.log(`[${root.logTag}] Replaced ${root.managedPath} (the example config is kept as a dated backup beside it; one axiom gave back isn't kept)`);
      if (["ours", "adopted", "created", "replaced"].includes(result))
        root.claimed(result, result === "adopted" ? words[1] ?? "" : "");
    });
  }

  // Gives the config back on leaving managed: "restored:<from>:<n>" (what
  // the takeover set aside: the adopted user/00-previous*, its lines that
  // start or load axiom enabled again, or the example config's backup; <n>
  // files left in user/ that it doesn't load), "written" (nothing was set
  // aside: releasedText), "notours" (already the user's) or "blocked" (a
  // symlinked or git-tracked one, never written)
  function release() {
    _takeover("release", (out, err) => {
      if (err !== "")
        console.warn(`[${root.logTag}] Giving back ${root.managedPath}:`, err);
      const words = out.split(":");
      const result = words[0];
      if (result === "restored") {
        console.log(`[${root.logTag}] Gave back ${root.managedPath}: it's ${words[1]} again`);
        if (Number(words[2]) > 0)
          console.warn(`[${root.logTag}] ${root.managedPath} is your previous config again, which doesn't load ${root.userFiles} (${words[2]} files): load them from it if you still want them`);
      } else if (result === "written") {
        console.log(`[${root.logTag}] Gave back ${root.managedPath}: it now starts axiom and loads ${root.userFiles}, and is yours to edit`);
      } else if (result === "blocked") {
        console.warn(`[${root.logTag}] ${root.managedPath} is a symlink or in a git repository, so axiom didn't give it back: it's still axiom's managed config`);
      }
      root.released(result);
    });
  }
}
