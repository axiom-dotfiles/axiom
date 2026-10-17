pragma Singleton
import QtQuick

// niri's config text (KDL) and IPC requests from axiom's settings
// (NiriManager, NiriConfigWriter), as SwayConf is for sway: each bind's
// node, the window look, input and options, outputs, and the files axiom
// writes (docs/dev/compositor/niri-backend.md). BindActions says what the
// actions are; this says how niri runs them.
//
// Text is built as nodes ({ name, args, props, children }, or { raw } for
// text as the user wrote it) and written out last, so a section is only
// ever written once per file: niri refuses a file with two `layout` or
// `binds` nodes, or a key bound twice in one.
QtObject {
  id: root

  // --- KDL ---

  // A node; `children` an array for a block, else null
  function node(name, args, props, children) {
    return {
      "name": name,
      "args": args ?? [],
      "props": props ?? ({}),
      "children": children ?? null
    };
  }

  // A string as a KDL string
  function kdlString(text) {
    return "\"" + String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + "\"";
  }

  // A number niri reads as a float, written with a point (niri refuses
  // `opacity 1` where it wants `1.0`)
  function real(value) {
    return {
      "real": Number(value)
    };
  }

  function kdlValue(value) {
    if (value !== null && typeof value === "object" && "real" in value) {
      const rounded = Math.round(value.real * 1000) / 1000;
      return Number.isInteger(rounded) ? rounded.toFixed(1) : String(rounded);
    }
    if (typeof value === "boolean")
      return value ? "true" : "false";
    if (typeof value === "number")
      return String(Math.round(value * 1000) / 1000);
    return kdlString(value);
  }

  // A node's name as KDL takes it: bare when it can be (a key combo, an
  // action), else quoted
  function _name(name) {
    return /^[A-Za-z_][A-Za-z0-9_+\-.]*$/.test(name) ? name : kdlString(name);
  }

  // Nodes as KDL text, `depth` levels in
  function serialize(nodes, depth) {
    const pad = "    ".repeat(depth ?? 0);
    return (nodes ?? []).map(n => {
      if (n.raw !== undefined)
        return pad + n.raw;
      const head = [_name(n.name)].concat(n.args.map(arg => kdlValue(arg)), Object.keys(n.props).map(key => `${key}=${kdlValue(n.props[key])}`)).join(" ");
      if (n.children === null)
        return pad + head;
      return n.children.length === 0 ? `${pad}${head} {}` : `${pad}${head} {\n${serialize(n.children, (depth ?? 0) + 1)}\n${pad}}`;
    }).join("\n");
  }

  // Sets the node at dotted `path` ("input.keyboard.xkb.layout") in
  // `nodes` (an array, changed in place) to `args` (and `props`), making
  // the sections on the way: a leaf already there is replaced
  function setPath(nodes, path, args, props) {
    const names = path.split(".");
    let level = nodes;
    for (const name of names.slice(0, -1)) {
      let section = level.find(n => n.name === name && n.children !== null);
      if (!section) {
        section = node(name, [], {}, []);
        level.push(section);
      }
      level = section.children;
    }
    const leaf = names[names.length - 1];
    const at = level.findIndex(n => n.name === leaf);
    const made = node(leaf, args, props);
    if (at >= 0)
      level[at] = made;
    else
      level.push(made);
  }

  // `nodes` with sections of the same name joined, in place of the first
  // (nodes that may repeat, like window-rule or output, stay apart)
  function merged(nodes) {
    const repeating = ["window-rule", "layer-rule", "output", "spawn-at-startup", "spawn-sh-at-startup", "workspace", "include"];
    const out = [];
    for (const n of nodes ?? []) {
      const same = n.children !== null && !repeating.includes(n.name) ? out.find(o => o.name === n.name && o.children !== null) : null;
      if (!same) {
        out.push(n.children !== null ? node(n.name, n.args, n.props, n.children.slice()) : n);
        continue;
      }
      for (const child of n.children) {
        const at = same.children.findIndex(c => c.name === child.name);
        if (at >= 0 && child.children !== null && same.children[at].children !== null)
          same.children[at] = merged([same.children[at], child])[0];
        else if (at >= 0)
          same.children[at] = child;
        else
          same.children.push(child);
      }
    }
    return out;
  }

  // --- Keys ---

  // axiom's modifier names (KeyNames) as niri's; CAPS, MOD2 and MOD3 have
  // none
  readonly property var _modNames: ({
      "SUPER": "Super",
      "CTRL": "Ctrl",
      "ALT": "Alt",
      "SHIFT": "Shift",
      "MOD5": "ISO_Level3_Shift"
    })

  // axiom's mouse keys (Hyprland's names) as niri's
  readonly property var _mouseNames: ({
      "mouse:272": "MouseLeft",
      "mouse:273": "MouseRight",
      "mouse:274": "MouseMiddle",
      "mouse:275": "MouseBack",
      "mouse:276": "MouseForward",
      "mouse_up": "WheelScrollUp",
      "mouse_down": "WheelScrollDown",
      "mouse_left": "WheelScrollLeft",
      "mouse_right": "WheelScrollRight"
    })

  /**
   * A combo ("SUPER + SHIFT + Q") as niri binds it ("Super+Shift+Q"), or
   * null when niri can't bind it: a modifier niri doesn't have, a keycode
   * (`code:N`) or a mouse button it doesn't name. Always Super, never Mod,
   * which is Alt while niri runs nested.
   */
  function key(combo) {
    const parts = KeyNames.split(combo);
    if (parts.key === "" || /^code:/.test(parts.key))
      return null;
    const mods = parts.mods.map(mod => root._modNames[mod]);
    if (mods.some(mod => mod === undefined))
      return null;
    const mouse = root._mouseNames[parts.key.toLowerCase()];
    if (/^mouse/.test(parts.key) && mouse === undefined)
      return null;
    return mods.concat([mouse ?? parts.key]).join("+");
  }

  function _wheel(combo) {
    return /^mouse_(up|down|left|right)$/.test(KeyNames.split(combo).key);
  }

  // --- Binds ---

  /**
   * The niri action (a node) of a compositor action (BindActions.
   * compositorActions) for `argument`, or null when niri can't do it or
   * the argument doesn't fit. `ctx`: { axiomPath, shellCommand, terminal,
   * fileManager, browser }
   */
  function actionNode(action, argument, ctx) {
    const sides = {
      "left": "column-or-monitor-left",
      "right": "column-or-monitor-right",
      "up": "window-or-monitor-up",
      "down": "window-or-monitor-down"
    };
    switch (action) {
    case "focusDir":
      return sides[argument] ? node("focus-" + sides[argument]) : null;
    case "moveWindowDir":
      return {
        "left": node("move-column-left-or-to-monitor-left"),
        "right": node("move-column-right-or-to-monitor-right"),
        "up": node("move-window-up"),
        "down": node("move-window-down")
      }[argument] ?? null;
    case "resizeWindow":
      {
        // One action a bind: across or along, not both
        const [x, y] = argument.split(/[\s,]+/).map(Number);
        if (!isFinite(x) || !isFinite(y) || (x !== 0) === (y !== 0))
          return null;
        const change = value => (value > 0 ? "+" : "") + value;
        return x !== 0 ? node("set-column-width", [change(x)]) : node("set-window-height", [change(y)]);
      }
    case "closeWindow":
      return node("close-window");
    case "fullscreen":
      return node("fullscreen-window");
    case "toggleFloat":
      return node("toggle-window-floating");
    case "centerWindow":
      return node("center-window");
    // A column's windows as tabs: niri's group
    case "toggleGroup":
      return node("toggle-column-tabbed-display");
    case "stripSwapColumn":
      return node(argument === "left" || argument === "up" ? "move-column-left" : "move-column-right");
    case "stripWider":
      return node("set-column-width", ["+10%"]);
    case "stripNarrower":
      return node("set-column-width", ["-10%"]);
    case "stripFit":
      return node("expand-column-to-available-width");
    // niri's own action, as the user wrote it
    case "raw":
      return {
        "raw": argument
      };
    // niri's binds can't tell axiom anything but through its IPC; the
    // modifier's release is SwitcherKeys'
    case "windowSwitcher":
    case "windowSwitcherReverse":
      return _ipc(ctx, ["windowSwitcher", BindActions.switcherSteps[action] > 0 ? "next" : "previous"]);
    // Run by niri, not over IPC, so it works when the shell is stuck
    case "restartShell":
      return node("spawn-sh", [`qs kill ${ctx.shellCommand.slice(3)}; ${ctx.shellCommand} -d`]);
    case "exitSession":
      return node("quit", [], {
        "skip-confirmation": true
      });
    case "terminal":
      return node("spawn-sh", [ctx.terminal]);
    case "fileManager":
      return node("spawn-sh", [ctx.fileManager]);
    case "browser":
      return node("spawn-sh", [ctx.browser]);
    }
    // Pinning, pseudotiling, splits, special workspaces; the mouse drag and
    // resize, which niri's own Mod + drag does
    return null;
  }

  // An axiom IPC call (`words`) spawned as niri runs it: argv, no shell
  function _ipc(ctx, words) {
    return node("spawn", ["qs", "-p", ctx.axiomPath, "ipc", "call"].concat(words));
  }

  // A configured bind's action node, or null when it's incomplete or niri
  // can't run it (raw binds written for another compositor)
  function actionFor(bind, ctx) {
    const argument = String(bind.argument ?? "").trim();
    if (!String(bind.key ?? "").trim() || (BindActions.needsArgument(bind.action) && !argument))
      return null;
    if (bind.action === "raw" && (bind.compositor ?? "hyprland") !== "niri")
      return null;
    if (BindActions.compositorActions[bind.action])
      return actionNode(bind.action, argument, ctx);
    if (bind.action === "exec")
      return node("spawn-sh", [argument]);
    if (BindActions.ipcActions[bind.action]) {
      const words = BindActions.ipcActions[bind.action][0].replace("{call}", BindActions.callFunction(bind)).split(" ").map(word => word === "{0}" ? argument : word);
      return _ipc(ctx, words);
    }
    return null;
  }

  /**
   * A configured bind as a node of niri's `binds`, or null. niri repeats a
   * held bind unless told not to, Hyprland doesn't: a bind repeats only
   * with its `repeating` flag. A wheel bind waits between steps, as one
   * notch can send several. niri has no release binds (`release` is left).
   */
  function bindNode(bind, ctx) {
    const action = actionFor(bind, ctx);
    const k = key(bind.key);
    if (!action || !k)
      return null;
    const props = {
      "hotkey-overlay-title": BindActions.descriptionFor(bind)
    };
    if (!bind.repeating)
      props["repeat"] = false;
    if (bind.locked)
      props["allow-when-locked"] = true;
    if (_wheel(bind.key))
      props["cooldown-ms"] = 150;
    return node(k, [], props, [action]);
  }

  // Whether niri can bind it (and so whether the writer counts it complete)
  function isComplete(bind, ctx) {
    return bindNode(bind, ctx) !== null;
  }

  // The `binds` section of every complete bind (null with none), each key
  // once: niri refuses a block binding one twice (compared without case)
  function bindsNode(binds, ctx) {
    const seen = {};
    const children = [];
    for (const bind of binds ?? []) {
      const n = bindNode(bind, ctx);
      if (!n || seen[n.name.toLowerCase()])
        continue;
      seen[n.name.toLowerCase()] = true;
      children.push(n);
    }
    return children.length > 0 ? node("binds", [], {}, children) : null;
  }

  // axiom's complete binds as BindKeys' entries, described as the
  // Keybinds page labels them
  function bindEntries(binds, ctx) {
    return (binds ?? []).filter(bind => isComplete(bind, ctx)).map(bind => {
      // keyId is "<modmask>:<key>"
      const id = BindKeys.keyId(bind.key);
      const at = id.indexOf(":");
      return {
        "modmask": Number(id.slice(0, at)),
        "key": id.slice(at + 1),
        "keycode": 0,
        "submap": "",
        "description": BindActions.descriptionFor(bind)
      };
    });
  }

  // --- The window look ---

  function _color(hex) {
    return "#" + String(hex ?? "").replace(/^#/, "");
  }

  /**
   * The look's parts that are on (CompositorLayer.look) as niri's nodes:
   *   borders  the border's and the focus ring's colors
   *   shape    a border of its width instead of the focus ring, and every
   *            window's corners rounded (and cut to them)
   *   gaps     gaps between windows, struts making the edges' outer
   *   blur     each window's background blurred (look.blur.windows), and
   *            niri's blur strength
   *   shadow   niri's shadow, one matching axiom's as
   *            CompositorLayer.gaussianShadow fits it
   *   opacity  focused and unfocused windows' (niri has no fullscreen
   *            matcher)
   * niri can't dim unfocused windows. A part off writes nothing, leaving
   * niri's own (or the user's config's).
   */
  function lookNodes(look) {
    const nodes = [];
    const layout = (path, args) => setPath(nodes, "layout." + path, args ?? []);
    if (look?.borders) {
      for (const part of ["border", "focus-ring"]) {
        layout(part + ".active-color", [_color(look.borders.active)]);
        layout(part + ".inactive-color", [_color(look.borders.inactive)]);
      }
    }
    if (look?.shape) {
      const width = Math.max(0, Math.round(look.shape.width));
      layout("focus-ring.off");
      if (width > 0) {
        layout("border.on");
        layout("border.width", [width]);
      } else {
        layout("border.off");
      }
      nodes.push(node("window-rule", [], {}, [node("geometry-corner-radius", [Math.max(0, Math.round(look.shape.radius))]), node("clip-to-geometry", [true])]));
    }
    if (look?.gaps) {
      const inner = Math.max(0, Math.round(look.gaps.inner));
      const edge = Math.max(0, Math.round(look.gaps.outer) - inner);
      layout("gaps", [inner]);
      for (const side of ["left", "right", "top", "bottom"])
        layout("struts." + side, [edge]);
    }
    if (look?.blur) {
      const b = look.blur;
      setPath(nodes, "blur.passes", [Math.max(1, Math.round(b.passes))]);
      setPath(nodes, "blur.offset", [Math.max(0, Math.round(b.size))]);
      setPath(nodes, "blur.noise", [real(Math.max(0, b.noise) / 1000)]);
      if (b.windows)
        nodes.push(node("window-rule", [], {}, [node("background-effect", [], {}, [node("blur", [true]), node("xray", [b.xray === true])])]));
    }
    if (look?.shadow) {
      const s = look.shadow;
      const soft = s.soft && s.rgb ? CompositorLayer.gaussianShadow(s) : null;
      const color = soft ? s.rgb + CompositorLayer.alphaHex(soft.alpha) : s.color;
      layout("shadow.on");
      layout("shadow.softness", [Math.max(0, Math.round(soft ? soft.radius : s.size))]);
      setPath(nodes, "layout.shadow.offset", [], {
        "x": 0,
        "y": Math.round(s.offset)
      });
      if (color !== "") {
        layout("shadow.color", ["#" + color]);
        layout("shadow.inactive-color", ["#" + color]);
      }
    }
    if (look?.opacity) {
      for (const focused of [true, false])
        nodes.push(node("window-rule", [], {}, [node("match", [], {
            "is-focused": focused
          }), node("opacity", [real(Math.max(0, Math.min(100, focused ? look.opacity.active : look.opacity.inactive)) / 100)])]));
    }
    return nodes;
  }

  // --- Input and options ---

  // A field's value as its x-niri node takes it ([args]), or null to leave
  // it out (a flag that's off: niri can only turn a flag on; an offFlag
  // is a flag written when the setting is off, like `animations { off }`)
  function _niriArgs(fieldSchema, value) {
    if (fieldSchema["x-niriSkip"] !== undefined && value === fieldSchema["x-niriSkip"])
      return null;
    if (fieldSchema["x-niriMap"] !== undefined) {
      const mapped = fieldSchema["x-niriMap"][String(value)];
      return mapped === undefined || mapped === null ? null : [mapped];
    }
    if (fieldSchema["x-niriValue"] === "flag")
      return value ? [] : null;
    if (fieldSchema["x-niriValue"] === "offFlag")
      return value ? null : [];
    const scaled = fieldSchema["x-niriScale"] !== undefined ? Math.round(value * fieldSchema["x-niriScale"] * 1000) / 1000 : value;
    return [fieldSchema["x-niriValue"] === "float" ? real(scaled) : scaled];
  }

  /**
   * A section's fields with an `x-niri` path as nodes: every one of them
   * (`gated` false: a managed config says them all), or with `gated` each
   * written when its x-hyprIf part is on, else once changed from its
   * default (CompositorLayer.annotatedFields).
   */
  function optionNodes(sectionSchema, values, gated) {
    const nodes = [];
    for (const field of CompositorLayer.annotatedFields(sectionSchema, values, "x-niri", gated)) {
      const args = _niriArgs(field.schema, field.value);
      if (args !== null)
        setPath(nodes, field.schema["x-niri"], args);
    }
    return nodes;
  }

  // The input (CompositorLayer.input) as nodes: Input's fields by their
  // x-niri path, then the cursor theme
  function inputNodes(input, inputSchema) {
    const nodes = optionNodes(inputSchema, input?.values ?? {}, true);
    if (input?.cursor) {
      setPath(nodes, "cursor.xcursor-theme", [input.cursor.theme]);
      setPath(nodes, "cursor.xcursor-size", [Math.round(input.cursor.size)]);
    }
    return nodes;
  }

  // --- Outputs ---

  // niri's config names for Wayland's transforms 0-7
  readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
  // ...and its IPC's (NiriState.transforms)
  readonly property var ipcTransforms: ["Normal", "_90", "_180", "_270", "Flipped", "Flipped90", "Flipped180", "Flipped270"]

  // The connector a monitor rule's `output` names (a "desc:Make Model
  // Serial" is looked up in `details`, CompositorManager.withOutputDetails),
  // or "" when none is connected
  function connectorFor(output, details) {
    const value = String(output ?? "");
    if (!value.startsWith("desc:"))
      return value;
    const description = value.slice(5).trim();
    return (details ?? []).find(d => String(d.description ?? "").trim() === description)?.name ?? "";
  }

  // Monitor rules (the MonitorRule schema) as `output` nodes for a file.
  // niri names an output by its connector or by "Make Model Serial". It
  // has no mirroring, bit depth or color settings (supports.monitorMirror /
  // monitorColor are off); a "preferred" mode leaves the mode as it is.
  function outputNodes(rules) {
    return (rules ?? []).map(rule => {
      const name = String(rule.output ?? "");
      const children = [];
      if (rule.disabled) {
        children.push(node("off"));
      } else {
        const mode = MonitorLayout.parseMode(rule.mode);
        if (mode)
          children.push(node("mode", [`${mode.width}x${mode.height}` + (mode.rate > 0 ? "@" + mode.rate.toFixed(3) : "")]));
        children.push(node("scale", [real(rule.scale ?? 1)]), node("transform", [transforms[rule.transform ?? 0] ?? "normal"]), node("position", [], {
          "x": Math.round(rule.x ?? 0),
          "y": Math.round(rule.y ?? 0)
        }));
        if ((rule.vrr ?? 0) > 0)
          children.push(node("variable-refresh-rate", [], rule.vrr === 2 ? {
            "on-demand": true
          } : {}));
      }
      return node("output", [name.startsWith("desc:") ? name.slice(5).trim() : name], {}, children);
    });
  }

  // Monitor rules as niri's Output requests, to set them now; disabled
  // outputs last, so an output isn't turned off before another takes over
  function outputRequests(rules, details) {
    const sorted = (rules ?? []).filter(rule => !rule.disabled).concat((rules ?? []).filter(rule => rule.disabled));
    const requests = [];
    for (const rule of sorted) {
      const output = connectorFor(rule.output, details);
      if (output === "")
        continue;
      const send = action => requests.push({
          "Output": {
            "output": output,
            "action": action
          }
        });
      if (rule.disabled) {
        send("Off");
        continue;
      }
      send("On");
      const mode = MonitorLayout.parseMode(rule.mode);
      if (mode)
        send({
          "Mode": {
            "mode": {
              "Specific": {
                "width": mode.width,
                "height": mode.height,
                "refresh": mode.rate > 0 ? mode.rate : null
              }
            }
          }
        });
      send({
        "Scale": {
          "scale": {
            "Specific": Number(rule.scale ?? 1)
          }
        }
      });
      send({
        "Transform": {
          "transform": ipcTransforms[rule.transform ?? 0] ?? "Normal"
        }
      });
      send({
        "Position": {
          "position": {
            "Specific": {
              "x": Math.round(rule.x ?? 0),
              "y": Math.round(rule.y ?? 0)
            }
          }
        }
      });
      send({
        "Vrr": {
          "vrr": {
            "vrr": (rule.vrr ?? 0) > 0,
            "on_demand": rule.vrr === 2
          }
        }
      });
    }
    return requests;
  }

  // The `output` nodes of a file axiom wrote, as text (the included module
  // or the managed config, which hold no output nodes of the user's)
  function fileOutputNodes(text) {
    const found = String(text ?? "").match(/^output [^\n]*\{[\s\S]*?^\}$/gm) ?? [];
    return found.map(raw => ({
          "raw": raw
        }));
  }

  // --- The files ---

  /**
   * The module axiom loads into niri (the included file, and the detached
   * mode's): `parts`: { header, includeLines, binds (a binds node or
   * null), outputs, look, input, options (nodes each) }. It's included at
   * the end of the user's config, so its look wins; binds on keys the
   * user's config binds aren't in it (the writer leaves them out).
   */
  function moduleText(parts) {
    const body = merged([parts.binds].filter(n => n).concat(parts.outputs ?? [], parts.options ?? [], parts.look ?? [], parts.input ?? []));
    return `${parts.header} from its settings, and rewritten whenever they (or
// the theme) change: edit those, not this file.
//
// Include it at the end of your niri config, so its look wins:
//   ${parts.includeLines}
// Binds on keys your config binds aren't in it: yours win.

${serialize(body)}
`;
  }

  /**
   * The managed niri config: axiom's binds, then the user's files in
   * `userDir` in name order (included after the binds, so the user's own
   * win), then the rest of axiom's layer (after them, so it wins: niri
   * keeps the last of a setting), then the session. `parts`: { header,
   * userDir, userFiles ([name]), binds (node or null), outputs, look,
   * input, options (nodes each), env ([{ name, value }]), start: {
   * command, idle, polkit }, autostart ([{ command, enabled }]), isAgent
   * (command → whether it's a polkit agent) }.
   */
  function managedText(parts) {
    const session = [];
    if ((parts.env ?? []).length > 0)
      session.push(node("environment", [], {}, parts.env.map(entry => node(entry.name, [entry.value]))));
    session.push(node("spawn-sh-at-startup", [parts.start.command]));
    for (const entry of parts.autostart ?? [])
      if (entry.enabled && entry.command.trim() !== "" && !(parts.start.idle && entry.command.trim() === "hypridle") && !(parts.start.polkit && parts.isAgent?.(entry.command)))
        session.push(node("spawn-sh-at-startup", [entry.command.trim()]));
    const includes = (parts.userFiles ?? []).map(name => node("include", [`${parts.userDir}/${name}`], {
        "optional": true
      }));
    const after = merged((parts.outputs ?? []).concat(parts.options ?? [], parts.look ?? [], parts.input ?? [], session));
    return `${parts.header} (niri mode: managed) from its settings, and
// rewritten whenever they (or the theme) change: edit those, not this file.
// Your own config goes in ${parts.userDir}/ as .kdl files, included after
// axiom's binds in name order: your binds win over axiom's, axiom's look
// and settings over yours.

${parts.binds ? serialize([parts.binds]) + "\n\n" : ""}// Your files
${includes.length > 0 ? serialize(includes) : "// (none yet)"}

${serialize(after)}
`;
  }

  // The detached mode's wrapper: the user's config, then axiom's module
  function wrapperText(header, main, module) {
    return `${header} for its detached mode: niri runs this in place of your
// config while axiom does (load-config-file), and your own again after it.
// Your config is untouched.

${serialize([node("include", [main]), node("include", [module])])}
`;
  }

  // What a niri config left behind on leaving managed holds when the
  // takeover set nothing aside: it starts axiom (`startNodes`) and
  // includes the user's files, as the managed one did
  function releasedText(userDir, userFiles, startNodes) {
    const includes = (userFiles ?? []).map(name => node("include", [`${userDir}/${name}`], {
        "optional": true
      }));
    return `// Given back by axiom when it stopped managing niri: this file is yours now,
// and axiom won't write it again. It starts axiom and includes the files in
// ${userDir}/, as axiom's managed one did.
${serialize(startNodes.concat(includes))}
`;
  }

  // The included file once axiom isn't in that mode: nothing in it
  function emptyModuleText(header) {
    return `${header}. axiom isn't in the "included" mode, so this file is
// empty; its include line can go.
`;
  }
}
