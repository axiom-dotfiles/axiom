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

  // A string as one argument of a sway command: quoted when it holds
  // anything but plain word characters
  function quote(text) {
    const value = String(text ?? "");
    return /^[A-Za-z0-9_.:+\-\/@~=]+$/.test(value) ? value : `"${value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
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
    return "exec " + (/[;,"']/.test(text) ? quote(text) : text);
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

  // The `bindsym` (or `bindcode`) line for a configured bind, or "". Sway
  // repeats a held bind unless told not to; Hyprland doesn't, so a bind
  // repeats only with its `repeating` flag.
  function bindLine(bind, ctx) {
    const cmd = command(bind, ctx);
    const k = key(bind.key);
    if (cmd === "" || !k)
      return "";
    const flags = ["--no-warn"];
    if (k.mouse)
      flags.push("--whole-window");
    if (bind.locked)
      flags.push("--locked");
    if (bind.release)
      flags.push("--release");
    if (!bind.repeating)
      flags.push("--no-repeat");
    return `${k.command} ${flags.join(" ")} ${k.spec} ${cmd}`;
  }

  // Whether sway can bind it (and so whether the writer counts it complete):
  // a line, or the floating modifier for a mouse drag or resize
  function isComplete(bind, ctx) {
    if (bind.action === "mouseDrag" || bind.action === "mouseResize")
      return key(bind.key) !== null;
    return bindLine(bind, ctx) !== "";
  }

  /**
   * Sway's floating_modifier for the mouse drag and resize binds: the
   * modifier of the drag bind, `normal` when it drags with the left button
   * (and resizes with the right), `inverse` the other way round. "" with no
   * drag bind; sway has one modifier for both.
   */
  function floatingModifier(binds) {
    const drag = (binds ?? []).find(bind => bind.action === "mouseDrag" && key(bind.key) !== null);
    if (!drag)
      return "";
    const parts = KeyNames.split(drag.key);
    const mod = root._modNames[parts.mods[0]];
    return mod ? `floating_modifier ${mod} ${parts.key === "mouse:273" ? "inverse" : "normal"}` : "";
  }

  // Every complete bind's line, then the floating modifier
  function bindLines(binds, ctx) {
    const lines = (binds ?? []).map(bind => bindLine(bind, ctx)).filter(line => line !== "");
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
      return k && bindLine(bind, ctx) !== "" ? `un${k.command} ${k.spec}` : "";
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

  // A field's value as its x-sway command takes it, or null to leave it
  function _swayValue(fieldSchema, value) {
    if (fieldSchema["x-swaySkip"] !== undefined && value === fieldSchema["x-swaySkip"])
      return null;
    if (fieldSchema["x-swayValue"] === "enabled")
      return value ? "enabled" : "disabled";
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
    const props = inputSchema?.properties ?? {};
    const values = input?.values ?? {};
    for (const name in props) {
      const fieldSchema = props[name];
      const template = fieldSchema["x-sway"];
      if (!template || values[name] === undefined || (live && fieldSchema["x-swayConfigOnly"]))
        continue;
      const condition = fieldSchema["x-hyprIf"];
      if (condition ? !values[condition] : values[name] === fieldSchema.default)
        continue;
      const value = _swayValue(fieldSchema, values[name]);
      if (value !== null)
        lines.push(template.replace("{}", value));
    }
    if (input?.cursor)
      lines.push(cursorLine(input.cursor.theme, input.cursor.size));
    return lines;
  }

  function cursorLine(theme, size) {
    return `seat * xcursor_theme ${quote(theme)} ${Math.round(size)}`;
  }

  // --- The included file ---

  // The mode whose presence (get_binding_modes) says the file is loaded:
  // only the file defines it
  readonly property string includedMode: "axiom_included"

  // The included file. `parts`: { header, includeLines, binds, look, input }
  // (lines each)
  function moduleText(parts) {
    const section = (title, lines) => lines.length > 0 ? `\n# ${title}\n${lines.join("\n")}\n` : "";
    return `${parts.header} from its settings, and rewritten whenever they (or
# the theme) change: edit those, not this file.
#
# Include it near the top of your sway config, so what follows overrides it:
#   ${parts.includeLines}
# Your own bindsym on one of axiom's keys, after it, wins (sway warns).

# Tells axiom this file is loaded
mode "${includedMode}" bindsym --no-warn F35 mode default
${section("Binds", parts.binds)}${section("Window borders and gaps", parts.look)}${section("Input", parts.input)}`;
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
    if (rule.bitdepth === 10)
      parts.push("render_bit_depth 10");
    return parts.join(" ");
  }

  // Every rule's command, as one command line sway runs in order (disabled
  // outputs last, so an output isn't turned off before another takes over)
  function outputCommands(rules) {
    const sorted = (rules ?? []).filter(rule => !rule.disabled).concat((rules ?? []).filter(rule => rule.disabled));
    return sorted.map(rule => outputCommand(rule)).join("; ");
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
