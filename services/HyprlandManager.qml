// Adapted from end-4's dots-hyprland
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

/* Provides access to some Hyprland data not available in Quickshell.Hyprland. */
Singleton {
  id: root
  property var windowList: []
  property var activeWorkspace: null

  // Refetch soon. Events arrive in bursts (a window opening fires several),
  // so they are coalesced into one fetch.
  function updateAll() {
    _debounce.restart();
  }

  // --- Actions ---

  // The Lua window selector for a hyprctl address ("0x…"). Dispatchers take
  // it as `window`; without one they act on the focused window.
  function _window(address) {
    return `"address:${address}"`;
  }

  function moveWindowToWorkspace(windowAddress, targetWorkspace) {
    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = ${_window(windowAddress)} })`);
  }

  function closeWindow(windowAddress) {
    Hyprland.dispatch(`hl.dsp.window.close({ window = ${_window(windowAddress)} })`);
  }

  function focusWindow(windowAddress) {
    Hyprland.dispatch(`hl.dsp.focus({ window = ${_window(windowAddress)} })`);
  }

  // Moves a window onto a workspace, tiling it on `side` ("left" | "right" |
  // "top" | "bottom") of `targetAddress`, or wherever when there's none.
  // Dwindle opens a moved window on the node nearest the cursor, and on the
  // focused window's when that's on the (active) workspace, then picks the
  // half by the cursor. So the chunk focuses the target if needed, warps the
  // cursor into the target's half and moves the window, then puts the cursor
  // back at `restore` (global). The target's box is read after the window has
  // left its workspace (`reinsert`: same workspace, moved out first), since
  // that reflows the layout. A floating window goes to `floatAt` instead.
  function placeWindow(address, workspaceId, targetAddress, side, restore, reinsert, floatAt) {
    const win = _window(address);
    const lines = [];
    if (floatAt) {
      if (!reinsert)
        lines.push(`run(function() return hl.dsp.window.move({ workspace = ${workspaceId}, follow = false, window = ${win} }) end)`);
      lines.push(`run(function() return hl.dsp.window.move({ x = ${Math.round(floatAt.x)}, y = ${Math.round(floatAt.y)}, window = ${win} }) end)`);
    } else {
      if (reinsert)
        lines.push(`run(function() return hl.dsp.window.move({ workspace = "name:axiom-drop", follow = false, window = ${win} }) end)`);
      if (targetAddress)
        lines.push(`aim(${_window(targetAddress)}, "${side}")`);
      lines.push(`run(function() return hl.dsp.window.move({ workspace = ${workspaceId}, follow = false, window = ${win} }) end)`);
      lines.push(`run(function() return hl.dsp.cursor.move({ x = ${Math.round(restore.x)}, y = ${Math.round(restore.y)} }) end)`);
    }
    _eval(_luaPrelude + lines.join("\n") + _luaEpilogue);
  }

  // Grows a window by (dw, dh) and moves it by (dx, dy). On a tiled window a
  // delta moves its nearest split by that much (dwindle smart resizing), so
  // the split follows the mouse; dx/dy only apply to floating windows.
  function resizeWindow(address, dw, dh, dx, dy) {
    const win = _window(address);
    const lines = [];
    if (dw !== 0 || dh !== 0)
      lines.push(`run(function() return hl.dsp.window.resize({ x = ${Math.round(dw)}, y = ${Math.round(dh)}, relative = true, window = ${win} }) end)`);
    if (dx !== 0 || dy !== 0)
      lines.push(`run(function() return hl.dsp.window.move({ x = ${Math.round(dx)}, y = ${Math.round(dy)}, relative = true, window = ${win} }) end)`);
    if (lines.length > 0)
      _eval(_luaPrelude + lines.join("\n") + _luaEpilogue);
  }

  // Every step runs even if an earlier one fails (so the cursor always goes
  // back); the failures are raised together at the end, and logged.
  // aim(): focus the target if it's on its monitor's active workspace, then
  // warp into the middle of its `side` half. Dwindle splits side by side when
  // the box is wider than tall (split_width_multiplier), so a side along the
  // other axis falls back to first/second half on the axis dwindle will use.
  readonly property string _luaPrelude: `local errs = {}
local function run(f)
  local ok, e = pcall(function() hl.dispatch(f()) end)
  if not ok then errs[#errs + 1] = tostring(e) end
end
local function aim(sel, side)
  local t = hl.get_window(sel)
  if not t then errs[#errs + 1] = "target not found"; return end
  local x, y = t.at.x or t.at[1], t.at.y or t.at[2]
  local w, h = t.size.x or t.size[1], t.size.y or t.size[2]
  local first = side == "left" or side == "top"
  local px, py = x + w / 2, y + h / 2
  if w > h * ${splitWidthMultiplier} then
    px = first and x + w / 4 or x + w * 3 / 4
  else
    py = first and y + h / 4 or y + h * 3 / 4
  end
  if t.workspace and t.workspace.active then
    run(function() return hl.dsp.focus({ window = sel }) end)
  end
  run(function() return hl.dsp.cursor.move({ x = px, y = py }) end)
end
`
  readonly property string _luaEpilogue: `
if #errs > 0 then error(table.concat(errs, "; ")) end`

  // Lua chunks run one at a time, in order, through `hyprctl eval`
  property var _evalQueue: []

  // Runs a Lua chunk in Hyprland (config functions like hl.bind or
  // hl.config, which a dispatch can't call); failures are logged
  function runLua(lua) {
    _eval(lua);
  }

  // Re-reads the options axiom follows (gaps, split ratio, the workspaces
  // animation), after something changed them at runtime
  function refreshOptions() {
    getGaps.running = true;
    getSplitMultiplier.running = true;
    getAnimations.running = true;
  }

  function _eval(lua) {
    _evalQueue.push(lua);
    if (!evalProcess.running)
      _nextEval();
  }

  function _nextEval() {
    if (_evalQueue.length === 0) {
      root.updateAll();
      return;
    }
    evalProcess.command = ["hyprctl", "eval", _evalQueue.shift()];
    evalProcess.running = true;
  }

  // --- Workspaces (laid out by WorkspacesConfig) ---

  // Goes to workspace `id`. mode: "go" (default), "move" (taking the
  // focused window along) or "moveSilent" (sending it there, staying put).
  // In a grid only the monitor's own workspaces are reachable (`monitor`,
  // the focused one by default), and it goes by row, then column, sliding
  // along each (WorkspacesConfig.animate). The standard layout is one row
  // (columns = count), so it only ever slides sideways.
  function goToWorkspace(id, mode, monitor) {
    mode = mode || "go";
    monitor = monitor ?? Hyprland.focusedMonitor;
    const base = workspaceBase(monitor);
    const size = WorkspacesConfig.size;
    if (WorkspacesConfig.grid && (id < base || id >= base + size)) {
      console.warn(`[HyprlandManager] workspace ${id} is outside ${monitor?.name ?? "the focused monitor"}'s grid (${base}-${base + size - 1})`);
      return;
    }
    const current = monitor === Hyprland.focusedMonitor ? _currentWorkspaceId() : (monitor?.activeWorkspace?.id ?? -1);
    if (id === current)
      return;
    if (mode === "moveSilent") {
      Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false })`);
      return;
    }
    root._lastGo = {
      "id": id,
      "time": Date.now()
    };
    const cols = WorkspacesConfig.columns;
    const from = current - base;
    const to = id - base;
    const steps = [];
    if (WorkspacesConfig.animate && root._workspaceAnim && from >= 0 && from < size) {
      if (Math.floor(from / cols) !== Math.floor(to / cols))
        steps.push({
          "id": base + Math.floor(to / cols) * cols + from % cols,
          "style": "slidevert"
        });
      if (from % cols !== to % cols)
        steps.push({
          "id": id,
          "style": "slide"
        });
    }
    if (steps.length === 0) {
      Hyprland.dispatch(_goDispatcher(id, mode));
      return;
    }
    root._slideSteps = steps.map(step => Object.assign(step, {
        "mode": mode
      }));
    _nextSlide();
  }

  // One step left/right/up/down from the current workspace: within the
  // monitor's grid, or through 1..count in the standard layout (where up is
  // previous and down next). Stops at the edges unless WorkspacesConfig.wrap.
  function stepWorkspace(direction, mode) {
    const base = workspaceBase(Hyprland.focusedMonitor);
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
      col = (col + cols) % cols;
      row = (row + rows) % rows;
    }
    goToWorkspace(base + row * cols + col, mode);
  }

  // The n-th workspace (1-based) of the current row in a grid, or
  // workspace n in the standard layout (number keybinds)
  function nthWorkspace(n, mode) {
    if (!WorkspacesConfig.grid) {
      goToWorkspace(n, mode);
      return;
    }
    const cols = WorkspacesConfig.columns;
    if (n < 1 || n > cols)
      return;
    const base = workspaceBase(Hyprland.focusedMonitor);
    const index = Math.min(Math.max(_currentWorkspaceId() - base, 0), WorkspacesConfig.size - 1);
    goToWorkspace(base + Math.floor(index / cols) * cols + n - 1, mode);
  }

  function _goDispatcher(id, mode) {
    return mode === "move" ? `hl.dsp.window.move({ workspace = ${id} })` : `hl.dsp.focus({ workspace = ${id} })`;
  }

  // The last workspace gone to, for a moment: key presses can come faster
  // than Hyprland reports the switch
  property var _lastGo: ({
      "id": -1,
      "time": 0
    })

  function _currentWorkspaceId() {
    if (Date.now() - root._lastGo.time < 300)
      return root._lastGo.id;
    return activeWorkspaceId();
  }

  // Hyprland's own "workspaces" animation ({ speed, bezier, style }), put
  // back after each slide; null when it isn't configured (or is off), so
  // there's nothing to slide with
  property var _workspaceAnim: null
  property var _slideSteps: []

  function _nextSlide() {
    const step = root._slideSteps.shift();
    if (!step)
      return;
    const anim = root._workspaceAnim;
    const set = style => `hl.animation({ leaf = "workspaces", enabled = true, speed = ${anim.speed}, bezier = "${anim.bezier}", style = "${style}" })`;
    _eval([set(step.style), `hl.dispatch(${_goDispatcher(step.id, step.mode)})`, set(anim.style)].join("\n"));
    if (root._slideSteps.length > 0)
      _slideTimer.restart();
  }

  // Lets the first slide start before the second changes the animation
  property Timer _slideTimer: Timer {
    interval: 80
    onTriggered: root._nextSlide()
  }

  // --- Queries ---

  // Calls back with the name of the screen under the cursor (the focused
  // monitor if hyprctl can't say). Asynchronous: one hyprctl call.
  function withHoveredScreen(callback) {
    withCursorPos(pos => callback((pos ? root._screenAt(pos.x, pos.y) : "") || (Hyprland.focusedMonitor?.name ?? General.primaryMonitor)));
  }

  // Calls back with the cursor's global position ({ x, y }), or null if
  // hyprctl can't say. Calls made while one is running share its answer.
  function withCursorPos(callback) {
    _cursorCallbacks.push(callback);
    getCursorPos.running = true;
  }

  property var _cursorCallbacks: []

  function _screenAt(x, y) {
    for (const screen of Quickshell.screens) {
      if (x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height)
        return screen.name;
    }
    return "";
  }

  function activeWorkspaceId() {
    return Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
  }

  // The Wayland toplevel for a hyprctl window address ("0x…")
  function toplevelForAddress(address) {
    for (const toplevel of Hyprland.toplevels.values) {
      if ("0x" + toplevel.address === address)
        return toplevel.wayland;
    }
    return null;
  }

  // First workspace id a monitor shows: 1 in the standard layout, else its
  // grid's (columns × rows ids per monitor, in Hyprland's monitor order)
  function workspaceBase(monitor) {
    const monitors = Hyprland.monitors.values;
    for (let i = 0; i < monitors.length; i++) {
      if (monitors[i].id === monitor?.id)
        return WorkspacesConfig.baseFor(i);
    }
    return 1;
  }

  // The workspace ids a monitor shows, in order
  function workspaceIds(monitor) {
    const base = workspaceBase(monitor);
    const ids = [];
    for (let i = 0; i < WorkspacesConfig.size; i++)
      ids.push(base + i);
    return ids;
  }

  // Whether the named monitor's active workspace shows a fullscreen window.
  // Not Hyprland's (or Quickshell's) hasFullscreen: that also counts
  // maximized windows (fullscreen mode 1), which leave reserved space
  // alone. Mode is a bitmask, 2 being fullscreen.
  function hasFullscreen(monitorName) {
    const workspace = Hyprland.monitors.values.find(m => m.name === monitorName)?.activeWorkspace?.id;
    return workspace !== undefined && root.windowList.some(w => w.workspace?.id === workspace && (w.fullscreen & 2));
  }

  function biggestWindowForWorkspace(workspaceId) {
    const windowsInThisWorkspace = root.windowList.filter(w => w.workspace.id == workspaceId);
    return windowsInThisWorkspace.reduce((maxWin, win) => {
      const maxArea = (maxWin?.size[0] ?? 0) * (maxWin?.size[1] ?? 0);
      const winArea = (win?.size[0] ?? 0) * (win?.size[1] ?? 0);
      return winArea > maxArea ? win : maxWin;
    }, null);
  }

  // Hyprland's general:gaps_out per side, which it adds after every
  // reserved zone (transparent bars subtract it, see BarPanel)
  property var gapsOut: ({
      "top": 0,
      "right": 0,
      "bottom": 0,
      "left": 0
    })

  // dwindle:split_width_multiplier: a box wider than tall times this splits
  // side by side (placeWindow, and the overview's drop preview)
  property real splitWidthMultiplier: 1

  // Hyprland arranges and stacks each layer's surfaces in the order they
  // were mapped, unless a layer rule's `order` says otherwise (higher is
  // "closer to the edge of the monitor": arranged, and drawn, first).
  // - Full-screen surfaces' backdrops (ScreenBackdrop) are Top-layer
  //   surfaces that must sit under the bars and border, which are mapped
  //   before them.
  // - A solid bar must be arranged before the border's strip on its edge,
  //   which then lands on the bar's inner part (see BarPanel). Mapping
  //   order alone breaks whenever the bar's surface is remade or changes
  //   layer (a new monitor, a new bar id on restore, solid <-> floating):
  //   Hyprland appends it after the border.
  // - An integrated edge menu is arranged before both, so it sits at the
  //   screen edge and pushes the bars, border and windows inwards.
  // Named, so re-adding one replaces it instead of piling up copies. Rules
  // added at runtime are lost when Hyprland reloads its config.
  function _addLayerRules() {
    _eval(`hl.layer_rule({ name = "axiom-backdrop", match = { namespace = "^axiom-backdrop$" }, order = 10 })`);
    _eval(`hl.layer_rule({ name = "axiom-bar", match = { namespace = "^axiom-bar$" }, order = 5 })`);
    _eval(`hl.layer_rule({ name = "axiom-edge-menu", match = { namespace = "^axiom-edge-menu$" }, order = 7 })`);
  }

  Component.onCompleted: {
    _fetch();
    refreshOptions();
    _addLayerRules();
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      // Layer surfaces (including our own popouts) don't affect clients
      if (event.name === "openlayer" || event.name === "closelayer")
        return;
      if (event.name === "configreloaded") {
        root.refreshOptions();
        root._addLayerRules();
      }
      root.updateAll();
    }
  }

  Process {
    id: evalProcess
    stdout: StdioCollector {
      id: evalCollector
      onStreamFinished: {
        const out = evalCollector.text.trim();
        if (out !== "" && out !== "ok")
          console.warn("[HyprlandManager] hyprctl eval:", out);
      }
    }
    stderr: StdioCollector {
      id: evalErrors
      onStreamFinished: {
        if (evalErrors.text.trim() !== "")
          console.warn("[HyprlandManager] hyprctl eval:", evalErrors.text.trim());
      }
    }
    onExited: root._nextEval()
  }

  Process {
    id: getSplitMultiplier
    command: ["hyprctl", "getoption", "dwindle:split_width_multiplier", "-j"]
    stdout: StdioCollector {
      id: splitCollector
      onStreamFinished: {
        const value = Number(root._parse(splitCollector.text, "getoption")?.float);
        if (value > 0)
          root.splitWidthMultiplier = value;
      }
    }
  }

  property Timer _debounce: Timer {
    interval: 50
    onTriggered: root._fetch()
  }

  // Set when a fetch is asked for while one is still running: starting a
  // running Process is a no-op, so it's re-run once the current one ends
  property bool _pending: false

  function _fetch() {
    if (getClients.running || getActiveWorkspace.running) {
      _pending = true;
      return;
    }
    getClients.running = true;
    getActiveWorkspace.running = true;
  }

  function _fetchFinished() {
    if (_pending && !getClients.running && !getActiveWorkspace.running) {
      _pending = false;
      _fetch();
    }
  }

  function _parse(text, what) {
    try {
      return JSON.parse(text);
    } catch (e) {
      console.warn("[HyprlandManager] Could not parse hyprctl " + what + ":", e);
      return undefined;
    }
  }

  Process {
    id: getCursorPos
    command: ["hyprctl", "cursorpos", "-j"]
    stdout: StdioCollector {
      id: cursorCollector
      onStreamFinished: {
        const pos = root._parse(cursorCollector.text, "cursorpos");
        const callbacks = root._cursorCallbacks;
        root._cursorCallbacks = [];
        callbacks.forEach(callback => callback(pos ?? null));
      }
    }
  }

  Process {
    id: getAnimations
    command: ["hyprctl", "animations", "-j"]
    stdout: StdioCollector {
      id: animationsCollector
      onStreamFinished: {
        // [animations, beziers]
        const all = root._parse(animationsCollector.text, "animations");
        const anim = (Array.isArray(all?.[0]) ? all[0] : []).find(a => a.name === "workspaces");
        root._workspaceAnim = anim?.overridden && anim.enabled && anim.bezier ? {
          "speed": anim.speed,
          "bezier": anim.bezier,
          "style": anim.style || "slide"
        } : null;
      }
    }
  }

  Process {
    id: getGaps
    command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
    stdout: StdioCollector {
      id: gapsCollector
      onStreamFinished: {
        // css is "top right bottom left" (CSS shorthand, like gaps_out)
        const option = root._parse(gapsCollector.text, "getoption");
        const css = String(option?.css ?? "").trim().split(/\s+/).map(Number);
        if (css.length === 0 || css.some(isNaN))
          return;
        const [top, right = top, bottom = top, left = right] = css;
        root.gapsOut = {
          "top": top,
          "right": right,
          "bottom": bottom,
          "left": left
        };
      }
    }
  }

  Process {
    id: getClients
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      id: clientsCollector
      onStreamFinished: {
        const clients = root._parse(clientsCollector.text, "clients");
        if (Array.isArray(clients))
          root.windowList = clients;
      }
    }
    onExited: root._fetchFinished()
  }

  Process {
    id: getActiveWorkspace
    command: ["hyprctl", "activeworkspace", "-j"]
    stdout: StdioCollector {
      id: activeWorkspaceCollector
      onStreamFinished: {
        const workspace = root._parse(activeWorkspaceCollector.text, "activeworkspace");
        if (workspace)
          root.activeWorkspace = workspace;
      }
    }
    onExited: root._fetchFinished()
  }

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
