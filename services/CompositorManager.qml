pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

/* The running compositor, for the rest of axiom: its windows, outputs and
 * workspaces in shapes that don't depend on it, what it supports, and every
 * workspace switch and window focus (docs/dev/compositor/README.md). The
 * compositor's own work is its backend's (HyprlandManager); with none
 * (an unknown compositor) everything here is empty and does nothing. */
Singleton {
  id: root

  // Which compositor axiom runs under: "hyprland", "sway", "niri" or ""
  // (unknown, or none). AXIOM_COMPOSITOR overrides it, for testing
  // ("none" for no backend at all).
  readonly property string kind: {
    const forced = Quickshell.env("AXIOM_COMPOSITOR") ?? "";
    if (forced !== "")
      return forced === "none" ? "" : forced;
    if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
      return "hyprland";
    if (Quickshell.env("SWAYSOCK"))
      return "sway";
    if (Quickshell.env("NIRI_SOCKET"))
      return "niri";
    return "";
  }

  // The backend for `kind`, or null (docs/dev/compositor/contract.md). Only
  // the one picked is ever created.
  readonly property var backend: kind === "hyprland" ? HyprlandManager : null

  // What the compositor can do, by capability (contract.md › Capabilities):
  // false for anything the backend doesn't say, and for what
  // AXIOM_COMPOSITOR_OFF ("focusGrab,blur") turns off, so the
  // fallbacks can be tried on a compositor that has them
  readonly property var supports: {
    const own = root.backend?.supports ?? {};
    const off = String(Quickshell.env("AXIOM_COMPOSITOR_OFF") ?? "").split(",").map(name => name.trim());
    return Object.keys(own).reduce((result, name) => {
      result[name] = own[name] === true && !off.includes(name);
      return result;
    }, {});
  }

  // --- State (contract.md › Shapes) ---

  // Every mapped window: [{ id, appId, initialAppId, title, workspaceId,
  // workspaceName, output, floating, fullscreen, maximized, hidden,
  // focusRank, x, y, w, h }]
  readonly property var windows: root.backend?.windows ?? []
  // Every monitor: [{ name, description, x, y, width, height, scale,
  // focused, activeWorkspaceId, specialWorkspaceId, reserved }]
  readonly property var outputs: root.backend?.outputs ?? []
  // Every workspace: [{ id, name, output, windowCount, active, focused }]
  readonly property var workspaces: root.backend?.workspaces ?? []
  // The focused monitor's name, or "" with none
  readonly property string focusedOutput: root.backend?.focusedOutput ?? ""
  // The focused window's id, or ""
  readonly property string activeWindowId: root.backend?.activeWindowId ?? ""
  // The gaps the compositor leaves at the screen edges, after reserved
  // zones ({ top, right, bottom, left })
  readonly property var gapsOut: root.backend?.gapsOut ?? ({
      "top": 0,
      "right": 0,
      "bottom": 0,
      "left": 0
    })
  // The compositor's blur as in effect ({ enabled, size, passes }). With
  // none, the strength is Hyprland's default, which the lock screen's and
  // the desktop's own frosting imitate (ScreenLayoutView.hyprBlur)
  readonly property var blur: root.backend?.blur ?? ({
      "enabled": false,
      "size": 8,
      "passes": 1
    })
  // A tiled box wider than tall times this splits side by side
  readonly property real splitWidthMultiplier: root.backend?.splitWidthMultiplier ?? 1
  // Whether surfaces with a fixed stacking order (bars, border, docks,
  // edge menus, the desktop) may map yet: the backend's stacking is in
  readonly property bool surfacesReady: root.backend?.surfacesReady ?? true

  // The output showing a screen, or null
  function outputFor(screen) {
    return screen ? root.output(screen.name) : null;
  }

  // The output named `name`, or null
  function output(name) {
    return root.outputs.find(o => o.name === name) ?? null;
  }

  // The focused output, or null
  readonly property var focused: root.output(root.focusedOutput)

  // The focused output's active workspace id (1 while unknown)
  function activeWorkspaceId() {
    const id = root.focused?.activeWorkspaceId ?? -1;
    return id > 0 ? id : 1;
  }

  // Re-reads the outputs and windows soon
  function refresh() {
    root.backend?.refresh();
  }

  // --- Events ---

  // A layer surface opened or closed
  signal layersChanged
  // A monitor was added or removed
  signal outputsHotplugged
  // The compositor reloaded its config
  signal configReloaded
  // The keyboard layout switched
  signal keyboardLayoutChanged
  // A window was focused; appId is its app id (class)
  signal windowFocused(string appId)

  Connections {
    target: root.backend
    ignoreUnknownSignals: true

    function onLayersChanged() {
      root.layersChanged();
    }
    function onOutputsHotplugged() {
      root.outputsHotplugged();
    }
    function onConfigReloaded() {
      root.configReloaded();
    }
    function onKeyboardLayoutChanged() {
      root.keyboardLayoutChanged();
    }
    function onWindowFocused(appId) {
      root.windowFocused(appId);
    }
  }

  // --- Windows ---

  // Focuses a window. One on another workspace goes through goToWorkspace,
  // to slide like any other switch.
  function focusWindow(id) {
    const win = root.windows.find(w => w.id === id);
    const out = root.output(win?.output ?? "");
    const workspaceId = win?.workspaceId ?? -1;
    if (!out || workspaceId <= 0 || workspaceId === out.activeWorkspaceId)
      root.backend?.activateWindow(id);
    else
      root.goToWorkspace(workspaceId, "go", out.name, id);
  }

  function closeWindow(id) {
    root.backend?.closeWindow(id);
  }

  // The overview's drag and drop (HyprlandManager.placeWindow)
  function placeWindow(id, workspaceId, targetId, side, restore, reinsert, floatAt) {
    root.backend?.placeWindow(id, workspaceId, targetId, side, restore, reinsert, floatAt);
  }

  // The overview's resize (HyprlandManager.resizeWindow)
  function resizeWindow(id, dw, dh, dx, dy) {
    root.backend?.resizeWindow(id, dw, dh, dx, dy);
  }

  // The live Wayland toplevel of a window (for previews), or null
  function toplevelFor(id) {
    return root.backend?.toplevelFor(id) ?? null;
  }

  // Whether the named output's active workspace, or the special workspace
  // open on it, shows a fullscreen window (maximized ones don't count:
  // they leave reserved space alone)
  function hasFullscreen(name) {
    const out = root.output(name);
    const ids = [out?.activeWorkspaceId ?? -1, out?.specialWorkspaceId ?? 0].filter(id => id !== -1 && id !== 0);
    return ids.length > 0 && root.windows.some(w => ids.includes(w.workspaceId) && w.fullscreen);
  }

  // The largest window on a workspace (its icon stands for the workspace),
  // or null
  function biggestWindowForWorkspace(workspaceId) {
    const area = w => (w?.w ?? 0) * (w?.h ?? 0);
    return root.windows.filter(w => w.workspaceId === workspaceId).reduce((biggest, w) => area(w) > area(biggest) ? w : biggest, null);
  }

  // A workspace's windows in strip order (WorkspaceGeometry.stripOrder)
  function stripWindows(workspaceId, vertical) {
    return WorkspaceGeometry.stripOrder(root.windows.filter(w => w.workspaceId === workspaceId && !w.hidden), vertical);
  }

  // Of `windows`, the one focused last (focused now, if any is), or null
  function lastFocused(windows) {
    return windows.reduce((last, w) => last === null || (w.focusRank ?? Infinity) < (last.focusRank ?? Infinity) ? w : last, null);
  }

  // --- The window look ---

  // The window look (WindowLookConfig) for a backend that applies it at
  // runtime: one without config modes (on Hyprland, HyprlandConfigManager
  // puts it in its Lua layer). Applied at startup, whenever it or the theme
  // colors and shape it follows change, and after the compositor reloads
  // its config (which drops it). The backend takes the parts it supports.
  function _applyLook() {
    if (!root.backend?.applyLook || root.supports.configModes)
      return;
    root.backend.applyLook(CompositorLayer.look(WindowLookConfig.look, {
      "activeHex": CompositorLayer.hex(WindowLookConfig.activeBorder),
      "inactiveHex": CompositorLayer.hex(WindowLookConfig.inactiveBorder),
      "borderWidth": WindowLookConfig.borderWidth,
      "radius": WindowLookConfig.radius,
      "surfacesBlur": false
    }));
  }

  readonly property string _lookInputs: [WindowLookConfig._lookJson, WindowLookConfig.activeBorder, WindowLookConfig.inactiveBorder, WindowLookConfig.borderWidth, WindowLookConfig.radius, root.kind].join("|")
  on_LookInputsChanged: _lookDebounce.restart()
  onConfigReloaded: _lookDebounce.restart()

  property Timer _lookDebounce: Timer {
    interval: 300
    onTriggered: root._applyLook()
  }

  // --- Session, input, cursor ---

  // Calls back with the main keyboard's layouts ({ layouts, index,
  // keymap }), or null
  function withKeyboard(callback) {
    if (root.backend)
      root.backend.withKeyboard(callback);
    else
      callback(null);
  }

  // Switches every keyboard to its "next" or "prev" layout, then calls back
  function cycleKeyboardLayout(direction, callback) {
    if (root.backend)
      root.backend.cycleKeyboardLayout(direction, callback);
    else
      callback?.();
  }

  // Calls back with each output's layer surfaces ({ [output]: { w, h,
  // layers: [{ namespace, x, y, w, h }] } }), or null when unknown
  function withLayerRects(callback) {
    if (root.backend)
      root.backend.withLayerRects(callback);
    else
      callback(null);
  }

  // Calls back with the cursor's global position ({ x, y }), or null when
  // the compositor can't say
  function withCursorPos(callback) {
    if (root.supports.cursorPos)
      root.backend.withCursorPos(callback);
    else
      callback(null);
  }

  // Calls back with the name of the screen under the cursor (the focused
  // one if the compositor can't say)
  function withHoveredScreen(callback) {
    root.withCursorPos(pos => callback((pos ? root._screenAt(pos.x, pos.y) : "") || root.focusedOutput || General.primaryMonitor));
  }

  function _screenAt(x, y) {
    for (const screen of General.outputs) {
      if (x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height)
        return screen.name;
    }
    return "";
  }

  // Moves the cursor to (x, y) inside one of axiom's layer surfaces (the
  // one in `namespace` on `output`, `width` × `height`), where the
  // compositor can
  function warpCursorToLayer(namespace, output, width, height, x, y) {
    if (root.supports.cursorWarp)
      root.backend.warpCursorToLayer(namespace, output, width, height, x, y);
  }

  // Ends the session (the power menu's log out)
  function exitSession() {
    root.backend?.exitSession();
  }

  // --- Outputs (the Monitors page) ---

  // Calls back with every output in detail, disabled ones too ({ name,
  // description, width, height, refreshRate, x, y, scale, transform,
  // disabled, mirrorOf, vrr, availableModes, … }, contract.md), or null.
  // Needs monitors
  function withOutputDetails(callback) {
    if (root.supports.monitors)
      root.backend.withOutputDetails(callback);
    else
      callback(null);
  }

  // Sets the outputs as `rules` (MonitorRule) say, now; `details` are the
  // outputs as withOutputDetails gave them. Needs monitors
  function applyOutputs(rules, details) {
    if (root.supports.monitors)
      root.backend.applyOutputs(rules, details);
  }

  // --- Binds (the Keybinds page) ---

  // Calls back with the compositor's binds in effect ({ modmask, key,
  // keycode, description, submap }, BindKeys), or null. Needs bindMerge
  function withBinds(callback) {
    if (root.supports.bindMerge)
      root.backend.withMainBinds(callback);
    else
      callback(null);
  }

  // While on, every key reaches axiom instead of the compositor's binds
  // (the key recorder). Needs keyCapture
  function captureKeys(on) {
    if (root.supports.keyCapture)
      root.backend.captureKeys(on);
  }

  // The shell command turning the screens off or on (the idle daemon's),
  // or "" where axiom doesn't know one
  function dpmsCommand(on) {
    return root.backend?.dpmsCommand(on) ?? "";
  }

  // --- Workspaces (laid out by WorkspacesConfig) ---

  // Goes to workspace `id`. mode: "go" (default), "move" (taking the
  // focused window along) or "moveSilent" (sending it there, staying put).
  // In a grid or perMonitor layout only the output's own workspaces are
  // reachable (`output`, a name, the focused one by default), and it goes
  // by column, then row, sliding along each in turn (WorkspacesConfig.
  // animate). The standard and perMonitor layouts are one row (columns =
  // count), so they only ever slide sideways. Callers on an output's
  // surface pass its name, and it's focused first. `focusId` (focusWindow)
  // arrives by focusing that window instead of the bare workspace.
  function goToWorkspace(id, mode, output, focusId) {
    if (!Number.isInteger(id) || id < 1) {
      console.warn(`[CompositorManager] Not a workspace id: ${id}`);
      return;
    }
    if (!root.backend)
      return;
    mode = mode || "go";
    output = output || root.focusedOutput;
    const base = workspaceBase(output);
    const size = WorkspacesConfig.size;
    if (WorkspacesConfig.perMonitorBlocks && (id < base || id >= base + size)) {
      if (focusId)
        root.backend.activateWindow(focusId);
      else
        console.warn(`[CompositorManager] workspace ${id} is outside ${output || "the focused output"}'s workspaces (${base}-${base + size - 1})`);
      return;
    }
    const focused = output === root.focusedOutput;
    const current = focused ? _currentWorkspaceId() : (root.output(output)?.activeWorkspaceId ?? -1);
    if (id === current) {
      if (focusId)
        root.backend.activateWindow(focusId);
      return;
    }
    if (mode === "moveSilent") {
      root.backend.sendWindowToWorkspace(id);
      return;
    }
    // A new switch replaces the rest of one still sliding, and slides on
    // from wherever that one has got to
    const midway = root.backend.travelingTo ?? -1;
    const at = midway > 0 ? midway : current;
    root._lastGo = {
      "id": id,
      "time": Date.now()
    };
    const cols = WorkspacesConfig.columns;
    const from = at - base;
    const to = id - base;
    const legs = [];
    if (WorkspacesConfig.animate && root.supports.workspaceSlide && from >= 0 && from < size) {
      if (from % cols !== to % cols)
        legs.push({
          "id": base + Math.floor(from / cols) * cols + to % cols,
          "axis": "x"
        });
      if (Math.floor(from / cols) !== Math.floor(to / cols))
        legs.push({
          "id": id,
          "axis": "y"
        });
    }
    if (legs.length === 0)
      legs.push({
        "id": id,
        "axis": ""
      });
    // Without the output focused, a new workspace would open on the
    // focused one
    root.backend.travel(focused || !output ? "" : output, legs, mode, focusId ?? "");
  }

  // A step about to wrap round the grid's ends on `output` (its name):
  // along a row (`alongRow`, the standard layout's only kind) or a column,
  // `forward` past the last. The bar switchers' active box leaves one end
  // and comes in at the other instead of sliding back across.
  signal workspaceWrapped(string output, bool alongRow, bool forward)

  // One step left/right/up/down from the current workspace: within the
  // output's grid, or through 1..count in the standard layout (where up is
  // previous and down next). Stops at the edges unless WorkspacesConfig.wrap.
  function stepWorkspace(direction, mode) {
    const base = workspaceBase(root.focusedOutput);
    const size = WorkspacesConfig.size;
    const index = _currentWorkspaceId() - base;
    if (index < 0 || index >= size) {
      goToWorkspace(base, mode);
      return;
    }
    const cols = WorkspacesConfig.grid ? WorkspacesConfig.columns : size;
    const rows = WorkspacesConfig.grid ? WorkspacesConfig.rows : 1;
    if (!WorkspacesConfig.grid && (direction === "up" || direction === "down"))
      direction = direction === "up" ? "left" : "right";
    let col = index % cols + (direction === "left" ? -1 : direction === "right" ? 1 : 0);
    let row = Math.floor(index / cols) + (direction === "up" ? -1 : direction === "down" ? 1 : 0);
    if (col < 0 || col >= cols || row < 0 || row >= rows) {
      if (!WorkspacesConfig.wrap)
        return;
      root.workspaceWrapped(root.focusedOutput, col < 0 || col >= cols, direction === "right" || direction === "down");
      col = (col + cols) % cols;
      row = (row + rows) % rows;
    }
    goToWorkspace(base + row * cols + col, mode);
  }

  // The n-th workspace (1-based) of the current row in a grid or perMonitor
  // layout, or workspace n in the standard layout (number keybinds)
  function nthWorkspace(n, mode) {
    if (!WorkspacesConfig.perMonitorBlocks) {
      goToWorkspace(n, mode);
      return;
    }
    const cols = WorkspacesConfig.columns;
    if (n < 1 || n > cols)
      return;
    const base = workspaceBase(root.focusedOutput);
    const index = Math.min(Math.max(_currentWorkspaceId() - base, 0), WorkspacesConfig.size - 1);
    goToWorkspace(base + Math.floor(index / cols) * cols + n - 1, mode);
  }

  // "horizontal" | "vertical" on a strip monitor (its name), else "",
  // always "" where the compositor has no strips (a config from Hyprland
  // may still list them)
  function stripDirection(screenName) {
    return root.supports.strips ? WorkspacesConfig.stripDirection(screenName) : "";
  }

  // Scrolls the strip of an output's active workspace a column on (1) or
  // back (-1). Layout messages act on the focused workspace, so only on the
  // focused output, and only with windows to scroll.
  function stepStrip(direction, output) {
    if (!root.supports.strips || !output || output !== root.focusedOutput)
      return;
    const active = root.output(output)?.activeWorkspaceId ?? -1;
    if (root.windows.some(w => w.workspaceId === active))
      root.backend.scrollStrip(direction);
  }

  // The last workspace gone to, for a moment: key presses can come faster
  // than the compositor reports the switch
  property var _lastGo: ({
      "id": -1,
      "time": 0
    })

  function _currentWorkspaceId() {
    if ((root.backend?.travelingTo ?? -1) > 0 || Date.now() - root._lastGo.time < 300)
      return root._lastGo.id;
    return activeWorkspaceId();
  }

  // First workspace id an output (its name) shows: 1 in the standard
  // layout, else its block's (grid/perMonitor, one block per output in a
  // stable order — the primary first, then the rest by a description-based
  // identity that survives a port change — not the compositor's discovery
  // order, which can reshuffle on a hotplug/reconnect/restart)
  function workspaceBase(output) {
    if (!WorkspacesConfig.perMonitorBlocks)
      return WorkspacesConfig.baseFor(0);
    const index = _orderedOutputs().findIndex(o => o.name === output);
    return WorkspacesConfig.baseFor(index >= 0 ? index : 0);
  }

  // The workspace ids an output (its name) shows, in order
  function workspaceIds(output) {
    const base = workspaceBase(output);
    const ids = [];
    for (let i = 0; i < WorkspacesConfig.size; i++)
      ids.push(base + i);
    return ids;
  }

  // The outputs in block order (WorkspaceGeometry.orderMonitors)
  function _orderedOutputs() {
    const outputs = root.outputs;
    const plain = outputs.map(o => ({
          "name": o.name,
          "key": MonitorLayout.outputId(o, outputs),
          "x": o.x,
          "y": o.y,
          "active": o.activeWorkspaceId,
          "focused": o.focused
        }));
    return WorkspaceGeometry.orderMonitors(plain, General.primaryMonitor);
  }

  // --- Layout changes ---

  // The layout the workspaces were last laid out for ({ blocks, size })
  property var _appliedLayout: null

  function _currentLayout() {
    return {
      "blocks": WorkspacesConfig.perMonitorBlocks,
      "size": WorkspacesConfig.size
    };
  }

  // A layout or count change saved together is one remap
  property Timer _remapTimer: Timer {
    interval: 200
    onTriggered: {
      const layout = root._currentLayout();
      if (root._appliedLayout)
        root._remapWorkspaces(root._appliedLayout, layout);
      root._appliedLayout = layout;
    }
  }

  property Connections _layoutWatch: Connections {
    target: WorkspacesConfig

    function onPerMonitorBlocksChanged() {
      root._remapTimer.restart();
    }

    function onSizeChanged() {
      root._remapTimer.restart();
    }
  }

  // Moves every window from its workspace under the `from` layout to the
  // matching one in its output's ids under `to` (WorkspaceGeometry.
  // remapWorkspaces), and switches each output to the workspace matching
  // the one it showed (the backend's applyRemap)
  function _remapWorkspaces(from, to) {
    if (!root.backend)
      return;
    const windows = root.windows.map(w => ({
          "id": w.id,
          "workspace": w.workspaceId,
          "output": w.output
        }));
    const outputs = _orderedOutputs();
    const plan = WorkspaceGeometry.remapWorkspaces(outputs, windows, from, to);
    if (!plan.changed)
      return;
    const focused = plan.focus[plan.focus.length - 1];
    root._lastGo = {
      "id": focused?.id ?? -1,
      "time": Date.now()
    };
    console.log(`[CompositorManager] remapping workspaces: ${plan.moves.length} windows, outputs to ${plan.focus.map(f => f.monitor + ":" + f.id).join(", ")}`);
    root.backend.applyRemap(plan, outputs.map(o => o.name));
  }

  Component.onCompleted: _appliedLayout = _currentLayout()

  // `qs -c axiom ipc call workspaces …`, for workspace keybinds. mode:
  // "go", "move" (take the focused window along) or "moveSilent"
  property IpcHandler _ipc: IpcHandler {
    target: "workspaces"

    function go(id: string): void {
      root.goToWorkspace(parseInt(id), "go");
    }

    function move(id: string): void {
      root.goToWorkspace(parseInt(id), "move");
    }

    function moveSilent(id: string): void {
      root.goToWorkspace(parseInt(id), "moveSilent");
    }

    // The n-th of the current row (grid), or workspace n (standard)
    function nth(n: string, mode: string): void {
      root.nthWorkspace(parseInt(n), mode);
    }

    // Moves workspaces left outside their output's ids (by a change made
    // while axiom wasn't running) back into them
    function reconcile(): void {
      root._remapWorkspaces(root._currentLayout(), root._currentLayout());
    }

    // direction: left, right, up or down
    function step(direction: string, mode: string): void {
      root.stepWorkspace(direction, mode);
    }

    function left(): void {
      root.stepWorkspace("left", "go");
    }

    function right(): void {
      root.stepWorkspace("right", "go");
    }

    function up(): void {
      root.stepWorkspace("up", "go");
    }

    function down(): void {
      root.stepWorkspace("down", "go");
    }
  }
}
