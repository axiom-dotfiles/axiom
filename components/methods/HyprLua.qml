pragma Singleton
import QtQuick

// Hyprland's Lua config from schema fields: each field with `x-hypr` (the
// option's dotted path, or a list of paths) becomes one value of a nested
// hl.config({...}) table.
//   x-hyprScale   a factor for integers shown scaled (0.01 for a percent)
//   x-hyprValue   how the value is converted: "int" (a boolean as 0/1),
//                 "number" (an enum of numbers written as strings),
//                 "emptyIsDefault" ("default" → ""), "color" (a theme color
//                 name as rgba(hex + x-hyprAlpha, "ff" unless given))
//   x-hyprAlways  written even when it's the schema default; other fields
//                 are only written once changed, so Hyprland's own default
//                 (and the user's files) stay in charge otherwise
//   x-hyprIf      a boolean sibling: written (default or not) only when on
QtObject {
  id: root

  // A Lua string literal
  function string(text) {
    return '"' + String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r") + '"';
  }

  // A value as Lua: strings quoted, numbers without float noise
  function value(v) {
    if (typeof v === "string")
      return string(v);
    if (typeof v === "number")
      return String(Math.round(v * 10000) / 10000);
    return String(v);
  }

  function _convert(fieldSchema, v, resolveHex) {
    if (fieldSchema["x-hyprScale"] !== undefined)
      return v * fieldSchema["x-hyprScale"];
    switch (fieldSchema["x-hyprValue"]) {
    case "int":
      return v ? 1 : 0;
    case "number":
      return Number(v);
    case "emptyIsDefault":
      return v === "default" ? "" : v;
    case "color":
      return `rgba(${resolveHex(v)}${fieldSchema["x-hyprAlpha"] ?? "ff"})`;
    }
    return v;
  }

  function _set(table, path, v) {
    const keys = path.split(".");
    let node = table;
    for (const key of keys.slice(0, -1)) {
      if (typeof node[key] !== "object" || node[key] === null)
        node[key] = {};
      node = node[key];
    }
    node[keys[keys.length - 1]] = v;
  }

  // The nested option table for `values` (an object of `objectSchema`'s
  // fields). resolveHex(colorName) gives "rrggbb"; `overrides` maps option
  // paths to values that win over the fields (axiom's shape, say).
  function configTable(objectSchema, values, resolveHex, overrides) {
    const table = {};
    const props = objectSchema?.properties ?? {};
    for (const key in props) {
      const fieldSchema = props[key];
      const target = fieldSchema["x-hypr"];
      if (!target || values[key] === undefined)
        continue;
      const condition = fieldSchema["x-hyprIf"];
      if (condition ? !values[condition] : !fieldSchema["x-hyprAlways"] && values[key] === fieldSchema.default)
        continue;
      const v = _convert(fieldSchema, values[key], resolveHex);
      // A schema list reaches QML as a list object, not a JS Array
      const paths = typeof target === "string" ? [target] : Array.prototype.slice.call(target);
      for (const path of paths)
        _set(table, path, v);
    }
    for (const path in overrides ?? {})
      _set(table, path, overrides[path]);
    return table;
  }

  // A table as a Lua literal, keys sorted. Nested tables go on lines of
  // their own below the top level, until one fits on a line.
  function serialize(table, indent) {
    const pad = indent ?? "";
    const keys = Object.keys(table).sort();
    const entry = key => {
      const v = table[key];
      return `${key} = ${typeof v === "object" ? serialize(v, pad + "  ") : value(v)}`;
    };
    const flat = `{ ${keys.map(entry).join(", ")} }`;
    if (keys.length === 0)
      return "{}";
    if (pad !== "" && flat.length <= 100 && !flat.includes("\n"))
      return flat;
    return `{\n${keys.map(key => `${pad}  ${entry(key)},`).join("\n")}\n${pad}}`;
  }

  // --- The window look (Hyprland.look) ---

  // Its parts that are on, as the lines of one hl.config(), or []: themed borders
  // (hex colors without #), axiom's shape (border width, corner radius)
  // and gaps
  function lookLua(look, activeHex, inactiveHex, borderWidth, radius) {
    const table = {};
    if (look.borders)
      _set(table, "general.col", {
        "active_border": `rgb(${activeHex})`,
        "inactive_border": `rgb(${inactiveHex})`
      });
    if (look.shape) {
      _set(table, "general.border_size", borderWidth);
      _set(table, "decoration.rounding", radius);
    }
    if (look.gaps) {
      _set(table, "general.gaps_in", look.gapsIn);
      _set(table, "general.gaps_out", look.gapsOut);
    }
    return Object.keys(table).length > 0 ? `hl.config(${serialize(table)})`.split("\n") : [];
  }

  // Which of its parts are on, e.g. ["borders", "gaps"]
  function lookParts(look) {
    return ["borders", "shape", "gaps"].filter(part => look[part]);
  }

  // --- Strips (Workspaces.strips, WorkspacesConfig.strips) ---

  readonly property var _stripDirections: ({
      "horizontal": "right",
      "vertical": "down"
    })

  // Lua lines for the strips (Hyprland's scrolling layout): `strips` is
  // [{ monitor, direction }] with monitors resolved ("*" = every monitor).
  // Every monitor makes scrolling, in its direction, the layout everywhere;
  // a named monitor gets a workspace rule (m[name]) that wins over it. The
  // Workspaces schema's `x-hypr` strip settings come with them (`values`).
  // Nothing without strips.
  function stripsLua(strips, workspacesSchema, values) {
    if (strips.length === 0)
      return [];
    const table = configTable(workspacesSchema, values);
    const every = strips.find(strip => strip.monitor === "*");
    if (every) {
      _set(table, "general.layout", "scrolling");
      _set(table, "scrolling.direction", _stripDirections[every.direction]);
    }
    const lines = Object.keys(table).length > 0 ? [`hl.config(${serialize(table)})`] : [];
    for (const strip of strips) {
      if (strip.monitor !== "*")
        lines.push(`hl.workspace_rule({ workspace = ${string(`m[${strip.monitor}]`)}, layout = "scrolling", layout_opts = { direction = ${string(_stripDirections[strip.direction])} } })`);
    }
    return lines;
  }

  // The runtime (detached) form of stripsLua's `lines`: applied once per
  // Hyprland config load, since workspace rules add up rather than
  // replace. `key` names what they are (in AXIOM_STRIPS, Hyprland's Lua
  // state, which a reload resets and a shell reload keeps); different
  // strips can't be taken back, so they reload Hyprland, which applies the
  // new ones over the user's config alone.
  function stripsRuntimeLua(lines, key) {
    return [`if AXIOM_STRIPS == nil then`].concat(lines.map(line => "  " + line), [`  AXIOM_STRIPS = ${string(key)}`, `elseif AXIOM_STRIPS ~= ${string(key)} then`, `  hl.dispatch(hl.dsp.exec_cmd("hyprctl reload"))`, `end`]);
  }

  // --- Monitors (Hyprland.monitors, MonitorLayout) ---

  // A monitor rule (the MonitorRule schema) as hl.monitor()'s spec: output,
  // mode, position and scale always, the rest only when changed. `mirror`
  // stays an output id: monitorsLua resolves it to a connector name.
  function monitorSpec(rule) {
    if (rule.disabled)
      return {
        "output": rule.output,
        "disabled": true
      };
    const spec = {
      "output": rule.output,
      "mode": rule.mode || "preferred",
      "position": `${Math.round(rule.x ?? 0)}x${Math.round(rule.y ?? 0)}`,
      "scale": rule.scale ?? 1
    };
    if (rule.transform)
      spec.transform = rule.transform;
    if (rule.mirror)
      spec.mirror = rule.mirror;
    if (rule.vrr)
      spec.vrr = rule.vrr;
    if (rule.bitdepth === 10)
      spec.bitdepth = 10;
    if (rule.cm && rule.cm !== "auto")
      spec.cm = rule.cm;
    if (rule.sdrBrightness !== undefined && rule.sdrBrightness !== 1)
      spec.sdrbrightness = rule.sdrBrightness;
    if (rule.sdrSaturation !== undefined && rule.sdrSaturation !== 1)
      spec.sdrsaturation = rule.sdrSaturation;
    return spec;
  }

  readonly property var _specOrder: ["output", "mode", "position", "scale"]

  // A spec on one line, output first
  function inlineSpec(spec) {
    const keys = Object.keys(spec).sort((a, b) => {
      const ia = _specOrder.indexOf(a);
      const ib = _specOrder.indexOf(b);
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || (a < b ? -1 : a > b ? 1 : 0);
    });
    return `{ ${keys.map(key => `${key} = ${value(spec[key])}`).join(", ")} }`;
  }

  // hl.monitor() calls for rules applied now (the Monitors page's Apply and
  // its revert). `mirrorName(output)` gives the connector a mirror target is
  // on, or "" to leave the mirror out.
  function monitorCalls(rules, mirrorName) {
    return rules.map(rule => {
      const spec = monitorSpec(rule);
      if (spec.mirror !== undefined) {
        const name = mirrorName(spec.mirror);
        if (name)
          spec.mirror = name;
        else
          delete spec.mirror;
      }
      return `hl.monitor(${inlineSpec(spec)})`;
    });
  }

  // Lua lines that keep the monitors in the profile for what's connected:
  // AXIOM_MONITOR_PROFILES, axiom_apply_monitors() (picks as
  // MonitorLayout.matchProfile does, from hl.get_monitors(), which only
  // lists enabled outputs) run now and on every monitor.added/removed.
  // Outputs another profile lists, but the chosen one doesn't, go back to
  // Hyprland's defaults (connected or not: a disabled output isn't listed),
  // so a disable doesn't outlive its profile.
  // With no profiles it only drops the event handlers of an earlier run.
  function monitorsLua(profiles) {
    const lines = ["if AXIOM_MONITOR_SUBS then", "  for _, sub in ipairs(AXIOM_MONITOR_SUBS) do sub:remove() end", "  AXIOM_MONITOR_SUBS = nil", "end"];
    const used = (profiles ?? []).filter(profile => (profile.outputs ?? []).some(rule => rule.output));
    if (used.length === 0)
      return lines;
    lines.push("AXIOM_MONITOR_PROFILES = {");
    for (const profile of used) {
      lines.push(`  { name = ${string(profile.name ?? "")}, outputs = {`);
      for (const rule of profile.outputs)
        if (rule.output)
          lines.push(`    ${inlineSpec(monitorSpec(rule))},`);
      lines.push("  } },");
    }
    lines.push("}");
    lines.push(`function axiom_apply_monitors()
  local connected = hl.get_monitors() or {}
  local function matches(output, mon)
    if output:sub(1, 5) == "desc:" then return mon.description == output:sub(6) end
    return mon.name == output
  end
  local function find(output)
    for _, mon in ipairs(connected) do
      if matches(output, mon) then return mon end
    end
  end
  local best, bestScore = nil, 0
  for _, profile in ipairs(AXIOM_MONITOR_PROFILES) do
    local score, exact = 0, true
    for _, spec in ipairs(profile.outputs) do
      local found = find(spec.output)
      if found and not spec.disabled then score = score + 1 end
      if not found and not spec.disabled then exact = false end
    end
    for _, mon in ipairs(connected) do
      local listed = false
      for _, spec in ipairs(profile.outputs) do
        if matches(spec.output, mon) then listed = true end
      end
      if not listed then exact = false end
    end
    if exact and score > 0 then score = score + 1000 end
    if score > bestScore then best, bestScore = profile, score end
  end
  -- Nothing reported yet (a first start): the first profile, as rules
  -- waiting for their outputs
  if #connected == 0 then best = AXIOM_MONITOR_PROFILES[1] end
  if not best then return end
  local mine = {}
  for _, spec in ipairs(best.outputs) do
    mine[spec.output] = true
    local rule = {}
    for k, v in pairs(spec) do rule[k] = v end
    if rule.mirror then
      local target = find(rule.mirror)
      rule.mirror = target and target.name or nil
    end
    hl.monitor(rule)
  end
  for _, profile in ipairs(AXIOM_MONITOR_PROFILES) do
    for _, spec in ipairs(profile.outputs) do
      if not mine[spec.output] then
        mine[spec.output] = true
        hl.monitor({ output = spec.output, mode = "preferred", position = "auto", scale = "auto" })
      end
    end
  end
end`);
    lines.push(`AXIOM_MONITOR_SUBS = { hl.on("monitor.added", axiom_apply_monitors), hl.on("monitor.removed", axiom_apply_monitors) }`);
    lines.push("axiom_apply_monitors()");
    return lines;
  }

  // The greeter's Hyprland, from its bundle (GreeterBundle): the monitor
  // layouts (monitorsLua, in every mode), and in managed mode one
  // hl.config of the options marked x-greeter (`managedSchema`:
  // Hyprland.managed's schema; any other option in `managed` is left out).
  // resolveHex as for configTable.
  function greeterLua(profiles, managedSchema, managed, resolveHex) {
    const lines = monitorsLua(profiles);
    if (!managed)
      return lines;
    const props = managedSchema?.properties ?? {};
    const greeterSchema = {
      "properties": {}
    };
    for (const key in props)
      if (props[key]["x-greeter"] === true)
        greeterSchema.properties[key] = props[key];
    const table = configTable(greeterSchema, managed, resolveHex, {});
    if (Object.keys(table).length > 0)
      lines.push(`hl.config(${serialize(table)})`);
    return lines;
  }

  // A chunk resetting Hyprland to its main binds if it's in submap `name`
  function leaveSubmap(name) {
    return `if hl.get_current_submap() == ${string(name)} then hl.dispatch(hl.dsp.submap("reset")) end`;
  }

  // --- The window switcher ---
  // Hyprland holds every key while it's open: the bind enters the switcher
  // submap on its press, so a release can't come before it, and the submap
  // sends what happens as `custom>>axiom-switcher:<verb>` events on
  // socket2 (WindowSwitcherManager listens). Releasing the held modifier
  // picks and leaves the submap in Hyprland itself, so it never sticks
  // without axiom. A release bind can't see that: Hyprland fires one on a
  // modifier only when no other key came between its press and release
  // (a tapped SUPER), and Tab always does. So while it's open a key
  // listener checks, after each release, whether any held modifier is
  // still down (by keysym name, a moment later, so it doesn't depend on
  // when Hyprland updates what's down).

  readonly property string switcherSubmap: "axiom_switcher"
  readonly property string switcherEvent: "axiom-switcher:"
  // Leaves the switcher from outside its binds (a click on a tile)
  readonly property string switcherLeaveLua: "if axiom_switcher_leave then axiom_switcher_leave() end"
  readonly property var _modifierKeys: ({
      "SUPER": ["Super_L", "Super_R"],
      "CTRL": ["Control_L", "Control_R"],
      "ALT": ["Alt_L", "Alt_R"],
      "SHIFT": ["Shift_L", "Shift_R"]
    })

  // The modifiers a switcher combo is held by (KeyNames.split's `mods`):
  // all but SHIFT, which only turns it around, unless SHIFT is all there is
  function switcherHeld(mods) {
    const held = (mods ?? []).filter(mod => mod !== "SHIFT" && _modifierKeys[mod]);
    return held.length > 0 || !(mods ?? []).includes("SHIFT") ? held : ["SHIFT"];
  }

  function _switcherDispatch(verb) {
    return `hl.dispatch(hl.dsp.event(${string(switcherEvent + verb)}))`;
  }

  // The switcher bind's dispatcher: enters the submap, starts watching for
  // the release (switcherLua defines axiom_switcher_watch), then steps
  function switcherBindLua(step) {
    return `function() hl.dispatch(hl.dsp.submap(${string(switcherSubmap)})); if axiom_switcher_watch then axiom_switcher_watch() end; ${_switcherDispatch("step " + step)} end`;
  }

  /**
   * Lua lines for the switcher, from `entries` ([{ mods, key, step }], each
   * a switcher bind split by KeyNames.split): the submap, where each combo
   * steps again (repeating), Return picks and Escape cancels, and
   * axiom_switcher_watch()/axiom_switcher_unwatch(), the key listener that
   * picks once no held modifier (AXIOM_SWITCHER_HELD) is down, and
   * axiom_switcher_leave(), which stops it and leaves the submap. Redefining
   * a submap adds to its binds, so the keys the last run bound
   * (AXIOM_SWITCHER_KEYS) are unbound first; with no entries that is all
   * it does.
   */
  function switcherLua(entries) {
    const binds = [];
    const keys = [];
    const bind = (key, body, options) => {
      keys.push(key);
      binds.push(`  hl.bind(${string(key)}, function() ${body} end, { ${options} })`);
    };
    const held = [];
    for (const entry of entries ?? []) {
      bind(entry.mods.concat([entry.key]).join(" + "), _switcherDispatch("step " + entry.step), "repeating = true");
      for (const mod of switcherHeld(entry.mods))
        for (const key of _modifierKeys[mod])
          if (!held.includes(key))
            held.push(key);
    }
    if (binds.length > 0) {
      bind("Return", `${_switcherDispatch("commit")}; axiom_switcher_leave()`, "ignore_mods = true");
      bind("Escape", `${_switcherDispatch("cancel")}; axiom_switcher_leave()`, "ignore_mods = true");
    }
    return [`hl.define_submap(${string(switcherSubmap)}, function()`, "  for _, key in ipairs(AXIOM_SWITCHER_KEYS or {}) do hl.unbind(key) end"].concat(binds, ["end)", `AXIOM_SWITCHER_KEYS = { ${keys.map(key => string(key)).join(", ")} }`, `AXIOM_SWITCHER_HELD = { ${held.map(key => string(key)).join(", ")} }`, `function axiom_switcher_unwatch()
  if AXIOM_SWITCHER_SUB then AXIOM_SWITCHER_SUB:remove() end
  AXIOM_SWITCHER_SUB = nil
end`, `function axiom_switcher_leave()
  axiom_switcher_unwatch()
  ${leaveSubmap(switcherSubmap)}
end`, `function axiom_switcher_watch()
  if AXIOM_SWITCHER_SUB then return end
  AXIOM_SWITCHER_SUB = hl.on("input.keyboard.key", function(_, _, state)
    if state ~= 0 then return end
    AXIOM_SWITCHER_CHECK = hl.timer(function()
      if hl.get_current_submap() ~= ${string(switcherSubmap)} then return axiom_switcher_unwatch() end
      for _, key in ipairs(AXIOM_SWITCHER_HELD) do
        if hl.is_key_down(key) then return end
      end
      ${_switcherDispatch("commit")}
      axiom_switcher_leave()
    end, { timeout = 10, type = "oneshot" })
  end)
end`]);
  }
}
