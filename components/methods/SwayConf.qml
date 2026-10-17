pragma Singleton
import QtQuick

// Sway's config and command text from axiom's settings (SwayManager,
// SwayConfigWriter), as HyprLua/HyprConfigLua are for Hyprland: each bind's
// `bindsym`, the window look and input as sway commands, the included file,
// output commands, and the binds a user's sway config already holds
// (docs/dev/compositor/sway-backend.md). BindActions says what the actions
// are; this says how sway runs them.
QtObject {
  id: root

  // A string as one argument of a sway command, arriving as it is from a
  // config file and at runtime alike: bare when it's plain word
  // characters, else each run without a `"` in double quotes and each `"`
  // in single ones. Sway takes unescaped quotes out but keeps a backslash
  // before one, so escaping a quote can't work.
  function quote(text) {
    const value = String(text ?? "");
    if (/^[A-Za-z0-9_.:+\-\/@~=*]+$/.test(value))
      return value;
    return value.split("\"").map(part => part === "" ? "" : `"${part}"`).join("'\"'") || "\"\"";
  }

  // A command as a bind's command: in a config file sway keeps it as
  // written but unescapes it (so backslashes are doubled, and a line break
  // or tab written as one); at runtime it splits a command list at `;` and
  // `,` and takes quotes out before the bind sees it, so a command holding
  // any is quoted whole
  function bindCommand(command, runtime) {
    if (!runtime)
      return command.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/\t/g, "\\t").replace(/\r/g, "\\r");
    return /[;,"']/.test(command) ? quote(command) : command;
  }

  // --- Keys ---

  // axiom's modifier names (KeyNames) as sway's
  readonly property var _modNames: ({
      "SUPER": "Mod4",
      "CTRL": "Ctrl",
      "ALT": "Mod1",
      "SHIFT": "Shift",
      "CAPS": "Lock",
      "MOD2": "Mod2",
      "MOD3": "Mod3",
      "MOD5": "Mod5"
    })

  // axiom's mouse keys (Hyprland's names) as sway's
  readonly property var _mouseNames: ({
      "mouse:272": "BTN_LEFT",
      "mouse:273": "BTN_RIGHT",
      "mouse:274": "BTN_MIDDLE",
      "mouse:275": "BTN_SIDE",
      "mouse:276": "BTN_EXTRA",
      "mouse_up": "button4",
      "mouse_down": "button5",
      "mouse_left": "button6",
      "mouse_right": "button7"
    })

  /**
   * A combo ("SUPER + SHIFT + Q") as sway binds it: { command: "bindsym" |
   * "bindcode", spec: "Mod4+Shift+q", mouse }, or null when a modifier or
   * the key can't be written. A letter is lower case (sway matches keysyms
   * so); `code:N` is a bindcode, mouse buttons and the wheel bind over the
   * whole window.
   */
  function key(combo) {
    const parts = KeyNames.split(combo);
    if (parts.key === "")
      return null;
    const mods = parts.mods.map(mod => root._modNames[mod]);
    if (mods.some(mod => mod === undefined))
      return null;
    const code = /^code:(\d+)$/.exec(parts.key);
    const mouse = root._mouseNames[parts.key.toLowerCase()];
    if (/^mouse:/.test(parts.key) && mouse === undefined)
      return null;
    const name = code ? code[1] : mouse ?? (parts.key.length === 1 ? parts.key.toLowerCase() : parts.key);
    return {
      "command": code ? "bindcode" : "bindsym",
      "spec": mods.concat([name]).join("+"),
      "mouse": mouse !== undefined
    };
  }

  // --- Binds ---

  // An `exec` of `text`, quoted when sway would otherwise split it into
  // several commands or take its own quotes out of it (sway's parser drops
  // quotes, then the shell sees a path with spaces as several words)
  function _exec(text) {
    return "exec " + (/[;,"'\\]/.test(text) ? quote(text) : text);
  }

  // A single-quoted shell word
  function shellWord(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
  }

  // The sway command of a compositor action (BindActions.compositorActions)
  // for `argument`, or "" when sway can't do it or the argument doesn't
  // fit. `ctx`: { shellCommand, terminal, fileManager, browser }
  function actionCommand(action, argument, ctx) {
    const directions = ["left", "right", "up", "down"];
    switch (action) {
    case "focusDir":
      return directions.includes(argument) ? "focus " + argument : "";
    case "moveWindowDir":
      return directions.includes(argument) ? "move " + argument : "";
    case "resizeWindow":
      {
        const [x, y] = argument.split(/[\s,]+/).map(Number);
        if (!isFinite(x) || !isFinite(y))
          return "";
        const parts = [];
        if (x !== 0)
          parts.push(`resize ${x > 0 ? "grow" : "shrink"} width ${Math.abs(x)} px`);
        if (y !== 0)
          parts.push(`resize ${y > 0 ? "grow" : "shrink"} height ${Math.abs(y)} px`);
        // Comma: one command list on the same (focused) window
        return parts.join(", ");
      }
    case "closeWindow":
      return "kill";
    case "fullscreen":
      return "fullscreen toggle";
    case "toggleFloat":
      return "floating toggle";
    case "pin":
      return "sticky toggle";
    case "centerWindow":
      return "move position center";
    case "toggleSplit":
      return "layout toggle split";
    // Sway's own command, as the user wrote it
    case "raw":
      return argument;
    // axiom's own binds: SwayManager reads them from sway's binding events
    case "windowSwitcher":
    case "windowSwitcherReverse":
      return `nop axiom switcher step ${BindActions.switcherSteps[action]}`;
    case "toggleSpecial":
      return /^\S+$/.test(argument) ? "nop axiom special toggle " + argument : "";
    case "moveToSpecial":
      return /^\S+$/.test(argument) ? "nop axiom special move " + argument : "";
    // Run by sway, not over IPC, so it works when the shell is stuck
    case "restartShell":
      return _exec(`qs kill ${ctx.shellCommand.slice(3)}; ${ctx.shellCommand} -d`);
    case "exitSession":
      return "exit";
    case "terminal":
      return _exec(ctx.terminal);
    case "fileManager":
      return _exec(ctx.fileManager);
    case "browser":
      return _exec(ctx.browser);
    }
    // Strips, pseudotiling, groups; the mouse drag and resize, which are
    // sway's floating_modifier (floatingModifier)
    return "";
  }

  // A configured bind's command, or "" when it's incomplete or sway can't
  // run it (raw binds written for another compositor)
  function command(bind, ctx) {
    const argument = String(bind.argument ?? "").trim();
    if (!String(bind.key ?? "").trim() || (BindActions.needsArgument(bind.action) && !argument))
      return "";
    if (bind.action === "raw" && (bind.compositor ?? "hyprland") !== "sway")
      return "";
    if (BindActions.compositorActions[bind.action])
      return actionCommand(bind.action, argument, ctx);
    if (bind.action === "exec")
      return _exec(argument);
    if (BindActions.ipcActions[bind.action]) {
      const ipc = BindActions.ipcActions[bind.action][0].replace("{call}", BindActions.callFunction(bind)).replace("{0}", shellWord(argument));
      return _exec(`${ctx.shellCommand} ipc call ${ipc}`);
    }
    return "";
  }

  // The `bindsym` (or `bindcode`) line for a configured bind, or "", for a
  // config file or, with `runtime`, to send now (bindCommand). Sway repeats
  // a held bind unless told not to; Hyprland doesn't, so a bind repeats
  // only with its `repeating` flag.
  function bindLine(bind, ctx, runtime) {
    const cmd = command(bind, ctx);
    const k = key(bind.key);
    if (cmd === "" || !k)
      return "";
    const flags = ["--no-warn"].concat(_conflictFlags(bind, k));
    if (!bind.repeating)
      flags.push("--no-repeat");
    return `${k.command} ${flags.join(" ")} ${k.spec} ${bindCommand(cmd, runtime === true)}`;
  }

  // The flags that are part of a bind's identity to sway: unbinding takes
  // them too, or it misses the bind
  function _conflictFlags(bind, k) {
    const flags = [];
    if (k.mouse)
      flags.push("--whole-window");
    if (bind.locked)
      flags.push("--locked");
    if (bind.release)
      flags.push("--release");
    return flags;
  }

  // Whether sway can bind it (and so whether the writer counts it complete):
  // a line, or for a mouse drag or resize what sway's floating modifier can
  // be (_floating)
  function isComplete(bind, ctx) {
    if (bind.action === "mouseDrag" || bind.action === "mouseResize")
      return _floating(bind) !== null;
    return bindLine(bind, ctx) !== "";
  }

  // A mouse drag or resize bind as sway's floating modifier: { mod,
  // inverse }, or null when sway can't do it. Sway has one modifier, held
  // with the left or right button: `normal` drags with the left and
  // resizes with the right, `inverse` the other way round.
  function _floating(bind) {
    const parts = KeyNames.split(bind?.key ?? "");
    const mod = parts.mods.length === 1 ? root._modNames[parts.mods[0]] : undefined;
    if (!mod || (parts.key !== "mouse:272" && parts.key !== "mouse:273"))
      return null;
    const right = parts.key === "mouse:273";
    return {
      "mod": mod,
      "inverse": bind.action === "mouseDrag" ? right : !right
    };
  }

  /**
   * Sway's floating_modifier for the mouse drag and resize binds: the drag
   * bind's (else the resize bind's) modifier and buttons. "" with neither.
   * A resize bind on another modifier, or on the same button as the drag,
   * can't be had too: sway has one modifier for both.
   */
  function floatingModifier(binds) {
    const mouse = (binds ?? []).filter(bind => (bind.action === "mouseDrag" || bind.action === "mouseResize") && _floating(bind) !== null);
    const first = mouse.find(bind => bind.action === "mouseDrag") ?? mouse[0];
    if (!first)
      return "";
    const f = _floating(first);
    return `floating_modifier ${f.mod} ${f.inverse ? "inverse" : "normal"}`;
  }

  // Every complete bind's line (for a file, or with `runtime` to send now),
  // then the floating modifier
  function bindLines(binds, ctx, runtime) {
    const lines = (binds ?? []).map(bind => bindLine(bind, ctx, runtime)).filter(line => line !== "");
    const floating = floatingModifier(binds);
    return floating !== "" ? lines.concat([floating]) : lines;
  }

  // axiom's complete binds as BindKeys' entries (as configBinds reads a
  // config's), described as the Keybinds page labels them
  function bindEntries(binds, ctx) {
    return (binds ?? []).filter(bind => isComplete(bind, ctx)).map(bind => {
      const k = key(bind.key);
      return _entry(k.command, k.spec, BindActions.descriptionFor(bind), "");
    }).filter(entry => entry !== null);
  }

  // The commands taking `binds`' lines back out (as bindLines bound them)
  function unbindLines(binds, ctx) {
    return (binds ?? []).map(bind => {
      const k = key(bind.key);
      return k && bindLine(bind, ctx) !== "" ? [`un${k.command}`].concat(_conflictFlags(bind, k), [k.spec]).join(" ") : "";
    }).filter(line => line !== "");
  }

  // --- The window look and the input ---

  // "rrggbb" as sway's "#rrggbb"
  function _color(hex) {
    return "#" + String(hex ?? "").replace(/^#/, "");
  }

  // Black or white, whichever reads on a title bar of `hex`
  function textOn(hex) {
    const v = String(hex ?? "").replace(/^#/, "");
    const [r, g, b] = [0, 2, 4].map(i => parseInt(v.slice(i, i + 2), 16) / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5 ? "#000000" : "#ffffff";
  }

  /**
   * The look's parts that are on (CompositorLayer.look) as sway commands:
   * borders (the client colors), shape (border width; sway has no rounded
   * corners) and gaps. `live`: for evaluating now, so what's open changes
   * too, not only what opens next.
   */
  function lookLines(look, live) {
    const lines = [];
    if (look?.borders) {
      const on = _color(look.borders.active);
      const off = _color(look.borders.inactive);
      lines.push(`client.focused ${on} ${on} ${textOn(on)} ${on} ${on}`);
      lines.push(`client.focused_inactive ${off} ${off} ${textOn(off)} ${off} ${off}`);
      lines.push(`client.unfocused ${off} ${off} ${textOn(off)} ${off} ${off}`);
    }
    if (look?.shape) {
      const width = Math.max(0, Math.round(look.shape.width));
      lines.push(`default_border pixel ${width}`, `default_floating_border pixel ${width}`);
      if (live)
        lines.push(`[all] border pixel ${width}`);
    }
    if (look?.gaps) {
      lines.push(`gaps inner ${look.gaps.inner}`, `gaps outer ${look.gaps.outer}`);
      if (live)
        lines.push(`gaps inner all set ${look.gaps.inner}`, `gaps outer all set ${look.gaps.outer}`);
    }
    return lines;
  }

  /**
   * SwayFX's part of the look (CompositorLayer.look) and the blur behind
   * axiom's surfaces (`surfaces`: { blur, throughWindows, backdrops }), as
   * commands to send now: never written into a file, which plain sway would
   * refuse. Each sets a compositor global, so a part off sends nothing,
   * and a reload takes it back. Whether a window blurs, casts a shadow and
   * its dim are each window's own: SwayManager sets those a window at a
   * time (SwayState.windowCommands), as `blur`/`shadows` sent here would
   * reach only the focused one.
   *   shape    corner_radius (windows opened from now on: SwayFX has no
   *            way to change an open window's at runtime)
   *   blur     blur_radius (≤ 10), blur_passes, blur_xray, blur_noise,
   *            blur_contrast
   *   shadow   shadow_blur_radius, shadow_offset, shadow_color (and
   *            inactive); one matching axiom's as
   *            CompositorLayer.gaussianShadow fits it
   *   dim      default_dim_inactive
   * and per axiom layer (LayerStack.blurSurfaces, blurBackdrops,
   * blurOverOverlay) its layer_effects, on or off, its transparent pixels
   * left out.
   */
  function fxLines(look, surfaces) {
    const lines = [];
    const clamp = (value, low, high) => Math.max(low, Math.min(high, Math.round(Number(value) || 0)));
    const toggle = on => on ? "enable" : "disable";
    if (look?.shape)
      lines.push(`corner_radius ${clamp(look.shape.radius, 0, 99)}`);
    if (look?.blur) {
      const b = look.blur;
      lines.push(`blur_radius ${clamp(b.size, 0, 10)}`, `blur_passes ${clamp(b.passes, 0, 10)}`, `blur_xray ${toggle(b.xray)}`, `blur_noise ${Math.round(b.noise) / 1000}`, `blur_contrast ${Math.round(b.contrast) / 100}`);
    }
    if (look?.shadow) {
      const soft = look.shadow.soft && look.shadow.rgb ? CompositorLayer.gaussianShadow(look.shadow) : null;
      const color = soft ? look.shadow.rgb + CompositorLayer.alphaHex(soft.alpha) : look.shadow.color;
      lines.push(`shadow_blur_radius ${clamp(soft ? soft.radius : look.shadow.size, 0, 100)}`, `shadow_offset 0 ${clamp(look.shadow.offset, -99, 99)}`);
      if (color !== "")
        lines.push(`shadow_color #${color}`, `shadow_inactive_color #${color}`);
    }
    if (look?.dim)
      lines.push(`default_dim_inactive ${clamp(look.dim.strength, 0, 100) / 100}`);
    const layer = (names, on, xray) => names.map(name => `layer_effects ${quote("axiom-" + name)} ${quote(`blur ${toggle(on)}; blur_xray ${toggle(xray)}; blur_ignore_transparent enable`)}`);
    const blur = surfaces?.blur === true;
    const xray = surfaces?.throughWindows !== true;
    return lines.concat(layer(LayerStack.blurSurfaces, blur, xray), layer(LayerStack.blurBackdrops, blur && surfaces?.backdrops === true, xray), layer(LayerStack.blurOverOverlay, blur, false));
  }

  // A field's value as its x-sway command takes it, or null to leave it
  function _swayValue(fieldSchema, value) {
    if (fieldSchema["x-swaySkip"] !== undefined && value === fieldSchema["x-swaySkip"])
      return null;
    if (fieldSchema["x-swayMap"] !== undefined)
      return fieldSchema["x-swayMap"][String(value)] ?? null;
    switch (fieldSchema["x-swayValue"]) {
    case "enabled":
      return value ? "enabled" : "disabled";
    case "yesNo":
      return value ? "yes" : "no";
    case "enableDisable":
      return value ? "enable" : "disable";
    case "raw":
      return String(value);
    }
    if (fieldSchema["x-swayScale"] !== undefined)
      return String(Math.round(value * fieldSchema["x-swayScale"] * 1000) / 1000);
    return quote(value);
  }

  /**
   * The input (CompositorLayer.input) as sway commands: Input's fields with
   * an `x-sway` command, each written when its x-hyprIf part is on (else
   * once changed from its default), then the cursor theme. `live`: for
   * sending now, leaving out what sway takes only from a config file
   * (x-swayConfigOnly).
   */
  function inputLines(input, inputSchema, live) {
    const lines = [];
    for (const field of CompositorLayer.annotatedFields(inputSchema, input?.values ?? {}, "x-sway", true)) {
      if (live && field.schema["x-swayConfigOnly"])
        continue;
      const value = _swayValue(field.schema, field.value);
      if (value !== null)
        lines.push(field.schema["x-sway"].replace("{}", value));
    }
    if (input?.cursor)
      lines.push(cursorLine(input.cursor.theme, input.cursor.size));
    return lines;
  }

  // A section's options (WindowBehaviour, Sway) as sway commands, every
  // field with an `x-sway` command: a managed config says all of them
  function optionLines(sectionSchema, values) {
    const lines = [];
    for (const field of CompositorLayer.annotatedFields(sectionSchema, values, "x-sway", false)) {
      const value = _swayValue(field.schema, field.value);
      if (value !== null)
        lines.push(field.schema["x-sway"].replace("{}", value));
    }
    return lines;
  }

  function cursorLine(theme, size) {
    return `seat * xcursor_theme ${quote(theme)} ${Math.round(size)}`;
  }

  // --- The included file ---

  // The mode whose presence (get_binding_modes) says axiom's file (the
  // included one, or the managed config) is loaded: only the file defines it
  readonly property string loadedMode: "axiom_layer"

  // The included file. `parts`: { header, includeLines, binds, look, input,
  // outputs } (lines each)
  function moduleText(parts) {
    const section = (title, lines) => lines.length > 0 ? `\n# ${title}\n${lines.join("\n")}\n` : "";
    return `${parts.header} from its settings, and rewritten whenever they (or
# the theme) change: edit those, not this file.
#
# Include it near the top of your sway config, so what follows overrides it:
#   ${parts.includeLines}
# Your own bindsym on one of axiom's keys, after it, wins (sway warns).

# Tells axiom this file is loaded
mode "${loadedMode}" bindsym --no-warn F35 mode default
${section("Binds", parts.binds)}${section("Window borders and gaps", parts.look)}${section("Input", parts.input)}${section("Monitors", parts.outputs ?? [])}`;
  }

  /**
   * The managed sway config: the module's lines (moduleText's, without its
   * comment header), the shared and sway's own options, the session (the
   * environment for what axiom starts, the start of axiom and the autostart
   * commands) and the user's own files after it all. `opts`: { header,
   * userDir, options (lines), env ([{ name, value }]), cursor, start: {
   * command, idle, polkit }, autostart ([{ command, enabled }]), isAgent
   * (command → whether it's a polkit agent) }.
   * Sway has no env command: the environment reaches axiom (and what it
   * starts) through its start line, and D-Bus/systemd activated apps
   * through dbus-update-activation-environment.
   */
  function managedText(module, opts) {
    const body = module.split("\n").filter(line => !line.startsWith("#")).join("\n").trim();
    const env = (opts.env ?? []).map(entry => `${entry.name}=${shellWord(entry.value)}`);
    // Sway unescapes a config line's arguments, exec's too: escaped as a
    // bind's command is, a shell word's '\'' and a backslash arrive whole
    const exec = text => _exec(bindCommand(text, false));
    const start = [];
    if (env.length > 0)
      start.push(exec(`dbus-update-activation-environment --systemd ${env.join(" ")}`));
    start.push(exec((env.length > 0 ? `env ${env.join(" ")} ` : "") + opts.start.command));
    for (const entry of opts.autostart ?? [])
      if (entry.enabled && entry.command.trim() !== "" && !(opts.start.idle && entry.command.trim() === "hypridle") && !(opts.start.polkit && opts.isAgent?.(entry.command)))
        start.push(exec(entry.command.trim()));
    return `${opts.header} (sway mode: managed) from its settings, and
# rewritten whenever they (or the theme) change: edit those, not this file.
# Your own config goes in ${opts.userDir}/, included after this in name
# order, so it overrides it.

${body}

# Windows, focus and sway's own options
${(opts.options ?? []).join("\n")}

# The session
${start.join("\n")}

include ${quote(opts.userDir + "/*")}
`;
  }

  // What a sway config left behind on leaving managed holds when the
  // takeover set nothing aside: it starts axiom (`startLines`) and
  // includes the user's files, as the managed one did
  function releasedText(userDir, startLines) {
    return `# Given back by axiom when it stopped managing sway: this file is yours now,
# and axiom won't write it again. It starts axiom and includes
# ${userDir}/, as axiom's managed one did.
${startLines}

include ${quote(userDir + "/*")}
`;
  }

  // The included file once axiom isn't in that mode: nothing in it
  function emptyModuleText(header) {
    return `${header}. axiom isn't in the "included" mode, so this file is
# empty; its include line can go.
`;
  }

  // --- Outputs ---

  // Sway's output names for Wayland's transforms 0-7
  readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

  // How sway names a monitor rule's output: a description ("desc:Make Model
  // Serial") is sway's own identifier for it, quoted
  function outputName(output) {
    const value = String(output ?? "");
    return quote(value.startsWith("desc:") ? value.slice(5).trim() : value);
  }

  // A monitor rule (the MonitorRule schema) as one `output` command. Sway
  // has no mirroring, color management or SDR settings: those are left out
  // (supports.monitorMirror / monitorColor are off). A "preferred" mode
  // leaves the mode as it is.
  function outputCommand(rule) {
    const name = outputName(rule.output);
    if (rule.disabled)
      return `output ${name} disable`;
    const parts = [`output ${name} enable`];
    const mode = String(rule.mode ?? "");
    if (mode !== "" && mode !== "preferred")
      parts.push("mode " + (/@[\d.]+$/.test(mode) ? mode + "Hz" : mode));
    parts.push(`pos ${Math.round(rule.x ?? 0)} ${Math.round(rule.y ?? 0)}`);
    parts.push(`scale ${rule.scale ?? 1}`);
    parts.push("transform " + (transforms[rule.transform ?? 0] ?? "normal"));
    parts.push("adaptive_sync " + ((rule.vrr ?? 0) > 0 ? "on" : "off"));
    // Always: sent at runtime, leaving it out would keep 10 after 10 is off
    parts.push("render_bit_depth " + (rule.bitdepth === 10 ? 10 : 8));
    return parts.join(" ");
  }

  // Every rule's command, in the order sway should run them (disabled
  // outputs last, so an output isn't turned off before another takes over)
  function outputLines(rules) {
    const sorted = (rules ?? []).filter(rule => !rule.disabled).concat((rules ?? []).filter(rule => rule.disabled));
    return sorted.map(rule => outputCommand(rule));
  }

  // outputLines as one command line, to run now
  function outputCommands(rules) {
    return outputLines(rules).join("; ");
  }

  // The `output` lines of a file axiom wrote (the included module or the
  // managed config, which hold no output lines of the user's)
  function fileOutputLines(text) {
    return String(text ?? "").split("\n").filter(line => line.startsWith("output "));
  }

  // --- A user's sway config ---

  // Sway's modifier names as X11 mask bits (BindKeys' entries)
  readonly property var _modBits: ({
      "shift": 1,
      "lock": 2,
      "control": 4,
      "ctrl": 4,
      "mod1": 8,
      "alt": 8,
      "mod2": 16,
      "mod3": 32,
      "mod4": 64,
      "super": 64,
      "mod5": 128
    })

  // Sway's mouse names as axiom's (Hyprland's)
  readonly property var _mouseKeys: ({
      "button1": "mouse:272",
      "button2": "mouse:274",
      "button3": "mouse:273",
      "button4": "mouse_up",
      "button5": "mouse_down",
      "button6": "mouse_left",
      "button7": "mouse_right",
      "btn_left": "mouse:272",
      "btn_right": "mouse:273",
      "btn_middle": "mouse:274",
      "btn_side": "mouse:275",
      "btn_extra": "mouse:276"
    })

  /**
   * The binds in a sway config's text (SwayConfigWriter reads it with its
   * includes in, scripts/sway_config_text.py), as BindKeys' entries: {
   * modmask, key, keycode, submap ("" outside a mode), description (its
   * command) }. $variables are put in as they're set; line continuations
   * joined; `mode "name" { … }` blocks give their submap. A bind that can't
   * be read (an unknown modifier) is left out.
   */
  function configBinds(text) {
    const vars = {};
    const entries = [];
    const blocks = [];
    const lines = String(text ?? "").replace(/\\\n/g, " ").split("\n");
    const expand = line => Object.keys(vars).sort((a, b) => b.length - a.length).reduce((result, name) => result.split(name).join(vars[name]), line);
    for (const raw of lines) {
      let line = raw.trim();
      if (line === "" || line.startsWith("#"))
        continue;
      if (line === "}") {
        blocks.pop();
        continue;
      }
      const set = /^set\s+(\$\S+)\s+(.*)$/.exec(line);
      if (set) {
        vars[set[1]] = expand(set[2]).trim();
        continue;
      }
      line = expand(line);
      if (line.endsWith("{")) {
        const mode = /^mode\s+(?:--pango_markup\s+)?("?)(.+?)\1\s*\{$/.exec(line);
        blocks.push(mode ? mode[2] : "");
        continue;
      }
      const inline = /^mode\s+(?:--pango_markup\s+)?("([^"]+)"|(\S+))\s+((?:bindsym|bindcode)\s.*)$/.exec(line);
      const submap = inline ? (inline[2] ?? inline[3]) : blocks.filter(name => name !== "").pop() ?? "";
      const bind = /^(bindsym|bindcode)\s+(.*)$/.exec(inline ? inline[4] : line);
      if (!bind)
        continue;
      const words = bind[2].split(/\s+/);
      while (words.length > 0 && words[0].startsWith("--"))
        words.shift();
      const combo = words.shift() ?? "";
      const entry = _entry(bind[1], combo, words.join(" "), submap);
      if (entry)
        entries.push(entry);
    }
    return entries;
  }

  function _entry(kind, combo, command, submap) {
    const parts = combo.split("+").filter(part => part !== "");
    if (parts.length === 0)
      return null;
    let mask = 0;
    for (const mod of parts.slice(0, -1)) {
      const bit = root._modBits[mod.toLowerCase()];
      if (bit === undefined)
        return null;
      mask |= bit;
    }
    const last = parts[parts.length - 1];
    const isCode = kind === "bindcode";
    return {
      "modmask": mask,
      "key": isCode ? "" : root._mouseKeys[last.toLowerCase()] ?? last,
      "keycode": isCode ? Number(last) : 0,
      "submap": submap,
      "description": command
    };
  }
}
