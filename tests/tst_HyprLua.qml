import QtQuick
import QtTest
import qs.components.methods

// The Lua it writes also goes to tests/.out/, where scripts/run_tests.sh
// checks it with `luac -p`.
TestCase {
  name: "HyprLua"

  RepoFiles {
    id: files
  }

  readonly property var fieldSchema: ({
      "properties": {
        "gaps": {
          "type": "integer",
          "default": 5,
          "x-hypr": "general.gaps_in"
        },
        "both": {
          "type": "integer",
          "default": 0,
          "x-hypr": ["a.one", "a.two"]
        },
        "opacity": {
          "type": "integer",
          "default": 100,
          "x-hypr": "decoration.active_opacity",
          "x-hyprScale": 0.01
        },
        "flag": {
          "type": "boolean",
          "default": false,
          "x-hypr": "misc.flag",
          "x-hyprValue": "int"
        },
        "border": {
          "type": "string",
          "default": "base0D",
          "x-hypr": "general.col.active_border",
          "x-hyprValue": "color",
          "x-hyprAlpha": "cc"
        },
        "always": {
          "type": "string",
          "default": "dwindle",
          "x-hypr": "general.layout",
          "x-hyprAlways": true
        },
        "gated": {
          "type": "integer",
          "default": 3,
          "x-hypr": "blur.size",
          "x-hyprIf": "blur"
        },
        "blur": {
          "type": "boolean",
          "default": false
        },
        "unmapped": {
          "type": "integer",
          "default": 1
        }
      }
    })

  function hex(name) {
    return name === "base0D" ? "112233" : "445566";
  }

  function test_string_escapes() {
    compare(HyprLua.string('a "b" \\ c\nd'), '"a \\"b\\" \\\\ c\\nd"');
    // A bare carriage return would end the string: Lua refuses the chunk
    compare(HyprLua.string("us\r,de"), '"us\\r,de"');
  }

  function test_value() {
    compare(HyprLua.value(0.1 + 0.2), "0.3");
    compare(HyprLua.value(true), "true");
    compare(HyprLua.value("x"), '"x"');
  }

  function test_defaults_write_only_always_fields() {
    const values = {
      "gaps": 5,
      "both": 0,
      "opacity": 100,
      "flag": false,
      "border": "base0D",
      "always": "dwindle",
      "gated": 3,
      "blur": false,
      "unmapped": 1
    };
    compare(JSON.stringify(HyprLua.configTable(fieldSchema, values, hex)), JSON.stringify({
      "general": {
        "layout": "dwindle"
      }
    }));
  }

  function test_changed_fields_convert() {
    const table = HyprLua.configTable(fieldSchema, {
      "gaps": 8,
      "both": 2,
      "opacity": 90,
      "flag": true,
      "border": "base08",
      "always": "master",
      "gated": 3,
      "blur": true
    }, hex, {
      "general.gaps_out": 12
    });
    compare(table.general.gaps_in, 8);
    compare(table.general.gaps_out, 12);
    compare(table.a.one, 2);
    compare(table.a.two, 2);
    compare(table.decoration.active_opacity, 0.9);
    compare(table.misc.flag, 1);
    compare(table.general.col.active_border, "rgba(445566cc)");
    compare(table.general.layout, "master");
    // x-hyprIf: written, default or not, only while the switch is on
    compare(table.blur.size, 3);
  }

  function test_serialize_is_sorted_and_nested() {
    compare(HyprLua.serialize({}), "{}");
    compare(HyprLua.serialize({
      "b": 1,
      "a": {
        "y": "s",
        "x": true
      }
    }), '{\n  a = { x = true, y = "s" },\n  b = 1,\n}');
  }

  // Every managed option, each changed from its default, as Lua
  function test_managed_schema_serializes_to_lua() {
    const schema = files.json("config/json/config.schema.json");
    const managed = schema.properties.Hyprland.properties.managed;
    const values = SchemaValidation.applyDefaults({}, managed, schema);
    const expected = [];
    for (const key in managed.properties) {
      const field = managed.properties[key];
      if (!field["x-hypr"])
        continue;
      if (field["x-hyprIf"])
        values[field["x-hyprIf"]] = true;
      if (field.type === "boolean")
        values[key] = !values[key];
      else if (field.type === "integer")
        values[key] = values[key] + 1 <= (field.maximum ?? Infinity) ? values[key] + 1 : values[key] - 1;
      else if (field.enum)
        values[key] = field.enum.find(option => option !== values[key]);
      else if (field.type === "string")
        values[key] = field["x-hyprValue"] === "color" ? "base08" : "changed";
      expected.push(...(typeof field["x-hypr"] === "string" ? [field["x-hypr"]] : field["x-hypr"]));
    }
    const table = HyprLua.configTable(managed, values, hex);
    for (const path of expected) {
      let node = table;
      for (const key of path.split("."))
        node = node?.[key];
      verify(node !== undefined, path + " missing from the table");
    }
    const lua = "hl = { config = function(t) end }\nhl.config(" + HyprLua.serialize(table) + ")\n";
    const written = files.write("tests/.out/managed.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  // --- Strips ---

  function test_stripsLua_without_strips_writes_nothing() {
    compare(HyprLua.stripsLua([], {}, {}), []);
  }

  // Every monitor sets the layout; a named one gets a rule that wins over
  // it; strip settings only once changed. Run by `lua` with a stubbed hl.
  function test_stripsLua_runs() {
    const schema = files.json("config/json/config.schema.json");
    const workspaces = schema.properties.Workspaces;
    const options = {
      "stripColumnWidth": 70,
      "stripFollowFocus": true
    };
    const lines = HyprLua.stripsLua([
      {
        "monitor": "*",
        "direction": "vertical"
      },
      {
        "monitor": "DP-1",
        "direction": "horizontal"
      }
    ], workspaces, options);
    compare(lines.length, 2);
    verify(!lines[0].includes("follow_focus"), "a default setting is left to Hyprland");
    compare(HyprLua.stripsLua([
      {
        "monitor": "DP-2",
        "direction": "vertical"
      }
    ], workspaces, {
      "stripColumnWidth": 50,
      "stripFollowFocus": true
    }), [`hl.workspace_rule({ workspace = "m[DP-2]", layout = "scrolling", layout_opts = { direction = "down" } })`]);
    const lua = `local config, rules = nil, {}
hl = {
  config = function(t) config = t end,
  workspace_rule = function(spec) rules[#rules + 1] = spec end,
}
${lines.join("\n")}
assert(config.general.layout == "scrolling", "every monitor scrolls")
assert(config.scrolling.direction == "down", "vertical goes down")
assert(math.abs(config.scrolling.column_width - 0.7) < 1e-6, "column width scaled")
assert(#rules == 1 and rules[1].workspace == "m[DP-1]", "a rule for the named monitor")
assert(rules[1].layout == "scrolling" and rules[1].layout_opts.direction == "right", "horizontal goes right")
`;

    const written = files.write("tests/.out/strips.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  // Applied once per Hyprland load; other strips reload it
  function test_stripsRuntimeLua_runs() {
    const lines = HyprLua.stripsRuntimeLua([`hl.workspace_rule({ workspace = "m[DP-1]" })`], "a");
    const lua = `local rules, reloads = 0, 0
hl = {
  workspace_rule = function() rules = rules + 1 end,
  dispatch = function(d) reloads = reloads + 1 end,
  dsp = { exec_cmd = function(c) return c end },
}
local function apply()
${lines.join("\n")}
end
apply(); apply()
assert(rules == 1 and reloads == 0, "applied once")
AXIOM_STRIPS = "b"
apply()
assert(rules == 1 and reloads == 1, "other strips reload")
`;

    const written = files.write("tests/.out/stripsRuntime.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  // --- Monitors ---

  readonly property var ruleDefaults: {
    const schema = files.json("config/json/config.schema.json");
    return SchemaValidation.applyDefaults({}, schema.definitions.MonitorRule, schema);
  }

  function rule(fields) {
    return Object.assign({}, ruleDefaults, fields);
  }

  function test_monitorSpec_writes_only_changes() {
    compare(HyprLua.monitorSpec(rule({
      "output": "DP-1",
      "mode": "3440x1440@240"
    })), {
      "output": "DP-1",
      "mode": "3440x1440@240",
      "position": "0x0",
      "scale": 1
    });
    const spec = HyprLua.monitorSpec(rule({
      "output": "DP-1",
      "x": -1440,
      "y": -1100,
      "transform": 3,
      "vrr": 2,
      "bitdepth": 10,
      "cm": "hdr",
      "sdrBrightness": 1.2
    }));
    compare(spec.position, "-1440x-1100");
    compare(spec.transform, 3);
    compare(spec.vrr, 2);
    compare(spec.bitdepth, 10);
    compare(spec.cm, "hdr");
    compare(spec.sdrbrightness, 1.2);
    compare(spec.sdrsaturation, undefined);
    compare(HyprLua.monitorSpec(rule({
      "output": "HDMI-A-1",
      "disabled": true,
      "x": 5
    })), {
      "output": "HDMI-A-1",
      "disabled": true
    });
  }

  function test_monitorCalls_resolve_mirrors() {
    const calls = HyprLua.monitorCalls([rule({
        "output": "desc:TV",
        "mirror": "desc:Main"
      }), rule({
        "output": "DP-3",
        "mirror": "desc:Gone"
      })], output => output === "desc:Main" ? "DP-1" : "");
    compare(calls[0], `hl.monitor({ output = "desc:TV", mode = "preferred", position = "0x0", scale = 1, mirror = "DP-1" })`);
    verify(!calls[1].includes("mirror"), "an absent mirror target is left out");
  }

  function test_monitorsLua_without_profiles_only_unsubscribes() {
    const lines = HyprLua.monitorsLua([]);
    verify(lines.join("\n").includes("sub:remove()"));
    verify(!lines.join("\n").includes("axiom_apply_monitors"));
  }

  // The generated picker, run by `lua` with a stubbed hl, picks what
  // MonitorLayout.matchProfile picks
  function test_monitorsLua_picks_like_matchProfile() {
    const profiles = [
      {
        "name": "Desk",
        "outputs": [rule({
            "output": "desc:AOC",
            "mode": "3440x1440@240"
          }), rule({
            "output": "HDMI-A-1",
            "disabled": true
          })]
      },
      {
        "name": "TV",
        "outputs": [rule({
            "output": "desc:AOC",
            "mode": "3440x1440@144"
          }), rule({
            "output": "desc:LG TV",
            "mode": "1920x1080@60",
            "x": 3440,
            "mirror": "desc:AOC"
          })]
      }
    ];
    const aoc = {
      "name": "DP-1",
      "description": "AOC"
    };
    const tv = {
      "name": "HDMI-A-1",
      "description": "LG TV"
    };
    const cases = [[[aoc], "3440x1440@240"], [[aoc, tv], "3440x1440@144"], [[tv], "3440x1440@144"]];
    const monitorsLua = monitors => "{ " + monitors.map(m => `{ name = ${HyprLua.string(m.name)}, description = ${HyprLua.string(m.description)} }`).join(", ") + " }";
    const checks = cases.map(([connected, mode]) => {
      compare(profiles[MonitorLayout.matchProfile(profiles, connected)].outputs[0].mode, mode);
      return `check(${monitorsLua(connected)}, ${HyprLua.string(mode)})`;
    });
    const lua = `local connected, applied, removed = {}, {}, 0
hl = {
  get_monitors = function() return connected end,
  monitor = function(spec) applied[#applied + 1] = spec end,
  on = function() return { remove = function() removed = removed + 1 end } end,
}
local function run()
${HyprLua.monitorsLua(profiles).join("\n")}
end
run()
local function check(monitors, mode)
  connected, applied = monitors, {}
  axiom_apply_monitors()
  assert(applied[1].mode == mode, "picked " .. tostring(applied[1].mode) .. ", wanted " .. mode)
end
${checks.join("\n")}
-- The TV profile mirrors onto the AOC's connector, and resets the output
-- Desk disables
check(${monitorsLua([aoc, tv])}, "3440x1440@144")
assert(applied[2].mirror == "DP-1", "mirror resolved to a connector")
local reset = false
for _, spec in ipairs(applied) do
  if spec.output == "HDMI-A-1" and spec.mode == "preferred" then reset = true end
end
assert(reset, "the output Desk disables goes back to its defaults")
-- A first start, nothing reported yet: the first profile
check({}, "3440x1440@240")
-- Running the chunk again drops the earlier handlers
run()
assert(removed == 2, "earlier handlers removed")
`;

    const written = files.write("tests/.out/monitors.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  // The greeter's Hyprland: the monitors always, and only the x-greeter
  // options of managed mode
  function test_greeterLua() {
    const schema = files.json("config/json/config.schema.json");
    const managedSchema = schema.properties.Hyprland.properties.managed;
    const profiles = [
      {
        "name": "desk",
        "outputs": [rule({
            "output": "DP-1"
          })]
      }
    ];
    const detached = HyprLua.greeterLua(profiles, managedSchema, undefined, hex);
    verify(detached.some(line => line.startsWith("AXIOM_MONITOR_PROFILES")));
    verify(!detached.some(line => line.startsWith("hl.config")));

    const managed = SchemaValidation.applyDefaults({}, managedSchema, schema);
    managed.kbLayout = "us,de";
    managed.sensitivity = -50;
    managed.shadowRange = 33;
    const lines = HyprLua.greeterLua(profiles, managedSchema, managed, hex);
    const config = lines[lines.length - 1];
    verify(config.startsWith("hl.config("));
    verify(config.includes('kb_layout = "us,de"'));
    verify(config.includes("sensitivity = -0.5"));
    verify(!config.includes("range"));
    const lua = "hl = { config = function(t) end, monitor = function(t) end, get_monitors = function() return {} end, on = function() return { remove = function() end } end }\n" + lines.join("\n") + "\n";
    const written = files.write("tests/.out/greeter.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  function test_look_writes_only_its_parts_that_are_on() {
    const off = {
      "borders": false,
      "shape": false,
      "gaps": false,
      "gapsIn": 3,
      "gapsOut": 6
    };
    compare(HyprLua.lookLua(off, "ffffff", "000000", 2, 8), []);
    compare(HyprLua.lookParts(off), []);

    const gaps = Object.assign({}, off, {
      "gaps": true,
      "gapsIn": 4,
      "gapsOut": 12
    });
    const gapsLua = HyprLua.lookLua(gaps, "ffffff", "000000", 2, 8).join("\n");
    verify(gapsLua.includes("gaps_in = 4"));
    verify(gapsLua.includes("gaps_out = 12"));
    verify(!gapsLua.includes("rounding"));
    verify(!gapsLua.includes("active_border"));

    const all = Object.assign({}, gaps, {
      "borders": true,
      "shape": true
    });
    const lines = HyprLua.lookLua(all, "aabbcc", "112233", 2, 8);
    const lua = lines.join("\n");
    verify(lua.startsWith("hl.config("));
    verify(lua.includes('active_border = "rgb(aabbcc)"'));
    verify(lua.includes('inactive_border = "rgb(112233)"'));
    verify(lua.includes("border_size = 2"));
    verify(lua.includes("rounding = 8"));
    compare(HyprLua.lookParts(all), ["borders", "shape", "gaps"]);
    verify(!lua.includes("blur"));
    const written = files.write("tests/.out/look.lua", lua + "\n");
    tryVerify(() => written.done, 2000);
  }

  function test_blurStrength() {
    compare(HyprLua.blurStrength(1), {
      "size": 3,
      "passes": 1
    });
    compare(HyprLua.blurStrength(10), {
      "size": 12,
      "passes": 4
    });
    compare(HyprLua.blurStrength(99).size, 12);
  }

  function test_blurLua() {
    const lines = opts => HyprLua.blurLua(Object.assign({
        "threshold": 0.5,
        "strength": 5
      }, opts));
    const on = lines({
      "on": true
    });
    const rules = on.filter(line => line.startsWith("hl.layer_rule"));
    compare(rules.length, 3);
    verify(rules[0].includes('name = "axiom-blur"'));
    verify(rules[0].includes('"^axiom-(border|bar|bar-floating|popout-under'), "the border blurs as the rest do");
    verify(rules[0].includes("blur_popups = true, ignore_alpha = 0.5, xray = true, enabled = true"), "the wallpaper alone by default");
    verify(rules[1].includes('"^axiom-(border)$"') && rules[1].endsWith("enabled = false })"), "the old border rule stays off");
    verify(rules[2].includes('"^axiom-(backdrop|polkit)$"'));
    verify(rules[2].includes("enabled = false"), "backdrops only when asked");
    verify(lines({
      "on": true,
      "backdrops": true
    })[2].includes("enabled = true"));
    verify(!lines({
      "on": true,
      "throughWindows": true
    })[0].includes("xray"), "through windows: no xray");
    // Taken back by redefining the rules, never dropped
    const offRules = lines({
      "on": false,
      "backdrops": true
    }).filter(line => line.startsWith("hl.layer_rule"));
    compare(offRules.length, 3);
    verify(offRules.every(line => line.endsWith("enabled = false })")));

    // The user's blur kept and given back; windows keep their own say
    // unless they blur too
    const run = (opts, check) => `${lines(opts).join("\n")}\n${check}\n`;
    const lua = `local options, windowRules = { ["decoration.blur.enabled"] = false, ["decoration.blur.size"] = 4, ["decoration.blur.passes"] = 1 }, {}
hl = {
  layer_rule = function() end,
  window_rule = function(spec) windowRules[spec.name] = spec end,
  get_config = function(key) return options[key] end,
  config = function(t)
    for key, v in pairs(t.decoration.blur) do options["decoration.blur." .. key] = v end
  end,
}
${run({
      "on": true
    }, `assert(options["decoration.blur.enabled"] == true, "blur on")
assert(options["decoration.blur.size"] == 7 and options["decoration.blur.passes"] == 2, "axiom's strength")
assert(windowRules["axiom-no-window-blur"].enabled == true, "windows with blur off kept unblurred")`)}
${run({
      "on": true,
      "strength": 8
    }, `assert(options["decoration.blur.size"] == 10, "a new strength")
assert(AXIOM_USER_BLUR.size == 4, "the user's kept, not axiom's")`)}
${run({
      "on": true,
      "windows": true
    }, `assert(windowRules["axiom-no-window-blur"].enabled == false, "windows blur too")`)}
${run({
      "on": false
    }, `assert(options["decoration.blur.enabled"] == false, "given back")
assert(options["decoration.blur.size"] == 4 and options["decoration.blur.passes"] == 1, "the user's strength back")
assert(windowRules["axiom-no-window-blur"].enabled == false, "windows rule off")`)}
options["decoration.blur.enabled"] = true
${run({
      "on": true
    }, `assert(windowRules["axiom-no-window-blur"].enabled == false, "a config with blur on blurs its windows")`)}
${run({
      "on": false
    }, `assert(options["decoration.blur.enabled"] == true, "and stays on")`)}
`;

    const written = files.write("tests/.out/blur.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }

  function test_leaveSubmap() {
    compare(HyprLua.leaveSubmap("axiom_record"), `if hl.get_current_submap() == "axiom_record" then hl.dispatch(hl.dsp.submap("reset")) end`);
  }

  function test_switcherHeld() {
    compare(HyprLua.switcherHeld(["ALT"]), ["ALT"]);
    compare(HyprLua.switcherHeld(["ALT", "SHIFT"]), ["ALT"], "SHIFT only turns it around");
    compare(HyprLua.switcherHeld(["SHIFT"]), ["SHIFT"], "unless it's all there is");
    compare(HyprLua.switcherHeld([]), [], "nothing to hold");
  }

  function test_switcherLua_without_binds_only_unbinds() {
    const lua = HyprLua.switcherLua([]).join("\n");
    verify(lua.includes("hl.unbind(key)"));
    verify(!lua.includes("hl.bind("));
    verify(lua.includes("AXIOM_SWITCHER_KEYS = {  }"));
  }

  // Run twice against a stub hl: the second run unbinds the first's keys,
  // the binds send their events, and letting go of ALT (not SHIFT) picks
  function test_switcherLua_runs() {
    const entries = [
      {
        "mods": ["ALT"],
        "key": "Tab",
        "step": 1
      },
      {
        "mods": ["ALT", "SHIFT"],
        "key": "Tab",
        "step": -1
      }
    ];
    const lua = `local binds, events, submap, down, listener, timer = {}, {}, "", {}, nil, nil
hl = {
  define_submap = function(name, fn) assert(name == "axiom_switcher"); fn() end,
  bind = function(key, fn, opts) assert(not binds[key], "bound twice: " .. key); binds[key] = { fn = fn, opts = opts } end,
  unbind = function(key) binds[key] = nil end,
  dispatch = function(d) if d.event then events[#events + 1] = d.event else submap = d.submap end end,
  get_current_submap = function() return submap end,
  is_key_down = function(key) return down[key] == true end,
  on = function(name, fn) assert(name == "input.keyboard.key"); listener = fn; return { remove = function() listener = nil end } end,
  timer = function(fn, opts) assert(opts.type == "oneshot"); timer = fn; return {} end,
  dsp = {
    event = function(data) return { event = data } end,
    submap = function(name) return { submap = name } end,
  },
}
local function run()
${HyprLua.switcherLua(entries).join("\n")}
end
-- A key goes up or down; the check runs once its timer fires
local function key(name, pressed)
  down[name] = pressed
  if listener then listener(0, 0, pressed and 1 or 0) end
  if timer then local t = timer; timer = nil; t() end
end
run()
run()
local open = ${HyprLua.switcherBindLua(1)}
down["Alt_L"] = true
open()
assert(submap == "axiom_switcher" and events[1] == "axiom-switcher:step 1", "the bind opens")
assert(listener, "watching for the release")
open()
binds["ALT + SHIFT + Tab"].fn()
assert(events[3] == "axiom-switcher:step -1" and binds["ALT + SHIFT + Tab"].opts.repeating, "steps back, repeating")
assert(binds["ALT + Tab"], "steps on")
key("Tab", false)
key("Shift_L", true)
key("Shift_L", false)
assert(#events == 3 and submap == "axiom_switcher", "releasing Tab or SHIFT doesn't pick")
key("Alt_L", false)
assert(events[4] == "axiom-switcher:commit" and submap == "reset", "releasing ALT picks and leaves")
assert(not listener, "stops watching")
key("Alt_L", true)
key("Alt_L", false)
assert(#events == 4, "nothing once closed")
-- Escape cancels, and stops watching too
down["Alt_L"] = true
open()
binds["Escape"].fn()
assert(events[6] == "axiom-switcher:cancel" and submap == "reset" and not listener, "escape cancels")
-- Left by something else: the next release stops watching, quietly
open()
submap = "reset"
key("Alt_L", false)
assert(#events == 7 and not listener, "left elsewhere")
-- Picked from outside (a tile clicked): stops watching and leaves
open()
${HyprLua.switcherLeaveLua}
assert(submap == "reset" and not listener, "left from outside")
assert(#AXIOM_SWITCHER_KEYS == 4, "keys remembered: " .. #AXIOM_SWITCHER_KEYS)
`;

    const written = files.write("tests/.out/switcher.run.lua", lua);
    tryVerify(() => written.done, 2000);
  }
}
