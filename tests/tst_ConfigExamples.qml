import QtQuick
import QtTest
import Qt.labs.folderlistmodel
import qs.components.methods

// ConfigExamples (what a shared config holds, by the schema's x-scope, and
// how it applies), and the shipped examples/*.json: each loads as a valid
// config the way SavedConfigsManager loads it, so an example can't rot when
// the schema moves.
TestCase {
  name: "ConfigExamples"

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
    schema = files.json("config/json/config.schema.json");
  }

  // ConfigManager.normalizeConfig: migrate → prune → defaults
  function load(parsed) {
    const config = ConfigMigration.migrate(Utils.clone(parsed)).config;
    SchemaValidation.pruneUnknown(config, schema);
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
    const picked = ConfigExamples.pick({
      "Appearance": {
        "theme": "dracula",
        "wallpaper": "/some/where.png"
      },
      "Bars": [bar("top", "DP-1")],
      "Calendar": {
        "accounts": []
      },
      "Hyprland": {
        "binds": [],
        "blur": true,
        "look": {
          "gaps": true,
          "gapsOut": 12
        }
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
      "Hyprland": {
        "look": {
          "gaps": true,
          "gapsOut": 12
        }
      }
    });
  }

  function test_pick_takes_personal_parts_when_asked() {
    const config = {
      "Apps": {
        "terminal": "foot"
      },
      "Hyprland": {
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
    compare(ConfigExamples.pick(config, schema), {
      "Dock": {
        "docks": [
          {
            "id": "main"
          }
        ]
      }
    });
    compare(ConfigExamples.pick(config, schema, true), {
      "Apps": {
        "terminal": "foot"
      },
      "Hyprland": {
        "binds": config.Hyprland.binds
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
    const result = ConfigExamples.apply(current, {
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
    const paths = ConfigExamples.takeoverPaths(schema).map(path => path.join("."));
    for (const path of ["Hyprland.mode", "Lockscreen.mode", "Greeter.enabled", "Idle.enabled", "Polkit.enabled"])
      verify(paths.includes(path), path);
  }

  function test_keep_takeovers() {
    const current = defaults();
    current.Hyprland.mode = "managed";
    current.Idle.enabled = true;
    current.Lockscreen.mode = "hyprlock";
    const loaded = defaults();
    loaded.Polkit.enabled = true;
    loaded.Workspaces.count = 4;
    const result = ConfigExamples.keepTakeovers(loaded, current, ConfigExamples.takeoverPaths(schema));
    compare(result.Hyprland.mode, "managed");
    compare(result.Idle.enabled, true);
    compare(result.Lockscreen.mode, "hyprlock");
    compare(result.Polkit.enabled, false);
    // Everything else is the loaded config's, and the input is left as it was
    compare(result.Workspaces.count, 4);
    compare(loaded.Hyprland.mode, "detached");
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
    compare(ConfigExamples.pick({
      "Section": {
        "mode": "managed",
        "size": 2
      }
    }, lookSchema), {
      "Section": {
        "size": 2
      }
    });
    compare(ConfigExamples.takeoverPaths(lookSchema), [["Section", "mode"]]);
  }

  function test_equal_apart_from_takeovers() {
    const paths = ConfigExamples.takeoverPaths(schema);
    const saved = defaults();
    const running = defaults();
    verify(ConfigExamples.equalApartFrom(running, saved, paths));
    running.Hyprland.mode = "managed";
    running.Idle.enabled = true;
    verify(ConfigExamples.equalApartFrom(running, saved, paths), "takeovers differ");
    verify(!ConfigExamples.equalApartFrom(running, saved, []), "no paths left out");
    running.Hyprland.requiredSettings = !saved.Hyprland.requiredSettings;
    verify(!ConfigExamples.equalApartFrom(running, saved, paths), "a sibling of a takeover differs");
    const other = defaults();
    other.Workspaces.count = saved.Workspaces.count + 1;
    verify(!ConfigExamples.equalApartFrom(other, saved, paths));
    // Agrees with comparing against keepTakeovers' copy
    for (const config of [running, other])
      compare(ConfigExamples.equalApartFrom(config, saved, paths), Utils.deepEqual(config, ConfigExamples.keepTakeovers(saved, config, paths)));
  }

  function test_apply_keeps_monitors_by_id_then_position() {
    const current = {
      "Bars": [bar("main", "DP-1"), bar("side", "HDMI-A-1")]
    };
    const result = ConfigExamples.apply(current, {
      "Bars": [bar("side", "eDP-1"), bar("theirs", "eDP-2"), bar("third", "eDP-3")]
    }, schema);
    // "side" by its id, "theirs" by its position, "third" has neither
    compare(result.Bars.map(b => b.monitor), ["HDMI-A-1", "HDMI-A-1", ""]);
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
      "Hyprland": {
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
      "Hyprland": {
        "binds": []
      }
    };
    const kept = ConfigExamples.apply(current, example, schema);
    // The bar matched by id, its widgets only by position: the command is
    // neither the example's nor (for another button) the user's
    compare(kept.Bars[0].widgets.left[0].properties.command, "");
    compare(kept.Bars[0].monitor, "DP-1");
    compare(kept.Dock.docks.map(d => d.pinned), [["kitty"], []]);
    compare(kept.Hyprland.binds, current.Hyprland.binds);

    const taken = ConfigExamples.apply(current, example, schema, true);
    compare(taken.Bars[0].widgets.left[0].properties.command, "theirs");
    compare(taken.Bars[0].monitor, "DP-1");
    compare(taken.Dock.docks.map(d => d.pinned), [["firefox"], ["gimp"]]);
    compare(taken.Hyprland.binds, []);
  }

  function test_apply_drops_values_of_another_type() {
    const result = ConfigExamples.apply({
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

  function test_sparse_defaults_are_empty() {
    compare(ConfigExamples.sparse(defaults(), schema), {});
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
      const applied = ConfigExamples.apply(defaults(), load(example), schema);
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
      compare(ConfigExamples.pick(parts, schema, true), parts, name);
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
          "config": ConfigExamples.apply(user, load(files.json("examples/" + name)), schema, true)
        })).concat([
      {
        "name": "v1.json",
        "config": user
      }
    ]);
    for (const source of sources) {
      for (const personal of [false, true]) {
        const label = `${source.name}${personal ? " with personal parts" : ""}`;
        const exported = ConfigExamples.sparse(ConfigExamples.pick(source.config, schema, personal), schema);
        exported.version = ConfigMigration.currentVersion;
        for (const current of [defaults(), user])
          verify(Utils.deepEqual(ConfigExamples.apply(current, load(exported), schema, personal), ConfigExamples.apply(current, source.config, schema, personal)), label + " imported");
      }
    }
  }

  // Older configs import too: a v1 config migrates, then applies
  function test_old_config_imports() {
    const old = load(files.json("tests/fixtures/configs/v1.json"));
    verify(old !== null);
    const applied = ConfigExamples.apply(defaults(), old, schema);
    compare(SchemaValidation.validationErrors(applied, schema), []);
  }
}
