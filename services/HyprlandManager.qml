// Adapted from end-4's dots-hyprland
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config
import qs.components.methods

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

  function closeWindow(windowAddress) {
    Hyprland.dispatch(`hl.dsp.window.close({ window = ${_window(windowAddress)} })`);
  }

  // Focusing a window on another workspace switches to it, so that goes
  // through goToWorkspace to slide like any other switch
  function focusWindow(windowAddress) {
    const win = root.windowList.find(w => w.address === windowAddress);
    const monitor = Hyprland.monitors.values.find(m => m.id === win?.monitor);
    const id = win?.workspace?.id ?? -1;
    if (!monitor || id <= 0 || id === monitor.activeWorkspace?.id)
      Hyprland.dispatch(_focusWindowDispatcher(windowAddress));
    else
      goToWorkspace(id, "go", monitor, windowAddress);
  }

  function _focusWindowDispatcher(windowAddress) {
    return `hl.dsp.focus({ window = ${_window(windowAddress)} })`;
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

  // Moves the cursor to (x, y) inside one of axiom's layer surfaces: the
  // mapped one in `namespace` on `monitor` that is `width` × `height`
  // (layer-shell windows don't know where they are on screen, Hyprland
  // does). Nothing happens if none matches.
  function warpCursorToLayer(namespace, monitor, width, height, x, y) {
    _eval(`for _, l in ipairs(hl.get_layers({ namespace = ${JSON.stringify(namespace)} })) do
  if l.mapped and l.monitor and l.monitor.name == ${JSON.stringify(monitor)} and math.abs(l.w - ${Math.round(width)}) <= 1 and math.abs(l.h - ${Math.round(height)}) <= 1 then
    hl.dispatch(hl.dsp.cursor.move({ x = l.x + ${Math.round(x)}, y = l.y + ${Math.round(y)} }))
    return
  end
end`);
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
  // In a grid or perMonitor layout only the monitor's own workspaces are
  // reachable (`monitor`, the focused one by default), and it goes by
  // column, then row, sliding along each in turn (WorkspacesConfig.animate).
  // The standard and perMonitor layouts are one row (columns = count), so
  // they only ever slide sideways. Callers on a monitor's surface pass its
  // monitor, which is focused first. `focusAddress` (focusWindow) arrives
  // by focusing that window instead of the bare workspace.
  function goToWorkspace(id, mode, monitor, focusAddress) {
    if (!Number.isInteger(id) || id < 1) {
      console.warn(`[HyprlandManager] Not a workspace id: ${id}`);
      return;
    }
    mode = mode || "go";
    monitor = monitor ?? Hyprland.focusedMonitor;
    const base = workspaceBase(monitor);
    const size = WorkspacesConfig.size;
    if (WorkspacesConfig.perMonitorBlocks && (id < base || id >= base + size)) {
      if (focusAddress)
        Hyprland.dispatch(_focusWindowDispatcher(focusAddress));
      else
        console.warn(`[HyprlandManager] workspace ${id} is outside ${monitor?.name ?? "the focused monitor"}'s workspaces (${base}-${base + size - 1})`);
      return;
    }
    const focused = monitor === Hyprland.focusedMonitor;
    const current = focused ? _currentWorkspaceId() : (monitor?.activeWorkspace?.id ?? -1);
    if (id === current) {
      if (focusAddress)
        Hyprland.dispatch(_focusWindowDispatcher(focusAddress));
      return;
    }
    if (mode === "moveSilent") {
      Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false })`);
      return;
    }
    // A new switch replaces the rest of one still sliding, and slides on
    // from wherever that one has got to
    const sliding = root._slideSteps.length > 0;
    root._slideSteps = [];
    _slideTimer.stop();
    const at = sliding ? root._slideAt : current;
    root._lastGo = {
      "id": id,
      "time": Date.now()
    };
    const cols = WorkspacesConfig.columns;
    const from = at - base;
    const to = id - base;
    // Without the monitor focused, a new workspace would open on the
    // focused one
    const lead = focused || !monitor ? [] : [`hl.dsp.focus({ monitor = "${monitor.name}" })`];
    const arrive = focusAddress ? _focusWindowDispatcher(focusAddress) : _goDispatcher(id, mode);
    const steps = [];
    if (WorkspacesConfig.animate && root._workspaceAnim && from >= 0 && from < size) {
      if (from % cols !== to % cols)
        steps.push({
          "id": base + Math.floor(from / cols) * cols + to % cols,
          "style": "slide"
        });
      if (Math.floor(from / cols) !== Math.floor(to / cols))
        steps.push({
          "id": id,
          "style": "slidevert"
        });
    }
    if (steps.length === 0) {
      lead.concat([arrive]).forEach(dispatcher => Hyprland.dispatch(dispatcher));
      return;
    }
    // Two legs each take a fraction of the configured time, so going
    // diagonally across the grid is quicker than one plain switch
    const speed = steps.length > 1 ? Math.max(0.5, root._workspaceAnim.speed * root._legSpeed) : root._workspaceAnim.speed;
    root._slideSteps = steps.map((step, i) => Object.assign(step, {
        "dispatchers": (i === 0 ? lead : []).concat([step.id === id ? arrive : _goDispatcher(step.id, mode)]),
        "speed": speed
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
    if (root._slideSteps.length > 0 || Date.now() - root._lastGo.time < 300)
      return root._lastGo.id;
    return activeWorkspaceId();
  }

  // Hyprland's own "workspaces" animation ({ speed, bezier, style }), put
  // back after each slide (global's speed and curve when it isn't set);
  // null when animations are off, so there's nothing to slide with
  property var _workspaceAnim: null
  property var _slideSteps: []
  // Each leg's share of the configured speed on a two-leg slide
  readonly property real _legSpeed: 0.35
  // The workspace the last slide went to, while more are waiting
  property int _slideAt: -1

  function _nextSlide() {
    const step = root._slideSteps.shift();
    if (!step)
      return;
    const anim = root._workspaceAnim;
    const set = (style, speed) => `hl.animation({ leaf = "workspaces", enabled = true, speed = ${speed}, bezier = "${anim.bezier}", style = "${style}" })`;
    _eval([set(step.style, step.speed)].concat(step.dispatchers.map(dispatcher => `hl.dispatch(${dispatcher})`), [set(anim.style, anim.speed)]).join("\n"));
    root._slideAt = step.id;
    if (root._slideSteps.length > 0) {
      // Hyprland's speed is in tenths of a second
      _slideTimer.interval = Math.max(50, Math.round(step.speed * 100));
      _slideTimer.restart();
    }
  }

  // Lets the first slide finish before the second starts: switching again
  // mid-slide cuts it short, so the workspace would jump rather than slide
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
  // block's (grid/perMonitor, one block per monitor in a stable order —
  // the primary monitor first, then the rest by a description-based
  // identity that survives a port change — not raw Hyprland discovery
  // order, which can reshuffle on a hotplug/reconnect/restart)
  function workspaceBase(monitor) {
    if (!WorkspacesConfig.perMonitorBlocks)
      return WorkspacesConfig.baseFor(0);
    const index = _orderedMonitors().findIndex(m => m.id === monitor?.id);
    return WorkspacesConfig.baseFor(index >= 0 ? index : 0);
  }

  // Hyprland's monitors in block order (WorkspaceGeometry.orderMonitors)
  function _orderedMonitors() {
    const monitors = Hyprland.monitors.values;
    const plain = monitors.map(m => ({
          "id": m.id,
          "name": m.name,
          "key": MonitorLayout.outputId(m, monitors),
          "x": m.x,
          "y": m.y,
          "active": m.activeWorkspace?.id ?? -1,
          "focused": m === Hyprland.focusedMonitor
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
  // matching one in its monitor's ids under `to` (WorkspaceGeometry.
  // remapWorkspaces), and switches each monitor to the workspace matching
  // the one it showed. Hyprland creates a workspace on the monitor it's
  // first used from, so windows first go to a named workspace each (on their
  // own monitor, so a chain like 10 → 11, 11 → 12 can't merge), every
  // monitor leaves its old workspace for a named one (so an empty old one
  // is gone before its id is used again), then the windows go to their ids
  // and the monitors to theirs. The named workspaces end up empty and go.
  function _remapWorkspaces(from, to) {
    const windows = root.windowList.map(w => ({
          "address": w.address,
          "workspace": w.workspace?.id ?? -1,
          "monitor": w.monitor
        }));
    const monitors = _orderedMonitors();
    const plan = WorkspaceGeometry.remapWorkspaces(monitors, windows, from, to);
    if (!plan.changed)
      return;
    root._slideSteps = [];
    _slideTimer.stop();
    const anim = root._workspaceAnim;
    const set = enabled => `hl.animation({ leaf = "workspaces", enabled = ${enabled}, speed = ${anim.speed}, bezier = "${anim.bezier}", style = "${anim.style}" })`;
    const move = (address, workspace) => `run(function() return hl.dsp.window.move({ workspace = ${workspace}, follow = false, window = ${_window(address)} }) end)`;
    const focus = (monitor, workspace) => [`run(function() return hl.dsp.focus({ monitor = ${JSON.stringify(monitor)} }) end)`, `run(function() return hl.dsp.focus({ workspace = ${workspace} }) end)`];
    const lines = [].concat(anim ? [set(false)] : [], plan.moves.map(m => move(m.address, `"name:axiom-remap-${m.to}"`)), [].concat(...monitors.map((m, i) => focus(m.name, `"name:axiom-remap-mon-${i}"`))), plan.moves.map(m => move(m.address, m.to)), [].concat(...plan.focus.map(f => focus(f.monitor, f.id))), anim ? [set(true)] : []);
    const focused = plan.focus[plan.focus.length - 1];
    root._lastGo = {
      "id": focused?.id ?? -1,
      "time": Date.now()
    };
    console.log(`[HyprlandManager] remapping workspaces: ${plan.moves.length} windows, monitors to ${plan.focus.map(f => f.monitor + ":" + f.id).join(", ")}`);
    _eval(_luaPrelude + lines.join("\n") + _luaEpilogue);
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

  // The largest window on a workspace (its icon stands for the
  // workspace), or null
  function biggestWindowForWorkspace(workspaceId) {
    const area = w => (w?.size?.[0] ?? 0) * (w?.size?.[1] ?? 0);
    return root.windowList.filter(w => w.workspace?.id === workspaceId).reduce((biggest, w) => area(w) > area(biggest) ? w : biggest, null);
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
  // - Detached popouts and floating edge menus are drawn under the bars and
  //   border, so they slide out from beneath them.
  // - A dock is arranged after everything else on its edge, so it sits
  //   inside the bars and border. Edge popouts (the OSD, edge menus) come
  //   after it, so they draw over it where they reach past its zone.
  // - The overlay's panel comes after both: it sits inside an always-shown
  //   dock's zone and draws over a hover or intellihide dock.
  // - The screenshot picker's frozen frame appears and goes at once, with no
  //   fade over the live screen, and draws over everything else, the
  //   overlay included (popups can't be ordered: see captureFrozen).
  // Named, so re-adding one replaces it instead of piling up copies. Rules
  // added at runtime are lost when Hyprland reloads its config.
  // HyprlandConfigManager also writes them into its Lua files, since a
  // reload Hyprland does by itself (a watched file changing) doesn't always
  // send the configreloaded event that re-adds them here.
  readonly property var layerRulesLua: [`hl.layer_rule({ name = "axiom-backdrop", match = { namespace = "^axiom-backdrop$" }, order = 10 })`, `hl.layer_rule({ name = "axiom-bar", match = { namespace = "^axiom-bar$" }, order = 5 })`, `hl.layer_rule({ name = "axiom-edge-menu", match = { namespace = "^axiom-edge-menu$" }, order = 7 })`, `hl.layer_rule({ name = "axiom-popout-under", match = { namespace = "^axiom-popout-under$" }, order = 6 })`, `hl.layer_rule({ name = "axiom-dock", match = { namespace = "^axiom-dock$" }, order = -1 })`, `hl.layer_rule({ name = "axiom-edge-popout", match = { namespace = "^axiom-edge-popout$" }, order = -2 })`, `hl.layer_rule({ name = "axiom-overlay", match = { namespace = "^axiom-overlay$" }, order = -3 })`, `hl.layer_rule({ name = "axiom-screenshot", match = { namespace = "^axiom-screenshot$" }, no_anim = true, order = -20 })`]

  function _addLayerRules() {
    for (const rule of layerRulesLua)
      _eval(rule);
  }

  Component.onCompleted: {
    _appliedLayout = _currentLayout();
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
        // A leaf that isn't set takes its speed and curve from its parent
        // (workspaces from global), and slides by default
        const leaves = Array.isArray(all?.[0]) ? all[0] : [];
        const leaf = name => leaves.find(a => a.name === name);
        const own = leaf("workspaces");
        const anim = own?.overridden ? own : leaf("global");
        root._workspaceAnim = own?.enabled !== false && anim?.enabled && anim.bezier && anim.speed > 0 ? {
          "speed": anim.speed,
          "bezier": anim.bezier,
          "style": (own?.overridden && own.style) || "slide"
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

    // Moves workspaces left outside their monitor's ids (by a change
    // made while axiom wasn't running) back into them
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
