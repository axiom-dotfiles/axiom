pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

/*
 * Sets the compositor up for axiom (the Compositor section's mode,
 * CompositorConfig.mode), through its backend's config writer
 * (CompositorManager.backend.configWriter, docs/dev/compositor/
 * config-modes.md). One layer (binds, required settings, the window look,
 * input, blur, monitor profiles, strips) reaches the compositor in one of
 * three ways:
 *   detached  evaluated at runtime, again after every config reload, which
 *             drops it
 *   included  written to a module the user's config loads (includeLines)
 *   managed   written as the compositor's config itself, loading the
 *             user's own files after it
 * Whenever the file isn't loaded (included but the lines are missing, or a
 * managed takeover refused), the runtime layer is applied instead, so axiom
 * still works, and `problem` says why.
 * The window look, the input and the blur behind axiom's surfaces are also
 * evaluated after every config reload in each mode, so they win over the
 * user's own config while they're on (_applyLive).
 */
Singleton {
  id: root

  // The running compositor's config writer, or null: only with configModes
  // may anything here touch a compositor's config
  readonly property var writer: CompositorManager.supports.configModes ? CompositorManager.backend.configWriter : null
  readonly property bool live: writer !== null

  readonly property string mode: CompositorConfig.mode
  // Why the chosen mode isn't in effect, or ""
  readonly property string problem: _problem
  property string _problem: ""
  // "runtime" (detached), "loaded" (the file is in effect), "fallback"
  // (it isn't: see `problem`) or "pending" (still checking)
  readonly property string status: mode === "detached" ? "runtime" : _problem !== "" ? "fallback" : _loaded ? "loaded" : "pending"
  property bool _loaded: false
  // Configured keys the runtime layer skipped because the compositor's
  // config already binds them
  readonly property var skippedKeys: writer?.skippedKeys ?? []
  // A problem belongs to the mode it was found in
  onModeChanged: {
    _problem = "";
    _loaded = false;
    writer?.clearConflicts();
  }

  // --- The writer's files and lines (for the settings page, the
  // onboarding and IntegrationHookupManager) ---

  readonly property string configDir: writer?.configDir ?? ""
  readonly property string includePath: writer?.includePath ?? ""
  readonly property string managedPath: writer?.managedPath ?? ""
  readonly property string userDir: writer?.userDir ?? ""
  readonly property string userFiles: writer?.userFiles ?? ""
  readonly property string includeLines: writer?.includeLines ?? ""
  readonly property string autostartLines: writer?.autostartLines ?? ""
  // integration_hookup.py targets, or null
  readonly property var includeTarget: writer?.includeTarget ?? null
  readonly property var autostartTarget: writer?.autostartTarget ?? null

  // Whether a configured bind has everything it needs to be bound
  function isComplete(bind) {
    return root.writer ? root.writer.isComplete(bind) : false;
  }

  // --- What the layer asks for (CompositorLayer) ---

  // Whether axiom's surfaces blur: as saved for a file, and at runtime as
  // now (BlurManager.active, paused over a fullscreen window), evaluated
  // over the file after every reload
  function _surfacesBlur(forFile) {
    return forFile === true ? Appearance.blur : BlurManager.active;
  }

  // The window look and the input that are on, for a file (`forFile`) or
  // for now: { look (CompositorLayer.look), input (CompositorLayer.input),
  // surfacesBlur }
  function spec(forFile) {
    const surfacesBlur = _surfacesBlur(forFile);
    return {
      "look": CompositorLayer.look(WindowLookConfig.look, {
        "activeHex": CompositorLayer.hex(WindowLookConfig.activeBorder),
        "inactiveHex": CompositorLayer.hex(WindowLookConfig.inactiveBorder),
        "borderWidth": WindowLookConfig.borderWidth,
        "radius": WindowLookConfig.radius,
        "surfacesBlur": surfacesBlur
      }),
      "input": CompositorLayer.input(InputConfig.input),
      "surfacesBlur": surfacesBlur
    };
  }

  // --- Files (included, managed) ---

  // Writes `text` to `path` unless it's already there; then reloads the
  // compositor, which doesn't watch files a config loads
  function _writeIfChanged(path, text) {
    if (FileManager.read(path) === text) {
      _checkLoaded();
      return;
    }
    CommandManager.run(["mkdir", "-p", path.replace(/\/[^/]*$/, "")], code => {
      if (code !== 0) {
        console.warn("[CompositorConfigManager] Could not create the folder for", path);
        return;
      }
      root._writeFile(fileWriter, path, text);
    });
  }

  // After a (re)load: is the file in effect? If not, the runtime layer
  // stands in for it
  function _checkLoaded() {
    if (_checking || !root.live)
      return;
    _checking = true;
    root.writer.checkLoaded(loaded => {
      root._checking = false;
      if (root.mode === "detached")
        return;
      if (loaded) {
        root._problem = "";
        root._loaded = true;
        root.writer.runtimeClear();
        return;
      }
      if (root.mode === "included")
        root._warnOnce(root.writer.notIncludedProblem);
      else if (root._problem === "")
        root._warnOnce(root.writer.notManagedProblem);
      root.writer.runtimeApply();
    });
  }

  property bool _checking: false

  function _warnOnce(message) {
    if (_problem === message)
      return;
    _problem = message;
    console.warn("[CompositorConfigManager]", message);
  }

  // Writes `text` to `path` through `view`, reading the file first: a
  // FileView skips setText of the text it last read or wrote, which the
  // file may no longer hold (release replaced it, or the user edited it)
  function _writeFile(view, path, text) {
    view.path = "";
    view.path = path;
    view.setText(text);
  }

  property FileView _fileWriter: FileView {
    id: fileWriter
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onSaved: root._reload()
    onSaveFailed: error => console.warn("[CompositorConfigManager] Could not write", fileWriter.path, error)
  }

  // The included module emptied (_emptyModule), apart from `fileWriter`,
  // which a takeover may be using at the same time
  property FileView _moduleWriter: FileView {
    id: moduleWriter
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onSaved: root._reload()
    onSaveFailed: error => console.warn("[CompositorConfigManager] Could not write", moduleWriter.path, error)
  }

  // Reloads the compositor's config, again once the running reload ends if
  // one is asked for meanwhile (a file written then would otherwise be
  // missed)
  function _reload() {
    if (!root.live)
      return;
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    root.writer.reload(() => {
      root._reloading = false;
      if (root._reloadAgain) {
        root._reloadAgain = false;
        root._reload();
      }
    });
  }

  property bool _reloading: false
  property bool _reloadAgain: false

  // --- The writer's managed takeover and bind merge ---

  property Connections _writerEvents: Connections {
    target: root.writer

    function onClaimed(adopted) {
      root._writeIfChanged(root.managedPath, root.writer.managedText(root.spec(true)));
      // The adopted config's binds would fight axiom's: they move in. Only
      // that file's: the user's other files are left to the Keybinds
      // page's Merge
      if (adopted)
        root.writer.mergeUserBinds(adopted);
    }
    function onBlocked() {
      root._warnOnce(root.writer.blockedProblem);
      root.writer.runtimeApply();
    }
    function onReleased(result) {
      root._releasing = false;
      // A reload brings the given-back config in, and with it the runtime
      // layer (configReloaded); without one, the runtime layer goes on now
      if (result === "restored" || result === "written")
        root._reload();
      else if (root.mode === "detached")
        root.writer.runtimeApply();
    }
    function onBindsMerged(binds) {
      root.bindsMerged(binds);
    }
  }

  // What switching to managed would do: "ours" | "adopt" | "stock" |
  // "released" | "new" | "blocked" (by managedBlockedBy "link" or "git")
  readonly property string managedCheck: writer?.managedCheck ?? ""
  readonly property string managedBlockedBy: writer?.managedBlockedBy ?? ""
  readonly property string managedBlockedRepo: writer?.managedBlockedRepo ?? ""
  // Managed mode: the user's files that set monitors themselves
  readonly property var monitorConflicts: writer?.monitorConflicts ?? []

  function checkManaged() {
    root.writer?.checkManaged();
  }

  readonly property bool merging: writer?.merging ?? false
  // The last merge, or null
  readonly property var lastMerge: writer?.lastMerge ?? null
  // How many binds a Merge of all the user's files would move; -1 until
  // looked
  readonly property int mergeable: writer?.mergeable ?? -1
  // The binds a merge moved in for good (KeybindManager adds them to a
  // draft with unsaved edits)
  signal bindsMerged(var binds)

  // `only`: one of the user's files (the adopted one), else all of them
  function mergeUserBinds(only) {
    root.writer?.mergeUserBinds(only);
  }

  // Counts what a Merge would move, changing nothing (`mergeable`)
  function previewMerge() {
    root.writer?.previewMerge();
  }

  // --- For the settings page ---

  function copyIncludeLines() {
    ClipboardManager.copyText(includeLines);
  }

  function openConfigDir() {
    if (root.configDir !== "")
      Quickshell.execDetached(["xdg-open", root.configDir]);
  }

  // --- Driving it ---

  function apply() {
    // Only with a writer: elsewhere nothing here may touch a config
    if (!root.live)
      return;
    // Detached, the reload's configReloaded applies the layer again. The
    // file modes go on: their configReloaded doesn't call apply(), so
    // returning would drop a mode switch or a rewrite made with it.
    if (_undoLive() && mode === "detached")
      return;
    if (_appliedMode !== "" && _appliedMode !== mode)
      _leave(_appliedMode);
    _appliedMode = mode;
    if (mode === "included") {
      _writeIfChanged(includePath, root.writer.moduleText(root.spec(true)));
    } else if (mode === "managed") {
      root.writer.claim();
    } else {
      _problem = "";
      // Not over the managed layer a release is about to take out: its
      // binds would read as the user's
      if (!_releasing)
        root.writer.runtimeApply();
    }
  }

  // --- The window look and the input, over the user's config in every mode ---

  // The parts last evaluated at runtime ("borders,gaps,input:keyboard"),
  // until a config reload drops them, and the cursor last set. Kept across
  // QML reloads, as the compositor keeps them.
  PersistentProperties {
    id: _liveState
    reloadableId: "axiomCompositorLive"
    property string applied: ""
    // The cursor theme and size last set ("theme|size"), or ""
    property string cursor: ""
  }

  // After a config reload in the file modes: the module set the look before
  // the user's own lines, so it's evaluated again to win over them. And in
  // every mode as the look, the input or the blur changes (_liveDebounce).
  function _applyLive() {
    if (!root.live)
      return;
    root.writer.runLive(_liveLines());
  }

  // The look, the input and the blur as evaluated at runtime now, noting
  // which parts that applies (the runtime layer evaluates them too, through
  // the writer's liveLinesHook). The cursor theme is set as it changes (a
  // reload keeps it).
  function _liveLines() {
    const now = root.spec(false);
    _liveState.applied = _appliedParts(now).join(",");
    const cursor = now.input.cursor ? `${now.input.cursor.theme}|${now.input.cursor.size}` : "";
    if (cursor !== "" && cursor !== _liveState.cursor)
      root.writer.setCursor(now.input.cursor.theme, now.input.cursor.size);
    _liveState.cursor = cursor;
    return root.writer.liveLines(now);
  }

  // The writer's runtime layer evaluates the live lines through this
  function _hookWriter() {
    if (root.writer)
      root.writer.liveLinesHook = () => root._liveLines();
  }
  onWriterChanged: _hookWriter()

  // The look's parts and the input's (as "input:<part>"; not the cursor,
  // which a reload doesn't take back) that are on in `spec`
  function _appliedParts(spec) {
    return spec.look.parts.concat(spec.input.parts.filter(part => part !== "cursor").map(part => "input:" + part));
  }

  // The parts evaluated since the last reload that are off now
  function _droppedParts() {
    const now = _appliedParts(root.spec(false));
    return _liveState.applied.split(",").filter(part => part !== "" && !now.includes(part));
  }

  // A runtime eval can't take a setting back: a part turned off since it
  // was evaluated reloads the compositor's config, whose configReloaded
  // applies the rest again. True when it reloaded.
  function _undoLive() {
    const dropped = _droppedParts();
    if (dropped.length === 0)
      return false;
    _liveState.applied = "";
    // The file modes rewrite their file, which reloads anyway, unless it
    // never held the part (only evaluated at runtime since its last write)
    if (mode !== "detached" && _appliedMode === mode && status === "loaded" && FileManager.read(mode === "managed" ? managedPath : includePath) !== (mode === "managed" ? root.writer.managedText(root.spec(true)) : root.writer.moduleText(root.spec(true))))
      return false;
    console.log(`[CompositorConfigManager] Window look or input turned off (${dropped.join(", ")}); reloading the compositor's config to take it back`);
    _reload();
    return true;
  }

  // The mode apply() last set up, "" before the first: only a switch made
  // while axiom runs gives anything back, never a load
  property string _appliedMode: ""
  // While a managed takeover is given back (detached waits for it)
  property bool _releasing: false

  // Gives back what `previous` took (as the takeover settings do, its own
  // card switching it): leaving managed, the config it claimed (the
  // writer's release); leaving included (or managed, whose restored config
  // may load it), the module, which then does nothing. Otherwise the old
  // layer stays in the compositor's config, and the runtime layer, which
  // only adds, can't undo it (a strip it set stays a strip).
  function _leave(previous) {
    if (mode !== "included")
      _emptyModule();
    if (previous === "managed") {
      _releasing = true;
      root.writer.release();
    }
  }

  function _emptyModule() {
    const empty = root.writer.emptyModuleText;
    const current = FileManager.read(includePath);
    if (!current || current === empty)
      return;
    _writeFile(moduleWriter, includePath, empty);
  }

  // Everything the layer is made of but the look, the input and the blur;
  // a change re-applies it (in the file modes, rewriting the file, which
  // reloads the compositor)
  readonly property string _inputs: [mode, KeybindsConfig._bindsJson, MonitorsConfig._profilesJson, SessionConfig._sessionJson, WorkspacesConfig._stripsJson, CompositorConfig.requiredSettings, writer?.inputsKey ?? ""].join("|")
  on_InputsChanged: _debounce.restart()

  // The window look, the input and the blur behind axiom (paused over a
  // fullscreen window too). A change is only evaluated at runtime, in every
  // mode: a reload on every step of a setting stalls the desktop, and
  // detached, re-applying the whole layer redoes every bind. The file holds
  // them as of its last write, and _applyLive evaluates the current ones
  // over it after every reload. Turning a part off goes through apply(),
  // since an eval can't take a setting back.
  readonly property string _liveInputs: [WindowLookConfig._lookJson, InputConfig._inputJson, Appearance.blur, BlurManager.active, Appearance.blurBackdrops, Appearance.blurThroughWindows, WindowLookConfig.activeBorder, WindowLookConfig.inactiveBorder, WindowLookConfig.radius, WindowLookConfig.borderWidth].join("|")
  on_LiveInputsChanged: _liveDebounce.restart()

  property Timer _liveDebounce: Timer {
    interval: 300
    onTriggered: {
      if (!root.live)
        return;
      if (root._appliedMode !== root.mode || root._droppedParts().length > 0)
        root.apply();
      else
        root._applyLive();
    }
  }

  property Timer _debounce: Timer {
    interval: 300
    onTriggered: root.apply()
  }

  Component.onCompleted: {
    _hookWriter();
    _debounce.restart();
  }

  property Connections _compositorEvents: Connections {
    target: root.live ? CompositorManager : null

    function onConfigReloaded() {
      // A reload drops runtime binds, rules, the look and the input
      root.writer.noteReload();
      _liveState.applied = "";
      if (root.mode === "detached") {
        root._debounce.restart();
      } else {
        root._checkLoaded();
        root._applyLive();
      }
      // The compositor reloads when one of the user's files changes
      if (root.mode === "managed")
        root.writer.findMonitorConflicts();
    }
  }
}
