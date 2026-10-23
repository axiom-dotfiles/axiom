import QtQuick
import QtTest
import Qt.labs.folderlistmodel
import qs.components.methods

// ConfigExamples (what a shared config holds, by the schema's x-scope, and
// how it applies), and the shipped examples/*.json: each loads as a valid
// config the way SavedConfigsManager loads it, so an example can't rot when
// the schema moves.
TestCase {
  id: test
  name: "ConfigExamples"

  // Records the helper calls as shared fixtures (Shared.qml)
  Shared {
    id: shared
    testCase: test
  }

  RepoFiles {
    id: files
  }

  FolderListModel {
    id: examples
    folder: files.url("examples/")
    nameFilters: ["*.json"]
    showDirs: false
  }

  property var schema

  function initTestCase() {
    schema = shared.legacySchema;
  }

  // ConfigManager.normalizeConfig: migrate → prune → defaults
  function load(parsed) {
    const config = shared.migrate(Utils.clone(parsed)).config;
    shared.pruneUnknown(config, schema);
    return SchemaValidation.applyDefaults(config, schema);
  }

  function defaults() {
    return load({
      "version": ConfigMigration.currentVersion
    });
  }

  function bar(id, monitor, widgets) {
    return {
      "id": id,
      "monitor": monitor,
      "widgets": {
        "left": widgets ?? []
      }
    };
  }

  function exampleNames() {
    tryVerify(() => examples.status === FolderListModel.Ready && examples.count > 0);
    const names = [];
    for (let i = 0; i < examples.count; i++)
      names.push(examples.get(i, "fileName"));
    return names;
  }

  function test_pick_takes_the_look_only() {
    const picked = shared.pick({
      "Appearance": {
        "theme": "dracula",
        "wallpaper": "/some/where.png"
      },
      "Bars": [bar("top", "DP-1")],
      "Calendar": {
        "accounts": []
      },
      "Keybinds": {
        "binds": [],
        "mode": "managed"
      },
      "WindowLook": {
        "gaps": true,
        "gapsOut": 12
      }
    }, schema);
    compare(picked, {
      "Appearance": {
        "theme": "dracula"
      },
      "Bars": [
        {
          "id": "top",
          "widgets": {
            "left": []
          }
        }
      ],
      "WindowLook": {
        "gaps": true,
        "gapsOut": 12
      }
    });
  }

  function test_pick_takes_personal_parts_when_asked() {
    const config = {
      "Apps": {
        "terminal": "foot"
      },
      "Keybinds": {
        "binds": [
          {
            "key": "SUPER + T",
            "action": "terminal"
          }
        ],
        "blur": true
      },
      "Dock": {
        "docks": [
          {
            "id": "main",
            "monitor": "DP-1",
            "pinned": ["kitty"]
          }
        ]
      }
    };
    compare(shared.pick(config, schema), {
      "Dock": {
        "docks": [
          {
            "id": "main"
          }
        ]
      }
    });
    compare(shared.pick(config, schema, ["personal"]), {
      "Apps": {},
      "Keybinds": {
        "binds": config.Keybinds.binds
      },
      "Dock": {
        "docks": [
          {
            "id": "main",
            "pinned": ["kitty"]
          }
        ]
      }
    });
    // The terminal runs: it's a command
    compare(shared.pick(config, schema, ["commands"]).Apps, {
      "terminal": "foot"
    });
  }

  // Each command field is in the commands scope, apart from the personal
  // parts: a file shared with its preferences runs nothing
  function test_command_fields_are_commands() {
    const scopes = [];
    const walk = (node, scope, path, depth) => {
      node = SchemaValidation.resolveRef(node, schema);
      if (!node || depth > 12)
        return;
      scope = node["x-scope"] ?? scope;
      if (/[cC]ommand$/.test(path[path.length - 1] ?? "") && node.type === "string")
        scopes.push(path.join(".") + " " + scope);
      for (const key in node.properties ?? {})
        walk(node.properties[key], scope, path.concat([key]), depth + 1);
      for (const option of node.oneOf ?? [])
        walk(option, scope, path, depth + 1);
      if (node.items)
        walk(node.items, scope, path.concat(["[]"]), depth + 1);
    };
    walk(schema, "machine", [], 0);
    verify(scopes.length > 10, scopes.length + " command fields");
    // Lockscreen.lockCommand and Session's autostart never travel at all
    compare(scopes.filter(line => !line.endsWith(" commands") && !line.endsWith(" machine")), []);
  }

  // An exec bind is a command: shared with the keybinds, it's left out,
  // and applying the keybinds keeps the user's own
  function test_exec_binds_are_commands() {
    const binds = [
      {
        "key": "SUPER + T",
        "action": "terminal"
      },
      {
        "key": "SUPER + X",
        "action": "exec",
        "argument": "theirs"
      }
    ];
    compare(shared.pick({
      "Keybinds": {
        "binds": binds
      }
    }, schema, ["personal"]).Keybinds.binds, [binds[0]]);
    compare(shared.pick({
      "Keybinds": {
        "binds": binds
      }
    }, schema, ConfigExamples.everything).Keybinds.binds, binds);
    const mine = {
      "key": "SUPER + M",
      "action": "raw",
      "argument": "mine"
    };
    const current = {
      "Keybinds": {
        "binds": [mine]
      }
    };
    const example = {
      "Keybinds": {
        "binds": binds
      }
    };
    compare(shared.apply(current, example, schema, ["personal"]).Keybinds.binds, [binds[0], mine]);
    compare(shared.apply(current, example, schema, ConfigExamples.everything).Keybinds.binds, binds);
    compare(shared.apply(current, example, schema).Keybinds.binds, [mine], "keybinds not taken at all");
  }

  // Saved keybind presets travel with the keybinds (personal), their exec
  // binds only with the commands
  function test_saved_presets_go_with_the_keybinds() {
    const binds = [
      {
        "key": "SUPER + T",
        "action": "terminal"
      },
      {
        "key": "SUPER + X",
        "action": "exec",
        "argument": "theirs"
      }
    ];
    const config = {
      "Keybinds": {
        "presets": [
          {
            "id": "a",
            "name": "Mine",
            "binds": binds
          }
        ]
      }
    };
    compare(shared.pick(config, schema).Keybinds, undefined, "a look leaves them out");
    compare(shared.pick(config, schema, ["personal"]).Keybinds.presets[0].binds, [binds[0]]);
    compare(shared.pick(config, schema, ConfigExamples.everything).Keybinds.presets[0].binds, binds);
  }

  // An app's OSD bar is personal: a look leaves it out, and applying one
  // keeps the user's after the example's bars
  function test_osd_app_bars_are_personal() {
    const osd = bars => ({
          "OSD": {
            "osds": [
              {
                "id": "main",
                "bars": bars
              }
            ]
          }
        });
    const master = {
      "type": "master"
    };
    const spotify = {
      "type": "app",
      "apps": ["spotify"]
    };
    compare(shared.pick(osd([master, spotify]), schema).OSD.osds[0].bars, [master]);
    compare(shared.pick(osd([master, spotify]), schema, ["personal"]).OSD.osds[0].bars, [master, spotify]);
    const firefox = {
      "type": "app",
      "apps": ["firefox"]
    };
    const brightness = {
      "type": "brightness"
    };
    const applied = shared.apply(osd([master, firefox]), osd([brightness, spotify]), schema);
    compare(applied.OSD.osds[0].bars.map(bar => bar.type), ["brightness", "app"]);
    compare(applied.OSD.osds[0].bars[1].apps, ["firefox"]);
  }

  function test_apply_replaces_parts_and_keeps_the_rest() {
    const current = {
      "Appearance": {
        "theme": "nord",
        "wallpaper": "/mine.png"
      },
      "EdgeMenus": [
        {
          "id": "old"
        },
        {
          "id": "older"
        }
      ],
      "Chat": {
        "providers": ["mine"]
      }
    };
    const result = shared.apply(current, {
      "Appearance": {
        "theme": "dracula",
        "wallpaper": "/theirs.png"
      },
      "EdgeMenus": [
        {
          "id": "new"
        }
      ],
      "Chat": {
        "providers": []
      }
    }, schema);
    compare(result.Appearance, {
      "theme": "dracula",
      "wallpaper": "/mine.png"
    });
    compare(result.EdgeMenus.length, 1);
    compare(result.EdgeMenus[0].id, "new");
    compare(result.Chat.providers, ["mine"]);
    // The input is left as it was
    compare(current.Appearance.theme, "nord");
  }

  function test_takeover_paths() {
    const paths = shared.takeoverPaths(schema).map(path => path.join("."));
    for (const path of ["Compositor.mode", "Lockscreen.mode", "Greeter.enabled", "Idle.enabled", "Polkit.enabled"])
      verify(paths.includes(path), path);
  }

  function test_keep_takeovers() {
    const current = defaults();
    current.Compositor.mode = "managed";
    current.Idle.enabled = true;
    current.Lockscreen.mode = "none";
    const loaded = defaults();
    loaded.Polkit.enabled = true;
    loaded.Workspaces.count = 4;
    const result = shared.keepTakeovers(loaded, current, shared.takeoverPaths(schema));
    compare(result.Compositor.mode, "managed");
    compare(result.Idle.enabled, true);
    compare(result.Lockscreen.mode, "none");
    compare(result.Polkit.enabled, false);
    // Everything else is the loaded config's, and the input is left as it was
    compare(result.Workspaces.count, 4);
    compare(loaded.Compositor.mode, "detached");
  }

  function test_pick_leaves_out_takeovers() {
    const lookSchema = {
      "type": "object",
      "properties": {
        "Section": {
          "type": "object",
          "x-scope": "look",
          "properties": {
            "mode": {
              "type": "string",
              "x-takeover": true
            },
            "size": {
              "type": "integer"
            }
          }
        }
      }
    };
    compare(shared.pick({
      "Section": {
        "mode": "managed",
        "size": 2
      }
    }, lookSchema), {
      "Section": {
        "size": 2
      }
    });
    compare(shared.takeoverPaths(lookSchema), [["Section", "mode"]]);
  }

  // A snapshot holds the look, the personal parts and the wallpaper setup;
  // restoring one (SavedConfigsManager.restore: save → load → apply →
  // withSnapshot) brings those back and leaves the other machine settings
  function test_snapshot_round_trips_and_keeps_machine_settings() {
    let saved = defaults();
    saved.Appearance.theme = "nord";
    saved.Appearance.wallpaper = "file:///walls/a%20b.png";
    saved.Appearance.wallpapers = {
      "DP-1": "file:///walls/a%20b.png",
      "HDMI-A-1": "file:///walls/gone.png"
    };
    saved.Appearance.variantWallpapers.dark = "file:///walls/night.png";
    saved.Bars = [bar("main", "DP-1")];
    saved.Keybinds.binds = [];
    // Filled, as a running config is
    saved = load(saved);
    const snapshot = shared.snapshot(saved, schema);
    compare(snapshot.Appearance.theme, "nord");
    compare(snapshot.Appearance.wallpaper, "file:///walls/a%20b.png");
    compare(snapshot.Keybinds.binds, []);
    verify(snapshot.ThemeIntegrations === undefined, "machine sections are left out");
    verify(snapshot.Compositor?.mode === undefined, "takeovers are left out");

    const current = defaults();
    current.ThemeIntegrations.kitty = true;
    current.Compositor.mode = "managed";
    current.Bars = [bar("main", "HDMI-A-1")];
    current.Appearance.wallpapers = {
      "HDMI-A-1": "file:///walls/mine.png"
    };
    const file = Object.assign({
      "version": ConfigMigration.currentVersion
    }, shared.sparse(snapshot, schema));
    const loaded = load(file);
    compare(shared.snapshotFiles(loaded, schema).sort(), ["/walls/a b.png", "/walls/gone.png", "/walls/night.png"]);
    const restored = shared.withSnapshot(shared.apply(current, loaded, schema, ConfigExamples.everything), loaded, schema, ["/walls/a b.png", "/walls/night.png"]);
    compare(restored.Appearance.theme, "nord");
    compare(restored.Keybinds.binds, []);
    compare(restored.ThemeIntegrations.kitty, true);
    compare(restored.Compositor.mode, "managed");
    compare(restored.Bars[0].monitor, "HDMI-A-1");
    compare(restored.Appearance.wallpaper, "file:///walls/a%20b.png");
    compare(restored.Appearance.wallpapers, {
      "DP-1": "file:///walls/a%20b.png",
      "HDMI-A-1": "file:///walls/mine.png"
    });
    compare(restored.Appearance.variantWallpapers.dark, "file:///walls/night.png");
    // What the modified dot compares: the saved file as it loads against
    // the config it was saved from, then a machine-only and a look change
    verify(Utils.deepEqual(shared.snapshot(loaded, schema), snapshot), "the saved file loads as saved");
    const machineEdit = Utils.clone(restored);
    machineEdit.ThemeIntegrations.gtk = !machineEdit.ThemeIntegrations.gtk;
    verify(Utils.deepEqual(shared.snapshot(machineEdit, schema), shared.snapshot(restored, schema)));
    machineEdit.Appearance.theme = "dracula";
    verify(!Utils.deepEqual(shared.snapshot(machineEdit, schema), shared.snapshot(restored, schema)));
  }

  // An older whole-config snapshot restores the same way: only its scoped
  // parts and wallpapers
  function test_whole_config_snapshot_keeps_machine_settings() {
    const old = defaults();
    old.ThemeIntegrations.kitty = false;
    old.Appearance.theme = "nord";
    const current = defaults();
    current.ThemeIntegrations.kitty = true;
    const restored = shared.withSnapshot(shared.apply(current, old, schema, ConfigExamples.everything), old, schema, []);
    compare(restored.ThemeIntegrations.kitty, true);
    compare(restored.Appearance.theme, "nord");
  }

  // The wallpaper setup comes back whole: a snapshot saved in fixed mode
  // turns rotation off again, and its schedule and rotation settings return
  function test_snapshot_restores_the_wallpaper_setup() {
    const saved = load(defaults());
    saved.Appearance.wallpaper = "file:///walls/fixed.png";
    const current = defaults();
    current.Appearance.wallpaperMode = "rotate";
    current.Appearance.wallpaperRotation.interval = 5;
    current.Appearance.themeSchedule.enabled = true;
    current.Appearance.variantWallpapers.light = "file:///walls/day.png";
    verify(!Utils.deepEqual(shared.snapshot(current, schema), shared.snapshot(saved, schema)), "a mode switch is a change");
    const restored = shared.withSnapshot(shared.apply(current, saved, schema, ConfigExamples.everything), saved, schema, ["/walls/fixed.png"]);
    compare(restored.Appearance.wallpaperMode, "fixed");
    compare(restored.Appearance.wallpaperRotation.interval, saved.Appearance.wallpaperRotation.interval);
    compare(restored.Appearance.themeSchedule.enabled, false);
    compare(restored.Appearance.wallpaper, "file:///walls/fixed.png");
    compare(restored.Appearance.variantWallpapers.light, "file:///walls/day.png", "a wallpaper is never blanked");
    const missing = shared.withSnapshot(current, saved, schema, []);
    compare(missing.Appearance.wallpaper, current.Appearance.wallpaper, "a missing file keeps the current one");
  }

  function test_snapshot_paths() {
    compare(shared.snapshotPaths(schema).map(path => path.join(".")).sort(), ["Appearance.variantWallpapers", "Appearance.wallpaper", "Appearance.wallpaperFolder", "Appearance.wallpaperMode", "Appearance.wallpaperRotation", "Appearance.wallpapers"]);
  }

  function test_snapshot_files() {
    compare(shared.snapshotFiles({
      "Appearance": {
        "wallpaper": "",
        "wallpapers": {
          "A": "file:///x.png",
          "B": "file:///x.png",
          "C": "relative.png"
        },
        "wallpaperFolder": "~/Pictures"
      }
    }, schema), ["/x.png"]);
    compare(shared.snapshotFiles({}, schema), []);
  }

  function test_apply_keeps_monitors_by_id_then_position() {
    const current = {
      "Bars": [bar("main", "DP-1"), bar("side", "HDMI-A-1")]
    };
    const result = shared.apply(current, {
      "Bars": [bar("side", "eDP-1"), bar("theirs", "eDP-2"), bar("third", "eDP-3")]
    }, schema);
    // "side" by its id, "theirs" by its position, "third" has neither
    compare(result.Bars.map(b => b.monitor), ["HDMI-A-1", "HDMI-A-1", ""]);
  }

  function test_monitor_order() {
    compare(shared.monitorOrder([
      {
        "name": "B",
        "x": 1920,
        "y": 0
      },
      {
        "name": "C",
        "x": 0,
        "y": 1080
      },
      {
        "name": "A",
        "x": 0,
        "y": 0
      }
    ]), ["A", "C", "B"]);
  }

  // Shared, a monitor is written by its place, and applying it puts it on
  // the user's monitor in that place: a part for a monitor they don't
  // have is turned off, or left out where it can't be
  function test_monitors_travel_by_place() {
    const author = ["DP-1", "HDMI-A-1"];
    const config = {
      "Bars": [bar("main", ""), bar("side", "HDMI-A-1"), bar("every", "*"), bar("gone", "DP-9")],
      "Workspaces": {
        "strips": [
          {
            "monitor": "HDMI-A-1",
            "direction": "vertical"
          }
        ]
      },
      "Desktop": {
        "monitors": [
          {
            "monitor": "HDMI-A-1",
            "columns": 8
          }
        ]
      }
    };
    const picked = shared.pick(config, schema, [], author);
    compare(picked.Bars.map(b => b.monitor), ["@primary", "#2", "*", undefined]);
    compare(picked.Workspaces.strips[0].monitor, "#2");
    compare(picked.Desktop.monitors[0].monitor, "#2");
    verify(shared.pick(config, schema).Bars[1].monitor === undefined, "without the monitors, names stay out");

    const file = load(Object.assign({
      "version": ConfigMigration.currentVersion
    }, picked));
    // Two monitors: the second is the user's second
    const two = shared.apply(defaults(), file, schema, [], ["eDP-1", "DP-2"]);
    compare(two.Bars.map(b => [b.monitor, b.enabled]), [["", true], ["DP-2", true], ["*", true], ["", true]]);
    compare(two.Workspaces.strips.map(s => s.monitor), ["DP-2"]);
    compare(two.Desktop.monitors.map(m => m.monitor), ["DP-2"]);
    // One: the second monitor's bar is off, its strip and desktop left out
    const one = shared.apply(defaults(), file, schema, [], ["eDP-1"]);
    compare(one.Bars.map(b => b.enabled), [true, false, true, true]);
    compare(one.Workspaces.strips, []);
    compare(one.Desktop.monitors, []);
    compare(SchemaValidation.validationErrors(one, schema), []);
  }

  function test_apply_takes_personal_values_only_when_asked() {
    const button = command => ({
          "type": "Button",
          "properties": {
            "icon": "terminal",
            "command": command
          }
        });
    const current = {
      "Bars": [bar("main", "DP-1", [button("mine")])],
      "Dock": {
        "docks": [
          {
            "id": "main",
            "pinned": ["kitty"]
          }
        ]
      },
      "Keybinds": {
        "binds": [
          {
            "key": "SUPER + T",
            "action": "terminal"
          }
        ]
      }
    };
    const example = {
      "Bars": [bar("main", "", [button("theirs")])],
      "Dock": {
        "docks": [
          {
            "id": "main",
            "pinned": ["firefox"]
          },
          {
            "id": "second",
            "pinned": ["gimp"]
          }
        ]
      },
      "Keybinds": {
        "binds": []
      }
    };
    const kept = shared.apply(current, example, schema);
    // The bar matched by id, its button as the first button: the user's
    // command stays, the example's isn't taken
    compare(kept.Bars[0].widgets.left[0].properties.command, "mine");
    compare(kept.Bars[0].monitor, "DP-1");
    compare(kept.Dock.docks.map(d => d.pinned), [["kitty"], []]);
    compare(kept.Keybinds.binds, current.Keybinds.binds);

    const personal = shared.apply(current, example, schema, ["personal"]);
    compare(personal.Bars[0].widgets.left[0].properties.command, "mine", "a command comes only with the commands");
    compare(personal.Dock.docks.map(d => d.pinned), [["firefox"], ["gimp"]]);

    const taken = shared.apply(current, example, schema, ConfigExamples.everything);
    compare(taken.Bars[0].widgets.left[0].properties.command, "theirs");
    compare(taken.Bars[0].monitor, "DP-1");
    compare(taken.Dock.docks.map(d => d.pinned), [["firefox"], ["gimp"]]);
    compare(taken.Keybinds.binds, []);
  }

  function test_apply_drops_values_of_another_type() {
    const result = shared.apply({
      "Bars": [bar("main", "DP-1", [
          {
            "type": "SystemStats",
            "properties": {
              "diskPath": "/home"
            }
          }
        ])]
    }, {
      "Bars": [bar("main", "", [
          {
            "type": "Time",
            "properties": {}
          }
        ])]
    }, schema);
    compare(result.Bars[0].widgets.left[0], {
      "type": "Time",
      "properties": {}
    });
  }

  function test_apply_matches_widgets_by_type() {
    const stats = path => ({
          "type": "SystemStats",
          "properties": {
            "diskPath": path
          }
        });
    const time = {
      "type": "Time",
      "properties": {}
    };
    const current = {
      "Bars": [bar("main", "DP-1", [stats("/home"), time, stats("/data")])]
    };
    // Moved behind another widget: still the first and second SystemStats
    const result = shared.apply(current, {
      "Bars": [bar("main", "", [time, stats("/theirs"), time, stats("/theirs")])]
    }, schema);
    compare(result.Bars[0].widgets.left.map(w => w.properties.diskPath), [undefined, "/home", undefined, "/data"]);
    // A third of a type the user has two of gets the default
    const more = shared.apply(current, {
      "Bars": [bar("main", "", [stats(""), stats(""), stats("")])]
    }, schema);
    compare(more.Bars[0].widgets.left.map(w => w.properties.diskPath), ["/home", "/data", "/"]);
  }

  function test_keep_moved_keys() {
    const current = {
      "WindowLook": {
        "shape": true,
        "rounding": 3,
        "shadow": true,
        "shadowSize": 7,
        "dim": true,
        "borders": true
      }
    };
    const file = {
      "WindowLook": {
        "shape": false,
        "rounding": 8,
        "shadow": false,
        "shadowSize": 10,
        "dim": false,
        "borders": false
      }
    };
    compare(shared.keepMovedKeys(file, {}, current, 49).WindowLook, {
      "shape": true,
      "rounding": 3,
      "shadow": true,
      "shadowSize": 7,
      "dim": true,
      "borders": false
    }, "a file older than v58 never held any of them");
    const v60 = shared.keepMovedKeys(file, {}, current, 60).WindowLook;
    compare([v60.shape, v60.rounding, v60.shadow, v60.dim], [false, 8, true, true], "the shape is the file's since v58");
    compare(shared.keepMovedKeys(file, {}, current, 63), file, "the file's own since v63");
    compare(file.WindowLook.shadow, false, "the file is left as it was");
    const held = shared.keepMovedKeys(file, {
      "WindowLook": {
        "rounding": 8
      }
    }, current, 49).WindowLook;
    compare([held.shape, held.rounding], [true, 8], "what an older file holds is its own");
  }

  // Settings carried since v71 (the launcher's look, notification and
  // input preferences, …): an older export never held them, so applying
  // one keeps the user's instead of putting the defaults in
  function test_older_files_keep_settings_carried_since_v71() {
    const user = defaults();
    user.Launcher.width = 900;
    user.Notifications.timeout = 9;
    user.Input.kbLayout = "de";
    user.Appearance.themeSchedule.enabled = true;
    const v70 = {
      "version": 70,
      "Appearance": {
        "theme": "nord"
      }
    };
    const loaded = shared.keepMovedKeys(load(v70), shared.migrate(v70).config, user, 70);
    const applied = shared.apply(user, loaded, schema);
    compare([applied.Launcher.width, applied.Notifications.timeout, applied.Appearance.themeSchedule.enabled, applied.Appearance.theme], [900, 9, true, "nord"]);
    compare(shared.apply(user, loaded, schema, ["personal"]).Input.kbLayout, "de");
    // A file of this version holds them, its defaults included
    const now = load({
      "version": ConfigMigration.currentVersion
    });
    compare(shared.apply(user, now, schema).Launcher.width, 680);
  }

  function test_sparse_defaults_are_empty() {
    compare(shared.sparse(defaults(), schema), {});
  }

  function test_examples_exist() {
    verify(exampleNames().length > 0);
  }

  function test_examples_are_valid() {
    for (const name of exampleNames()) {
      const example = files.json("examples/" + name);
      verify(example._example?.title, name + " has a title");
      const errors = SchemaValidation.validationErrors(load(example), schema);
      compare(errors, [], name);
      // Applied onto the defaults, it is still a valid config
      const applied = shared.apply(defaults(), load(example), schema);
      compare(SchemaValidation.validationErrors(applied, schema), [], name + " applied");
    }
  }

  // An example holds only what applying one takes (look and personal parts)
  function test_examples_hold_only_shared_parts() {
    for (const name of exampleNames()) {
      const example = files.json("examples/" + name);
      const parts = Utils.clone(example);
      delete parts._example;
      delete parts.version;
      compare(shared.pick(parts, schema, ConfigExamples.everything), parts, name);
    }
  }

  // Export (pick → sparse) and import (load → apply) give back what applying
  // the whole config would: look only and with personal parts, onto the
  // defaults and onto a user's own config (whose machine and personal values
  // aren't the defaults). SavedConfigsManager.exportConfig relies on it.
  function test_export_round_trips() {
    const user = load(files.json("tests/fixtures/configs/v1.json"));
    const sources = exampleNames().map(name => ({
          "name": name,
          "config": shared.apply(user, load(files.json("examples/" + name)), schema, ConfigExamples.everything)
        })).concat([
      {
        "name": "v1.json",
        "config": user
      }
    ]);
    for (const source of sources) {
      for (const carry of [[], ["personal"], ["commands"], ConfigExamples.everything]) {
        const label = `${source.name} with ${carry.join(", ") || "the look"}`;
        const exported = shared.sparse(shared.pick(source.config, schema, carry), schema);
        exported.version = ConfigMigration.currentVersion;
        for (const current of [defaults(), user])
          verify(Utils.deepEqual(shared.apply(current, load(exported), schema, carry), shared.apply(current, source.config, schema, carry)), label + " imported");
      }
    }
  }

  // Older configs import too: a v1 config migrates, then applies
  function test_old_config_imports() {
    const old = load(files.json("tests/fixtures/configs/v1.json"));
    verify(old !== null);
    const applied = shared.apply(defaults(), old, schema);
    compare(SchemaValidation.validationErrors(applied, schema), []);
  }
}
