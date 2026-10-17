pragma Singleton
import QtQuick

// The Lua axiom's Hyprland layer is made of (HyprlandConfigWriter): each
// bind's hl.bind(), the included module, the managed hyprland.lua and the
// one given back on leaving managed. Everything it reads from config comes
// in as arguments; BindActions says what the actions are, this says how
// Hyprland runs them.
QtObject {
  id: root

  // A Lua string literal
  function _lua(text) {
    return HyprLua.string(text);
  }

  // A single-quoted shell word
  function shellWord(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
  }

  // A color ({ r, g, b } in 0-1) as "rrggbb"
  function hex(color) {
    return CompositorLayer.hex(color);
  }

  // `lines` joined, each but the empty ones after `prefix`
  function indent(lines, prefix) {
    return lines.map(line => line === "" ? "" : prefix + line).join("\n");
  }

  // The dispatcher Lua of a compositor action (BindActions.compositorActions)
  // for `argument`, or "" when the argument doesn't fit it. `ctx`:
  // { shellCommand, terminal, fileManager, browser }
  function dispatcherLua(action, argument, ctx) {
    switch (action) {
    case "focusDir":
      return `hl.dsp.focus({ direction = ${_lua(argument)} })`;
    case "moveWindowDir":
      return `hl.dsp.window.move({ direction = ${_lua(argument)} })`;
    case "resizeWindow":
      {
        const [x, y] = argument.split(/[\s,]+/).map(Number);
        return isFinite(x) && isFinite(y) ? `hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })` : "";
      }
    case "closeWindow":
      return "hl.dsp.window.close()";
    case "fullscreen":
      return "hl.dsp.window.fullscreen()";
    case "toggleFloat":
      return `hl.dsp.window.float({ action = "toggle" })`;
    case "pin":
      return "hl.dsp.window.pin()";
    case "centerWindow":
      return "hl.dsp.window.center()";
    case "toggleGroup":
      return "hl.dsp.group.toggle()";
    case "pseudo":
      return "hl.dsp.window.pseudo()";
    case "toggleSplit":
      return `hl.dsp.layout("togglesplit")`;
    // Strips (the scrolling layout): the column before (left, up) or after
    // (right, down) swaps with the focused one; widths step through
    // scrolling.explicit_column_widths
    case "stripSwapColumn":
      return `hl.dsp.layout(${_lua("swapcol " + (argument === "left" || argument === "up" ? "l" : "r"))})`;
    case "stripWider":
      return `hl.dsp.layout("colresize +conf")`;
    case "stripNarrower":
      return `hl.dsp.layout("colresize -conf")`;
    case "stripFit":
      return `hl.dsp.layout("fit visible")`;
    // Any dispatcher, as Lua (`hl.dsp.layout("swapsplit")`), compiled when
    // the bind is made so a mistake only leaves that bind doing nothing
    // instead of breaking the whole file (bindLua leaves out a raw command
    // written for another compositor)
    case "raw":
      return `(function() local ok, d = pcall(load(${_lua("return " + argument)}) or error) if ok and d then return d end return hl.dsp.no_op() end)()`;
    // Lua functions entering the switcher's submap (HyprLua.switcherLua)
    case "windowSwitcher":
    case "windowSwitcherReverse":
      return HyprLua.switcherBindLua(BindActions.switcherSteps[action]);
    // On a mouse button (SUPER + mouse:272), which Hyprland makes a mouse
    // bind by itself
    case "mouseDrag":
      return "hl.dsp.window.drag()";
    case "mouseResize":
      return "hl.dsp.window.resize()";
    case "toggleSpecial":
      return `hl.dsp.workspace.toggle_special(${_lua(argument)})`;
    case "moveToSpecial":
      return `hl.dsp.window.move({ workspace = ${_lua("special:" + argument)} })`;
    // Run by Hyprland, not over IPC, so it works when the shell is stuck
    case "restartShell":
      return `hl.dsp.exec_cmd(${_lua(`qs kill ${ctx.shellCommand.slice(3)}; ${ctx.shellCommand} -d`)})`;
    case "exitSession":
      return `hl.dsp.exec_cmd(${_lua("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")})`;
    // The apps from the Apps settings, so a bind follows them
    case "terminal":
      return `hl.dsp.exec_cmd(${_lua(ctx.terminal)})`;
    case "fileManager":
      return `hl.dsp.exec_cmd(${_lua(ctx.fileManager)})`;
    case "browser":
      return `hl.dsp.exec_cmd(${_lua(ctx.browser)})`;
    }
    return "";
  }

  // The hl.bind() line for a configured bind, or "" when it's incomplete
  // (no key, a missing argument, or an argument its action can't use).
  // `ctx` as for dispatcherLua
  function bindLua(bind, ctx) {
    const argument = String(bind.argument ?? "").trim();
    if (!String(bind.key ?? "").trim() || (BindActions.needsArgument(bind.action) && !argument) || (bind.action === "raw" && (bind.compositor ?? "hyprland") !== "hyprland"))
      return "";
    let dispatcher;
    if (BindActions.compositorActions[bind.action]) {
      dispatcher = dispatcherLua(bind.action, argument, ctx);
    } else if (bind.action === "exec") {
      dispatcher = `hl.dsp.exec_cmd(${_lua(argument)})`;
    } else if (BindActions.ipcActions[bind.action]) {
      const ipc = BindActions.ipcActions[bind.action][0].replace("{call}", BindActions.callFunction(bind)).replace("{0}", shellWord(argument));
      dispatcher = `hl.dsp.exec_cmd(${_lua(`${ctx.shellCommand} ipc call ${ipc}`)})`;
    }
    if (!dispatcher)
      return "";
    const options = [`description = ${_lua(BindActions.descriptionFor(bind))}`];
    for (const flag of BindActions.flagNames)
      if (bind[flag])
        options.push(`${flag} = true`);
    return `hl.bind(${_lua(bind.key.trim())}, ${dispatcher}, { ${options.join(", ")} })`;
  }

  // The window switcher's submap for the switcher binds among `binds`
  // (HyprLua.switcherLua)
  function switcherLua(binds, ctx) {
    const entries = binds.filter(bind => BindActions.switcherSteps[bind.action] !== undefined && bindLua(bind, ctx) !== "").map(bind => Object.assign(KeyNames.split(bind.key), {
        "step": BindActions.switcherSteps[bind.action]
      }));
    return HyprLua.switcherLua(entries);
  }

  // Every complete bind's line, then the switcher's submap
  function bindLines(binds, ctx) {
    return binds.map(bind => bindLua(bind, ctx)).filter(line => line !== "").concat(switcherLua(binds, ctx));
  }

  // Session lock restore, ignoring apps' maximize requests and, with
  // `withAnimation`, a workspaces animation (axiom's grid slides)
  function requiredLua(withAnimation) {
    // The maximize rule is Hyprland's example config's, which managed mode replaces:
    // without it apps like kitty (remember_window_size) reopen maximized
    const lines = ["hl.config({ misc = { allow_session_lock_restore = true } })", `hl.window_rule({ name = "axiom-suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })`];
    if (withAnimation)
      lines.push(`hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slide" })`);
    return lines;
  }

  // The included module, a table whose setup() applies what's enabled.
  // `parts`: { header, includeLines, requiredSettings, and the Lua lines of
  // binds, look, input, blur, layers, monitors, strips }
  function moduleLua(parts) {
    const setup = [];
    if (parts.requiredSettings)
      setup.push("M.required()");
    setup.push("M.binds()");
    setup.push("M.look()");
    setup.push("M.input()");
    setup.push("M.blur()");
    setup.push("M.layers()");
    setup.push("M.monitors()");
    setup.push("M.strips()");
    return `${parts.header} from its Hyprland settings, and rewritten whenever they
-- (or the theme) change: edit those, not this file.
--
-- Load it near the top of hyprland.lua, so what follows overrides it:
--   ${parts.includeLines.replace("\n", "\n--   ")}
-- setup() applies everything enabled in axiom's settings; call the parts
-- instead to pick. hl.unbind("KEY") after it frees one of axiom's keys.
local M = {}

-- Session lock restore, ignoring apps' maximize requests and a workspaces
-- animation (axiom's grid slides)
function M.required()
${indent(requiredLua(true), "  ")}
end

function M.binds()
${indent(parts.binds, "  ")}
end

-- Window borders in the axiom theme, its shape, gaps, Hyprland's blur and
-- window opacity, as enabled. axiom applies them again after every reload,
-- so they win over what follows while they're on.
function M.look()
${indent(parts.look, "  ")}
end
-- Its old name
M.theme = M.look

-- The keyboard, mouse and touchpad, as enabled; applied again after every
-- reload like the look
function M.input()
${indent(parts.input, "  ")}
end

-- Blur behind axiom's surfaces while they're translucent (on or off, so
-- turning it off takes it back), at Hyprland's blur
function M.blur()
${indent(parts.blur, "  ")}
end

-- Stacking order of axiom's surfaces (bars, border, edge menus, backdrops)
function M.layers()
${indent(parts.layers, "  ")}
end

-- Monitor profiles from the Monitors page: the one for what's connected,
-- again whenever a monitor comes or goes
function M.monitors()
${indent(parts.monitors, "  ")}
end

-- Strips (the scrolling layout) on the monitors Workspaces lists
function M.strips()
${indent(parts.strips, "  ")}
end

function M.setup()
${indent(setup, "  ")}
end

-- Lets axiom see that this file is loaded
AXIOM_INCLUDED = true

return M
`;
  }

  // The included module once axiom isn't in that mode: every part a no-op,
  // so a hyprland.lua still loading it (setup() or any part) gets nothing
  function emptyModuleLua(header) {
    return `${header}: Hyprland mode isn't "included", so this module does
-- nothing. Switching back to included writes it again.
return setmetatable({}, { __index = function() return function() end end })
`;
  }

  // What the managed file runs once Hyprland has started: the cursor
  // (`cursor`: CompositorLayer.input()'s), axiom (`start.command`), then the Session
  // `session`'s autostart commands. A plain `hypridle` is left out while
  // axiom runs its own (`start.idle`), and a polkit agent while axiom is
  // the agent (`start.polkit`).
  function startLua(session, cursor, start) {
    const lines = [];
    if (cursor)
      lines.push(`hl.exec_cmd(${_lua(`hyprctl setcursor ${shellWord(cursor.theme)} ${cursor.size}`)})`);
    lines.push(`hl.exec_cmd(${_lua(start.command)})`);
    for (const entry of session.autostart)
      if (entry.enabled && entry.command.trim() !== "" && !(start.idle && entry.command.trim() === "hypridle") && !(start.polkit && PolkitAgents.isAgentCommand(entry.command)))
        lines.push(`hl.exec_cmd(${_lua(entry.command.trim())})`);
    return lines;
  }

  // The session's environment (`env`: CompositorLayer.sessionEnv's) as
  // hl.env calls
  function envLua(env) {
    return (env ?? []).map(entry => `hl.env(${_lua(entry.name)}, ${_lua(entry.value)})\n`).join("");
  }

  // Animation presets: curves { name: [x1, y1, x2, y2] } and leaves
  // [leaf, speed (Hyprland's unit: 100 ms), curve, style]
  readonly property var animationPresets: ({
      "snappy": {
        "curves": {
          "axiomSnappy": [0.2, 0, 0, 1]
        },
        "leaves": [["windows", 2, "axiomSnappy", "popin 90%"], ["layers", 2, "axiomSnappy", "fade"], ["fade", 2, "axiomSnappy", ""], ["border", 1, "axiomSnappy", ""], ["workspaces", 2.5, "axiomSnappy", "slide"], ["specialWorkspace", 2.5, "axiomSnappy", "slidevert"]]
      },
      "bouncy": {
        "curves": {
          "axiomSnappy": [0.2, 0, 0, 1],
          "axiomOvershoot": [0.34, 1.56, 0.64, 1]
        },
        "leaves": [["windows", 4, "axiomOvershoot", "popin 60%"], ["windowsOut", 3, "axiomSnappy", "popin 80%"], ["layers", 3, "axiomOvershoot", "fade"], ["fade", 3, "axiomSnappy", ""], ["border", 2, "axiomSnappy", ""], ["workspaces", 4, "axiomOvershoot", "slide"], ["specialWorkspace", 4, "axiomOvershoot", "slidevert"]]
      },
      // Windows in and out almost at once, bouncing in, workspaces fading
      "lightning": {
        "curves": {
          "lightningSlow": [0, 0.85, 0.3, 1],
          "lightningOut": [0.3, -0.3, 0, 1],
          "lightningWind": [0.05, 0.9, 0.1, 1],
          "lightningOvershot": [0.7, 0.6, 0.1, 1.1],
          "lightningBounce": [1.1, 1.6, 0.1, 0.85],
          "lightningDecel": [0.05, 0.7, 0.1, 1]
        },
        "leaves": [["windowsIn", 0.5, "lightningSlow", "popin"], ["windowsOut", 0.5, "lightningOut", "popin"], ["windowsMove", 0.7, "lightningWind", "slide"], ["fade", 2, "lightningOvershot", ""], ["workspaces", 2.5, "lightningWind", "fade"], ["windows", 2, "lightningBounce", "popin"], ["specialWorkspace", 0.8, "lightningDecel", "slidevert"]]
      }
    })

  // The preset (or custom list) of the managed settings `m` as { curves,
  // leaves }, or null for Hyprland's own animations. `motion`: the shell's
  // { fast, normal, slow } durations in ms (the "axiom" preset)
  function animationSet(m, motion) {
    switch (m.animationPreset) {
    case "axiom":
      {
        // Look & Feel → Motion: the shell's durations, in Hyprland's unit
        const speed = ms => Math.max(0.1, ms / 100);
        return {
          "curves": {
            "axiomMotion": [0.05, 0.7, 0.1, 1]
          },
          "leaves": [["windows", speed(motion.slow), "axiomMotion", "popin 80%"], ["layers", speed(motion.normal), "axiomMotion", "fade"], ["fade", speed(motion.normal), "axiomMotion", ""], ["border", speed(motion.fast), "axiomMotion", ""], ["workspaces", speed(motion.slow), "axiomMotion", "slide"], ["specialWorkspace", speed(motion.slow), "axiomMotion", "slidevert"]]
        };
      }
    case "custom":
      {
        const curves = {};
        for (const curve of m.curves) {
          const points = curve.points.split(",").map(Number);
          if (curve.name.trim() !== "" && points.length === 4 && points.every(isFinite))
            curves[curve.name.trim()] = points;
        }
        return {
          "curves": curves,
          "leaves": m.customAnimations.map(a => [a.leaf, a.enabled ? a.durationMs / 100 : 0, a.curve.trim() || "default", a.style.trim()])
        };
      }
    }
    return root.animationPresets[m.animationPreset] ?? null;
  }

  // The curves and animations of the managed settings `m`, or "" for
  // Hyprland's own. `motion`: { fast, normal, slow, enabled } (the shell's
  // animations; following axiom's motion while it's off turns them off,
  // in configLua)
  function animationsLua(m, motion) {
    const off = !m.animations || (m.animationPreset === "axiom" && !motion.enabled);
    const set = off ? null : animationSet(m, motion);
    if (!set)
      return "";
    const lines = Object.keys(set.curves).map(name => {
      const p = set.curves[name].map(v => HyprLua.value(v));
      return `hl.curve(${_lua(name)}, { type = "bezier", points = { { ${p[0]}, ${p[1]} }, { ${p[2]}, ${p[3]} } } })`;
    });
    for (const [leaf, speed, curve, style] of set.leaves) {
      const parts = [`leaf = ${_lua(leaf)}`, `enabled = ${speed > 0}`];
      if (speed > 0)
        parts.push(`speed = ${HyprLua.value(speed)}`, `bezier = ${_lua(curve)}`);
      if (speed > 0 && style !== "")
        parts.push(`style = ${_lua(style)}`);
      lines.push(`hl.animation({ ${parts.join(", ")} })`);
    }
    return "\n" + lines.join("\n") + "\n";
  }

  // The managed settings `m` as one hl.config() table. `opts`: { schema
  // (Hyprland.managed's), resolveHex (a theme color name → "rrggbb"),
  // motion }. The border width and rounding are the window look's
  // (M.look()).
  function configLua(m, opts) {
    const overrides = {};
    // Following axiom's motion includes turning animations off with it
    if (m.animationPreset === "axiom" && !opts.motion.enabled)
      overrides["animations.enabled"] = false;
    return `hl.config(${HyprLua.serialize(HyprLua.configTable(opts.schema, m, opts.resolveHex, overrides))})`;
  }

  // Loads user/*.lua (in `userDir`) in name order: the end of managedLua()
  // and of releasedLua()
  function userFilesLua(userDir) {
    return `-- Your files, through require (as user.<name>) so Hyprland reloads when
-- one changes. Shared modules go in user/lib/ (require("user.lib.x")),
-- which isn't loaded here. A failing file doesn't stop the rest; the
-- errors are raised together at the end (hyprctl configerrors).
local errors = {}
local files = io.popen("cd " .. ${_lua(shellWord(userDir))} .. " 2>/dev/null && ls -1 *.lua 2>/dev/null")
if files then
  for file in files:lines() do
    local ok, err = pcall(require, "user." .. file:gsub("%.lua$", ""))
    if not ok then errors[#errors + 1] = tostring(err) end
  end
  files:close()
end
if #errors > 0 then error(table.concat(errors, "\\n")) end`;
  }

  // The managed hyprland.lua: `module` (moduleLua()'s text, its comments
  // dropped) wrapped, the managed settings `m`, setup(), the animations,
  // the start commands and user/*.lua. `opts`: configLua's, plus { header,
  // userDir, session (Session's values), env (envLua's), cursor and start
  // (startLua's) }
  function managedLua(module, m, opts) {
    const body = module.split("\n").filter(line => !line.startsWith("--")).join("\n").trim();
    return `${opts.header} (Hyprland mode: managed) from its Hyprland settings,
-- and rewritten whenever they (or the theme) change: edit those, not this file.
-- Your own config goes in ${opts.userDir}/*.lua, loaded after this in name
-- order, so it overrides it. hl.unbind("KEY") there frees one of axiom's keys.

local axiom = (function()
${indent(body.split("\n"), "  ")}
end)()

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
${envLua(opts.env)}
${configLua(m, opts)}
axiom.setup()
${animationsLua(m, opts.motion)}
hl.on("hyprland.start", function()
${indent(startLua(opts.session, opts.cursor, opts.start), "  ")}
end)

${userFilesLua(opts.userDir)}
`;
  }

  // The hyprland.lua leaving managed gives back when the takeover set
  // nothing aside (claim_hyprland.sh release): the user's from then on,
  // running `startLines` (starting axiom, and loading its module in
  // included mode) and loading user/*.lua as the managed one did
  function releasedLua(userDir, startLines) {
    return `-- Given back by axiom when it stopped managing Hyprland: this file is yours
-- now, and axiom won't write it again. It starts axiom and loads
-- ${userDir}/*.lua, as axiom's managed one did.
${startLines}

-- Not when it's required as one of those files itself (a managed takeover
-- adopts it into user/): the file requiring it loads them
if select("#", ...) == 0 then
${indent(userFilesLua(userDir).split("\n"), "  ")}
end`;
  }
}
