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
 * user's own config while they're on (_applyLive). A compositor taking
 * nothing at runtime (niri: the writer's `liveByFile`) gets them in its
 * files instead, rewritten as they change, which it reloads by itself.
 */
Singleton {
  id: root

  // The running compositor's config writer, or null: only with configModes
  // may anything here touch a compositor's config
  readonly property var writer: CompositorManager.supports.configModes ? CompositorManager.backend.configWriter : null
  // Only once the compositor's capabilities are final: the parts applied
  // depend on them (_appliedParts), and one seen missing for a moment would
  // count as turned off and reload the compositor. And once the cursor
  // theme's XCursor name is known, so a start writes it once.
  readonly property bool live: writer !== null && CompositorManager.ready && CursorThemeManager.ready
  onLiveChanged: {
    if (live)
      _debounce.restart();
  }

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
    _takeoverPending = false;
    writer?.clearConflicts();
    // Managed picked while axiom runs (its card's Save) is the approval to
    // take this compositor's config over; a mode loaded with a config isn't
    if (mode === "managed" && _appliedMode !== "")
      _approveTakeover();
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
  // for now: { look (CompositorLayer.look), surfaces ({ blur,
  // throughWindows, backdrops }), input (CompositorLayer.input),
  // surfacesBlur }
  function spec(forFile) {
    const surfacesBlur = _surfacesBlur(forFile);
    return {
      "look": CompositorLayer.look(WindowLookConfig.look, {
        "activeHex": CompositorLayer.hex(WindowLookConfig.activeBorder),
        "inactiveHex": CompositorLayer.hex(WindowLookConfig.inactiveBorder),
        "borderWidth": WindowLookConfig.borderWidth,
        "radius": WindowLookConfig.radius,
        "surfacesBlur": surfacesBlur,
        "shadow": WindowLookConfig.shadowOn ? {
          "size": WindowLookConfig.shadowSize,
          "color": WindowLookConfig.shadowThemed ? CompositorLayer.hex(WindowLookConfig.shadowColor) : "",
          "alpha": WindowLookConfig.shadowAlpha,
          // Spread evenly, as axiom's own
          "offset": 0,
          "soft": WindowLookConfig.shadowSoft,
          "strength": WindowLookConfig.shadowStrength
        } : null
      }),
      // How axiom's surfaces blur (a backend blurring layers by name)
      "surfaces": {
        "blur": surfacesBlur,
        "throughWindows": Appearance.blurThroughWindows,
        "backdrops": Appearance.blurBackdrops
      },
      "input": CompositorLayer.input(InputConfig.input, CursorThemeManager.xcursorTheme),
      "surfacesBlur": surfacesBlur
    };
  }

  // --- Files (included, managed) ---

  // Writes `text` to `path` unless it's already there; then reloads the
  // compositor, which doesn't watch files a config loads. A writer that
  // can check its text first (`validate`) leaves the file as it was when
  // the compositor would refuse it, and says why (`problem`).
  function _writeIfChanged(path, text) {
    if (FileManager.read(path) === text) {
      _checkLoaded();
      // No reload to evaluate the live parts after (the shell started
      // over a file already as wanted): what's only set at runtime
      // (SwayFX's look, sway's window opacity) is sent now
      _applyLive();
      return;
    }
    if (!root.writer.validate) {
      _write(path, text);
      return;
    }
    // Checks finish in any order: only the last asked for is written
    const asked = ++_writes;
    root.writer.validate(text, error => {
      if (asked !== root._writes)
        return;
      if (error)
        root._warnOnce(root.writer.invalidProblem(error));
      else
        root._write(path, text);
    });
  }

  property int _writes: 0

  function _write(path, text) {
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
      // The compositor couldn't load its config at all: the runtime layer
      // wouldn't load either
      if (loaded === "failed") {
        root._warnOnce(root.writer.failedProblem);
        return;
      }
      if (loaded) {
        root._problem = "";
        root._loaded = true;
        root.writer.runtimeClear();
        return;
      }
      if (root.mode === "included") {
        root._warnOnce(root.writer.notIncludedProblem);
        root._notifyNotIncluded();
      } else if (root._problem === "") {
        root._warnOnce(root.writer.notManagedProblem);
      }
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

  function copyAutostartLines() {
    ClipboardManager.copyText(autostartLines);
  }

  // Adds the autostart line to the user's config (the autostart hookup,
  // with a backup); it takes effect with the next session, so no reload
  function addAutostartLines() {
    IntegrationHookupManager.apply("compositorAutostart");
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
      _claimIfApproved();
    } else {
      _problem = "";
      // Not over the managed layer a release is about to take out: its
      // binds would read as the user's
      if (!_releasing)
        root.writer.runtimeApply();
    }
  }

  // --- Approving a takeover ---

  // Managed mode waits for the user before taking over a config of theirs
  // on this compositor: one that came with the mode from elsewhere (another
  // compositor's, an import) never took it over here. Allowed once (the
  // Compositor card's Allow, or picking managed there), it's remembered
  // for this compositor. A config that holds nothing of the user's (none
  // yet, the example, axiom's own, the one leaving managed wrote) is taken
  // over without asking.
  readonly property bool takeoverPending: _takeoverPending
  property bool _takeoverPending: false
  // Why it waits (`problem` meanwhile)
  readonly property string approvalProblem: `Compositor mode is "managed", but taking over ${managedPath} needs your approval (Settings › Compositor). Applying axiom's layer at runtime meanwhile.`

  // The compositors whose config the user let axiom take over
  // ($XDG_STATE_HOME/axiom/ui/takeover.json: { approved: [kind] })
  readonly property var _approvalState: StateManager.createStateHandler("takeover")
  property var _approved: []
  property bool _approvalsRead: false

  function _isApproved() {
    if (!_approvalsRead) {
      _approved = _approvalState.load({
        "approved": []
      }).approved ?? [];
      _approvalsRead = true;
    }
    return _approved.includes(CompositorManager.kind);
  }

  function _approveTakeover() {
    if (_isApproved())
      return;
    _approved = _approved.concat([CompositorManager.kind]);
    _approvalState.save({
      "approved": _approved
    });
  }

  // The status card's (and the notification's) Allow
  function allowTakeover() {
    _approveTakeover();
    _takeoverPending = false;
    _problem = "";
    if (mode === "managed")
      apply();
  }

  function _claimIfApproved() {
    if (_isApproved()) {
      _takeoverPending = false;
      root.writer.claim();
      return;
    }
    root.writer.checkManaged(check => {
      if (root.mode !== "managed")
        return;
      // Nothing of the user's to take over, or blocked anyway (claim says)
      if (["ours", "new", "stock", "released", "blocked"].includes(check)) {
        if (check !== "blocked")
          root._approveTakeover();
        root._takeoverPending = false;
        root.writer.claim();
        return;
      }
      root._takeoverPending = true;
      root._warnOnce(root.approvalProblem);
      root._notifyApproval();
      root.writer.runtimeApply();
    });
  }

  // Once per session (it outlives a reload of the shell), with Allow on it
  function _notifyApproval() {
    _notifyOnce("approvalAsked", I18n.tr("{0} config needs your approval", CompositorManager.displayName), I18n.tr("axiom's Managed mode would take over {0}, moving your config to {1}. Until you allow it, axiom applies its settings at runtime.", Paths.shortenHome(root.managedPath), Paths.shortenHome(root.userDir)), [["allow", I18n.tr("Allow takeover"), () => root.allowTakeover()]]);
  }

  // Included mode with the module not loaded: once per session, offering
  // to add the line (as the onboarding's Apply does, with a backup), not
  // while the onboarding is open, which offers it itself
  function _notifyNotIncluded() {
    if (OnboardingManager.shown)
      return;
    const add = root.includeTarget ? [["add", I18n.tr("Add it for me"), () => root.addIncludeLines()]] : [];
    _notifyOnce("includeAsked", I18n.tr("{0} doesn't load axiom's module", CompositorManager.displayName), I18n.tr("axiom's Included mode needs this in your config:\n{0}\nUntil it's there, axiom applies its settings at runtime.", root.includeLines), add);
  }

  // Adds the include lines to the user's config (the include hookup, with a
  // backup), then reloads it so they take effect
  function addIncludeLines() {
    _includeAdded = true;
    IntegrationHookupManager.apply("compositorModule");
  }

  property bool _includeAdded: false

  property Connections _hookups: Connections {
    target: root._includeAdded ? IntegrationHookupManager : null

    function onResultsChanged() {
      const results = IntegrationHookupManager.results.compositorModule;
      if (!results)
        return;
      root._includeAdded = false;
      if (results.some(result => result.changed))
        root._reload();
    }
  }

  // A notification sent once per session (`flag`, a property of the
  // session's, outliving a reload of the shell), with `actions` ([[id,
  // label, run]]) and Open settings
  function _notifyOnce(flag, title, body, actions) {
    if (_session[flag])
      return;
    _session[flag] = true;
    const all = actions.concat([["settings", I18n.tr("Open settings"), () => SettingsManager.openSection("Compositor")]]);
    const command = ["notify-send", "-a", "axiom", "-u", "critical"].concat(...all.map(action => ["-A", `${action[0]}=${action[1]}`]), ["--", title, body]);
    CommandManager.run(command, (code, out) => {
      // (not `picked?.[2]()`: Qt 6.12's compiler crashes on it)
      const picked = all.find(action => action[0] === out.trim());
      if (picked)
        picked[2]();
    });
  }

  PersistentProperties {
    id: _session
    reloadableId: "axiomCompositorSession"
    property bool approvalAsked: false
    property bool includeAsked: false
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
    if (!root.live || root.writer.liveByFile)
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
    const cursor = now.input.cursor ? `${now.input.cursor.theme}|${now.input.cursor.xcursor}|${now.input.cursor.size}` : "";
    if (cursor !== "" && cursor !== _liveState.cursor)
      root.writer.setCursor(now.input.cursor);
    _liveState.cursor = cursor;
    return root.writer.liveLines(now);
  }

  // The writer's runtime layer evaluates the live lines through this
  function _hookWriter() {
    if (!root.writer)
      return;
    root.writer.liveLinesHook = () => root._liveLines();
    // A writer applying its runtime layer as a file (niri's) asks for the spec
    if ("specHook" in root.writer)
      root.writer.specHook = forFile => root.spec(forFile);
  }
  onWriterChanged: _hookWriter()

  // The look's parts and the input's (as "input:<part>"; not the cursor,
  // which a reload doesn't take back) that are on in `spec`, of those the
  // compositor applies (supports.window<Part>, inputConfig): one it can't
  // (blur on sway) was never evaluated, so turning it off reloads nothing
  function _appliedParts(spec) {
    const supports = CompositorManager.supports;
    const look = spec.look.parts.filter(part => supports["window" + part.charAt(0).toUpperCase() + part.slice(1)] === true);
    const input = supports.inputConfig === true ? spec.input.parts.filter(part => part !== "cursor").map(part => "input:" + part) : [];
    return look.concat(input);
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
  readonly property string _inputs: [mode, KeybindsConfig._bindsJson, MonitorsConfig._profilesJson, SessionConfig._sessionJson, ThemeIntegrations.qt, WorkspacesConfig._stripsJson, CompositorConfig.requiredSettings, writer?.inputsKey ?? ""].join("|")
  on_InputsChanged: _debounce.restart()

  // The window look, the input and the blur behind axiom (paused over a
  // fullscreen window too). A change is only evaluated at runtime, in every
  // mode: a reload on every step of a setting stalls the desktop, and
  // detached, re-applying the whole layer redoes every bind. The file holds
  // them as of its last write, and _applyLive evaluates the current ones
  // over it after every reload. Turning a part off goes through apply(),
  // since an eval can't take a setting back.
  readonly property string _liveInputs: [WindowLookConfig._lookJson, InputConfig._inputJson, CursorThemeManager.xcursorTheme, Appearance.blur, BlurManager.active, Appearance.blurBackdrops, Appearance.blurThroughWindows, WindowLookConfig.activeBorder, WindowLookConfig.inactiveBorder, WindowLookConfig.radius, WindowLookConfig.borderWidth, WindowLookConfig.shadowOn, WindowLookConfig.shadowSize, WindowLookConfig.shadowColor, WindowLookConfig.shadowAlpha, WindowLookConfig.shadowStrength].join("|")
  on_LiveInputsChanged: _liveDebounce.restart()

  property Timer _liveDebounce: Timer {
    interval: 300
    onTriggered: {
      if (!root.live)
        return;
      // A compositor taking them from its files only: rewritten (apply)
      if (root.writer.liveByFile || root._appliedMode !== root.mode || root._droppedParts().length > 0) {
        root.apply();
      } else {
        root._applyLive();
        root._fileSync.restart();
      }
    }
  }

  // The file modes' file follows the live parts too, once they've settled,
  // written without a reload (the runtime eval has applied them): else it
  // keeps what they were at its last write, and the next session starts
  // from that (a cursor theme, and the XCURSOR_THEME apps get). Hyprland
  // reloads a hyprland.lua that changed by itself; that's once, after the
  // settings settle.
  property Timer _fileSync: Timer {
    interval: 2000
    onTriggered: root._syncFile()
  }

  function _syncFile() {
    // A change to the rest waiting to apply writes the file itself, and
    // reloads: written first, it would find the file as it wants it and
    // reload nothing (a new bind unloaded)
    if (!root.live || root.writer.liveByFile || root._appliedMode !== root.mode || root.status !== "loaded" || root._debounce.running)
      return;
    if (root._reloading) {
      root._fileSync.restart();
      return;
    }
    const path = root.mode === "managed" ? root.managedPath : root.mode === "included" ? root.includePath : "";
    if (path === "")
      return;
    const text = root.mode === "managed" ? root.writer.managedText(root.spec(true)) : root.writer.moduleText(root.spec(true));
    if (FileManager.read(path) !== text)
      root._writeFile(syncWriter, path, text);
  }

  property FileView _syncWriter: FileView {
    id: syncWriter
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onSaveFailed: error => console.warn("[CompositorConfigManager] Could not write", syncWriter.path, error)
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
