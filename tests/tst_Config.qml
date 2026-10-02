import QtQuick
import QtTest
import qs.components.methods

// The real schema and ConfigMigration together: the defaults are a valid
// config, every oneOf variant's defaults are valid, and old configs load
// the way ConfigManager loads them (migrate → prune → defaults → validate).
TestCase {
  name: "Config"

  RepoFiles {
    id: files
  }

  property var schema

  function initTestCase() {
    schema = files.json("config/json/config.schema.json");
  }

  function errors(value, subSchema) {
    return SchemaValidation.validationErrors(value, subSchema ?? schema);
  }

  // What ConfigManager does with a parsed config.json
  function load(parsed) {
    const migration = ConfigMigration.migrate(parsed);
    const config = migration.config;
    const removed = SchemaValidation.pruneUnknown(config, schema);
    return {
      config: SchemaValidation.applyDefaults(config, schema),
      removed: removed,
      changes: migration.changes
    };
  }

  function test_version_matches_schema() {
    compare(ConfigMigration.currentVersion, schema.properties.version.default);
  }

  function test_defaults_are_valid() {
    compare(errors(SchemaValidation.applyDefaults({}, schema)), []);
  }

  function test_empty_config_loads() {
    const loaded = load({});
    compare(errors(loaded.config), []);
    compare(loaded.config.version, ConfigMigration.currentVersion);
  }

  function test_every_variant_default_is_valid_data() {
    const rows = [];
    for (const union of ["BarWidget", "OverlayModule", "OverlayView"]) {
      for (const option of schema.definitions[union].oneOf) {
        const name = option.$ref.split("/").pop();
        const type = schema.definitions[name].properties.type.const;
        rows.push({
          tag: union + ":" + type,
          union: union,
          type: type
        });
      }
    }
    return rows;
  }

  function test_every_variant_default_is_valid(data) {
    const unionSchema = {
      "$ref": "#/definitions/" + data.union
    };
    SchemaValidation._ctx.root = schema;
    const filled = SchemaValidation.applyDefaults({
      "type": data.type
    }, unionSchema, schema);
    compare(filled.type, data.type);
    // validationErrors takes the root schema for $refs, so wrap the value
    const wrapped = Object.assign({}, schema, {
      "type": "object",
      "properties": {
        "value": unionSchema
      },
      "additionalProperties": false,
      "required": []
    });
    compare(SchemaValidation.validationErrors({
      "value": filled
    }, wrapped), []);
  }

  function test_edge_menu_defaults_are_valid() {
    const menuSchema = schema.definitions.EdgeMenu;
    const filled = SchemaValidation.applyDefaults({
      "id": "test"
    }, menuSchema, schema);
    const wrapped = Object.assign({}, schema, {
      "type": "object",
      "properties": {
        "menu": {
          "$ref": "#/definitions/EdgeMenu"
        }
      },
      "additionalProperties": false,
      "required": []
    });
    compare(SchemaValidation.validationErrors({
      "menu": filled
    }, wrapped), []);
  }

  function test_v1_config_migrates_to_a_valid_one() {
    const loaded = load(files.json("tests/fixtures/configs/v1.json"));
    const config = loaded.config;
    compare(errors(config), []);
    compare(loaded.removed, []);
    compare(config.version, ConfigMigration.currentVersion);

    // v2 + v8: the old Workspaces widget was the grid, now the grid layout
    const left = config.Bars[0].widgets.left;
    compare(left[0].type, "Workspaces");
    compare(left[0].properties.textColor, "base0D");
    compare(config.Workspaces.layout, "grid");
    // v3 + v21: the bar's inset keeps its widgets 26 px high
    compare(config.Bars[0].widgetSize, 26);
    compare(config.Bars[0].padding, 4);
    compare(config.Bars[0].extent, undefined);
    // v4, v6
    compare(config.Appearance.autoThemeSwitch, undefined);
    compare(config.General.monitors, "focused");
    // v9: an old default glyph becomes its Material Symbols name
    compare(left[1].properties.icon, "apps");
    // v10: the grid popout's icons move onto the widget
    compare(config.Popouts.workspaceIcons, undefined);
    compare(left[0].properties.showAppIcons, true);
    // v5, v7, v13, v18: the pages that became (or were added as) views
    const types = config.Overlay.views.map(view => view.type);
    compare(types[0], "Settings");
    verify(types.includes("Themes"));
    // v31: the edge menu editor became part of the pinned Layouts page
    verify(!types.includes("EdgeMenuEditor"));
    verify(types.includes("Monitors"));
    // v11: backends become providers, keeping a model the user added
    compare(config.Chat.defaultProvider, "anthropic");
    const anthropic = config.Chat.providers.find(p => p.id === "anthropic");
    verify(anthropic.models.includes("my-own-model"));
    // v12: QuickToggles and Session become QuickActions
    const modules = config.Overlay.views[1].modules;
    compare(modules[0].type, "QuickActions");
    compare(modules[1].properties.actions, ["lock", "reboot"]);
    // v14: the Network widget no longer polls
    const network = config.Bars[0].widgets.right[0];
    compare(network.type, "Network");
    compare(network.properties.interval, undefined);
    compare(network.properties.showName, true);
    // v15: OSD apps become typed bars; v24: the OSD becomes the first of
    // several
    compare(config.OSD.apps, undefined);
    compare(config.OSD.bars, undefined);
    compare(config.OSD.osds.length, 1);
    const osd = config.OSD.osds[0];
    compare(osd.id, "main");
    compare(osd.placement, "edge");
    compare(osd.bars.map(bar => bar.type), ["app", "other", "master"]);
    // v29: an App bar's app becomes a list
    compare(osd.bars[0].app, undefined);
    compare(osd.bars[0].apps, ["spotify"]);
    compare(osd.bars[0].showOsd, false);
    compare(osd.bars[1].apps, []);
    // v16: an edge menu's extraDepth becomes the size across its edge;
    // v31: which is dropped with its card size (menus use the overlay's)
    compare(config.EdgeMenus[0].extraDepth, undefined);
    compare(config.EdgeMenus[0].extraWidth, undefined);
    compare(config.EdgeMenus[0].cardSize, undefined);
    compare(config.EdgeMenus[1].extraHeight, undefined);
    compare(config.EdgeMenus[1].cardSize, undefined);
    // v17: a Notes module's name becomes the Markdown file it moved to
    compare(modules[2].properties.name, undefined);
    compare(modules[2].properties.note, "my_list.md");
    compare(modules[3].properties.note, "");
    compare(modules[3].properties.lockNote, false);
    // v18: no monitor profiles until the Monitors page saves one
    compare(config.Hyprland.monitors.profiles, []);
    // v31: a column's cells become modules placed down the grid; empty
    // cells leave nothing behind
    compare(config.Overlay.views[1].columns, undefined);
    compare(modules.length, 4);
    compare(modules.map(m => [m.place.x, m.place.y, m.place.w, m.place.h]), [[0, 0, 4, 4], [0, 4, 4, 4], [0, 8, 4, 4], [0, 12, 4, 4]]);
  }

  function test_v20_adds_app_binds_on_free_keys() {
    const result = ConfigMigration.migrate({
      "version": 19,
      "Hyprland": {
        "binds": [
          {
            "key": "SUPER + RETURN",
            "action": "exec",
            "argument": "foot"
          }
        ]
      }
    });
    const binds = result.config.Hyprland.binds;
    // The user's own SUPER + Return stays; the rest are added once
    compare(binds.filter(bind => bind.action === "terminal").length, 0);
    compare(binds[0].argument, "foot");
    // (v22 adds SUPER + CTRL + S)
    compare(binds.filter(bind => bind.action === "screenshot").length, 4);
    compare(binds.filter(bind => bind.action === "exitHyprland").length, 1);
    compare(ConfigMigration.migrate(result.config).config.Hyprland.binds.length, binds.length);
  }

  function test_v28_adds_wasd_binds_on_free_keys() {
    const result = ConfigMigration.migrate({
      "version": 27,
      "Hyprland": {
        "binds": [
          {
            "key": "SUPER + A",
            "action": "exec",
            "argument": "pavucontrol"
          }
        ]
      }
    });
    const binds = result.config.Hyprland.binds;
    // The user's own SUPER + A stays; the other seven are added once (and
    // v38's three)
    compare(binds.length, 11);
    compare(binds[0].argument, "pavucontrol");
    compare(binds.filter(bind => bind.action === "workspaceStep").map(bind => bind.argument).sort(), ["down", "right", "up"]);
    compare(binds.filter(bind => bind.action === "moveWindowStep").length, 4);
    compare(ConfigMigration.migrate(result.config).config.Hyprland.binds.length, binds.length);
  }

  function test_v26_moves_pywal_themes_to_tonal() {
    const migrate = theme => ConfigMigration.migrate({
        "version": 25,
        "Appearance": {
          "theme": theme
        }
      }).config.Appearance.theme;
    compare(migrate("generated/pywal-dark-colorthief"), "generated/wallpaper-tonal-dark");
    compare(migrate("generated/pywal-light-wal"), "generated/wallpaper-tonal-light");
    compare(migrate("generated/pywal-dark"), "generated/wallpaper-tonal-dark");
    compare(migrate("gruvbox-dark"), "gruvbox-dark");
  }

  function test_v27_bars_keep_widget_sizing() {
    const config = ConfigMigration.migrate({
      "version": 26,
      "Widget": {
        "padding": 7,
        "spacing": 3
      },
      "Bars": [
        {
          "id": "a"
        },
        {
          "id": "b",
          "widgetPadding": 12
        }
      ]
    }).config;
    compare(config.Bars[0].widgetPadding, 7);
    compare(config.Bars[0].widgetSpacing, 3);
    compare(config.Bars[1].widgetPadding, 12);
    compare(config.Bars[1].widgetSpacing, 3);
    // Left out of Widget: the bar gets the schema default
    const plain = ConfigMigration.migrate({
      "version": 26,
      "Bars": [
        {
          "id": "a"
        }
      ]
    }).config;
    compare(plain.Bars[0].widgetPadding, undefined);
  }

  function test_v23_moves_apps_out_of_launcher() {
    const loaded = load({
      "version": 22,
      "Launcher": {
        "terminal": "foot",
        "browser": "firefox",
        "width": 700
      }
    });
    compare(loaded.config.Apps.terminal, "foot");
    compare(loaded.config.Apps.browser, "firefox");
    compare(loaded.config.Apps.fileManager, "");
    compare(loaded.config.Launcher.terminal, undefined);
    compare(loaded.config.Launcher.width, 700);
    compare(errors(loaded.config), []);
  }

  function test_v25_edge_menus_follow_popout_padding() {
    const loaded = load({
      "version": 24,
      "EdgeMenus": [
        {
          "id": "old",
          "padding": 12
        },
        {
          "id": "own",
          "padding": 20
        }
      ]
    });
    compare(loaded.config.EdgeMenus[0].padding, -1);
    compare(loaded.config.EdgeMenus[1].padding, 20);
    compare(errors(loaded.config), []);
  }

  function test_v30_moves_battery_levels_and_renames_keys() {
    const loaded = load({
      "version": 29,
      "Bars": [
        {
          "id": "a",
          "widgets": {
            "left": [
              {
                "type": "Battery",
                "properties": {
                  "notify": false,
                  "lowThreshold": 30,
                  "lowColor": "base09"
                }
              },
              {
                "type": "Battery",
                "properties": {
                  "notify": true,
                  "criticalThreshold": 5
                }
              },
              {
                "type": "ClaudeUsage",
                "properties": {
                  "warnPercent": 60,
                  "critPercent": 80,
                  "critColor": "base0A"
                }
              },
              {
                "type": "Privacy",
                "properties": {
                  "ignoreApps": "cava, easyeffects,,"
                }
              }
            ]
          }
        }
      ],
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "columns": [
              {
                "cells": [
                  {
                    "layout": "Tall",
                    "slots": {
                      "main": {
                        "type": "ClockCalendar",
                        "properties": {
                          "use24h": false
                        }
                      }
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    });
    const config = loaded.config;
    // The first widget's settings win; the second only adds what's left
    compare([config.Battery.notify, config.Battery.lowThreshold, config.Battery.criticalThreshold], [false, 30, 5]);
    const left = config.Bars[0].widgets.left;
    compare(left[0].properties.lowThreshold, undefined);
    compare(left[0].properties.notify, undefined);
    compare(left[0].properties.lowColor, "base09");
    compare(left[1].properties.criticalThreshold, undefined);
    compare([left[2].properties.warnThreshold, left[2].properties.criticalThreshold, left[2].properties.criticalColor], [60, 80, "base0A"]);
    compare(left[2].properties.critPercent, undefined);
    compare(left[3].properties.ignoreApps, ["cava", "easyeffects"]);
    compare(config.Overlay.views[0].modules[0].properties.use24Hour, false);
    compare(loaded.removed, []);
    compare(errors(config), []);
  }

  function place(module) {
    return [module.place.x, module.place.y, module.place.w, module.place.h];
  }

  function test_v31_places_modules_on_a_grid() {
    const loaded = load(files.json("tests/fixtures/configs/v30.json"));
    const config = loaded.config;
    compare(loaded.removed, []);
    compare(errors(config), []);
    const views = config.Overlay.views;
    compare(views.map(view => view.type), ["Custom", "Settings", "BarEditor", "Themes", "Keybinds", "Monitors"]);
    // Columns side by side, each flowing its cells, slots within them
    const home = views[0];
    compare(home.columns, undefined);
    const at = type => home.modules.filter(m => m.type === type).map(place);
    compare(at("ClockCalendar"), [[0, 0, 4, 8]]);
    compare(at("QuickActions"), [[4, 0, 4, 2], [4, 2, 4, 2]]);
    compare(at("SystemGraphs"), [[4, 4, 4, 4]]);
    compare(at("NowPlaying"), [[8, 0, 8, 4]]);
    compare(at("AudioMixer"), [[8, 4, 4, 4]]);
    compare(at("Network"), [[12, 4, 4, 2]]);
    compare(at("Favourites"), [[12, 6, 2, 2]]);
    compare(at("Screenshot"), [[14, 6, 2, 2]]);
    compare(at("Notifications"), [[16, 0, 4, 4]]);
    compare(at("Weather"), [[16, 4, 4, 2]]);
    compare(at("Disks"), [[16, 6, 4, 2]]);
    compare(home.modules.find(m => m.type === "Disks").properties.paths, ["/", "/home"]);

    const menus = config.EdgeMenus;
    // A cell filling along a left edge: the menu takes the whole edge
    const left = menus[0];
    compare(left.columns, undefined);
    compare(left.length, "edge");
    compare(left.modules.map(m => [m.type].concat(place(m))), [["NowPlaying", 0, 2, 4, 2], ["QuickActions", 0, 0, 4, 2], ["ClockCalendar", 0, 4, 4, 4]]);
    // The extra width across a right edge is dropped with the card size
    const right = menus[1];
    compare(right.length, "edge");
    compare(right.cardSize, undefined);
    compare(right.extraWidth, undefined);
    compare(right.modules.map(m => [m.type].concat(place(m))), [["NowPlaying", 0, 0, 4, 2], ["Chat", 0, 2, 4, 8], ["QuickActions", 0, 10, 4, 2]]);
    // Two Talls side by side on a top edge, 8 quarter units thick
    compare(menus[2].length, "content");
    compare(menus[2].cardSize, undefined);
    compare(menus[2].modules.map(place), [[0, 0, 4, 8], [4, 0, 4, 8]]);
    verify(loaded.changes.some(change => change.includes("(200 px) dropped")));
    verify(loaded.changes.some(change => change.includes("card size (395 px) dropped")));
  }

  function test_v31_pin_modules_become_a_pin_button() {
    const loaded = load({
      "version": 30,
      "EdgeMenus": [
        {
          "id": "m",
          "edge": "Bottom",
          "columns": [
            {
              "cells": [
                {
                  "layout": "Horiz1x2",
                  "fillWidth": true,
                  "slots": {
                    "top": {
                      "type": "NowPlaying"
                    },
                    "bottomRight": {
                      "type": "Pin"
                    }
                  }
                }
              ]
            }
          ]
        }
      ]
    });
    const menu = loaded.config.EdgeMenus[0];
    compare(menu.pinButton, true);
    compare(menu.length, "edge");
    compare(menu.modules.length, 1);
    compare(place(menu.modules[0]), [0, 0, 4, 2]);
    compare(errors(loaded.config), []);
  }

  function test_v31_fill_cells_grow_on_pages() {
    const loaded = load({
      "version": 30,
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "columns": [
              {
                "cells": [
                  {
                    "layout": "Tall",
                    "slots": {
                      "main": {
                        "type": "ClockCalendar"
                      }
                    }
                  }
                ]
              },
              {
                "cells": [
                  {
                    "layout": "Wide",
                    "slots": {}
                  },
                  {
                    "layout": "HalfWide",
                    "fillWidth": true,
                    "fillHeight": true,
                    "slots": {
                      "main": {
                        "type": "NowPlaying"
                      }
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    });
    const modules = loaded.config.Overlay.views[0].modules;
    compare(modules.map(place), [[0, 0, 4, 8], [4, 4, 8, 4]]);
    compare(errors(loaded.config), []);
  }

  function test_v31_fill_growth_stays_in_bounds_and_page_pins_are_noted() {
    const tall = {
      "layout": "Tall",
      "slots": {
        "main": {
          "type": "Weather"
        }
      }
    };
    const loaded = load({
      "version": 30,
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "columns": [
              {
                "cells": [tall, tall, tall, tall, tall]
              },
              {
                "cells": [
                  {
                    "layout": "Single",
                    "fillHeight": true,
                    "slots": {
                      "main": {
                        "type": "NowPlaying"
                      }
                    }
                  }
                ]
              },
              {
                "cells": [
                  {
                    "layout": "Single",
                    "slots": {
                      "main": {
                        "type": "Pin"
                      }
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    });
    const modules = loaded.config.Overlay.views[0].modules;
    compare(modules.length, 6);
    verify(modules.every(module => module.place.h <= 32), "grown down a 40-unit column, kept to 32");
    verify(loaded.changes.some(change => change.includes("Pin module(s) removed")));
    compare(errors(loaded.config), []);
  }

  function test_v32_position_becomes_an_anchor() {
    const loaded = load({
      "version": 31,
      "EdgeMenus": [
        {
          "id": "a",
          "position": 0,
          "margin": 12
        },
        {
          "id": "b",
          "position": 50
        },
        {
          "id": "c",
          "position": 90
        },
        {
          "id": "d",
          "position": 30
        }
      ]
    });
    const menus = loaded.config.EdgeMenus;
    // Anchors, then (v35) offsets from the middle: an end's is the furthest
    compare(menus.map(menu => menu.offset), [-200, 0, 200, 0]);
    compare(menus[0].align, undefined);
    compare(menus[0].position, undefined);
    compare(menus[0].margin, undefined);
    verify(loaded.changes.some(change => change.includes("position 30%")));
    verify(loaded.changes.some(change => change.includes("frame margin dropped")));
    verify(!loaded.changes.some(change => change.includes("position 50%")));
    compare(errors(loaded.config), []);
  }
  function test_v35_align_becomes_an_offset_from_the_middle() {
    const loaded = load({
      "version": 34,
      "EdgeMenus": [
        {
          "id": "a",
          "align": "center",
          "offset": 2
        },
        {
          "id": "b",
          "align": "start",
          "offset": 1
        },
        {
          "id": "c",
          "align": "end"
        }
      ]
    });
    const menus = loaded.config.EdgeMenus;
    compare(menus.map(menu => menu.offset), [2, -200, 200]);
    verify(menus.every(menu => !("align" in menu)));
    verify(loaded.changes.some(change => change.includes("align \"start\"")));
    compare(errors(loaded.config), []);
  }

  function test_v37_theme_editor_becomes_theme_picker() {
    const place = {
      "x": 0,
      "y": 0,
      "w": 4,
      "h": 8
    };
    const loaded = load({
      "version": 36,
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "name": "Look",
            "modules": [
              {
                "type": "ThemeEditor",
                "place": place
              },
              {
                "type": "WallpaperPicker",
                "place": place
              }
            ]
          }
        ]
      },
      "EdgeMenus": [
        {
          "id": "menu",
          "modules": [
            {
              "type": "ThemeEditor",
              "place": place
            }
          ]
        }
      ]
    });
    const view = loaded.config.Overlay.views.find(v => v.name === "Look");
    compare(view.modules[0].type, "ThemePicker");
    compare(view.modules[1].type, "WallpaperPicker");
    compare(loaded.config.EdgeMenus[0].modules[0].type, "ThemePicker");
    compare(loaded.changes.filter(change => change.includes("ThemePicker")).length, 2);
    compare(errors(loaded.config), []);
  }

  function test_v38_adds_split_and_special_binds_on_free_keys() {
    const free = ConfigMigration.migrate({
      "version": 37,
      "Hyprland": {
        "binds": [
          {
            "key": "SUPER + J",
            "action": "toggleSplit"
          }
        ]
      }
    }).config.Hyprland.binds;
    compare(free.length, 4);
    compare(free[1].key, "SUPER + X");
    compare(free[1].action, "toggleSplit");
    compare([free[2].key, free[2].action, free[2].argument], ["SUPER + V", "toggleSpecial", "magic"]);
    compare([free[3].key, free[3].action, free[3].argument], ["SUPER + SHIFT + V", "moveToSpecial", "magic"]);
    const taken = ConfigMigration.migrate({
      "version": 37,
      "Hyprland": {
        "binds": [
          {
            "key": "super + x",
            "action": "exec",
            "argument": "foot"
          }
        ]
      }
    }).config.Hyprland.binds;
    compare(taken.length, 3);
    compare(taken[0].action, "exec");
    compare(taken.filter(bind => bind.action === "toggleSplit").length, 0);
  }

  function test_v36_primary_bar_monitors_become_primary() {
    const loaded = load({
      "version": 35,
      "Launcher": {
        "monitors": "primaryBar"
      },
      "Overlay": {
        "monitors": "focused"
      },
      "OSD": {
        "osds": [
          {
            "id": "a",
            "monitors": "primaryBar"
          }
        ]
      }
    });
    compare(loaded.config.Launcher.monitors, "primary");
    compare(loaded.config.Overlay.monitors, "focused");
    compare(loaded.config.OSD.osds[0].monitors, "primary");
    compare(loaded.changes.filter(change => change.includes("primaryBar")).length, 2);
    compare(errors(loaded.config), []);
  }

  function test_v33_missing_tool_pages_come_back_hidden() {
    const loaded = load({
      "version": 32,
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "name": "Home",
            "modules": []
          },
          {
            "type": "Themes"
          },
          {
            "type": "Settings"
          }
        ]
      }
    });
    const views = loaded.config.Overlay.views;
    compare(views.map(view => view.type), ["Custom", "Themes", "Settings", "Keybinds", "BarEditor", "Monitors"]);
    compare(views.map(view => view.visible === false), [false, false, false, true, true, true]);
    compare(loaded.changes.filter(change => change.includes("added back")).length, 3);
    compare(errors(loaded.config), []);
  }

  function test_v33_custom_pages_lose_stretch() {
    const loaded = load({
      "version": 32,
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "name": "Home",
            "stretch": true,
            "modules": []
          },
          {
            "type": "Custom",
            "name": "Other",
            "stretch": false,
            "modules": []
          }
        ]
      }
    });
    const views = loaded.config.Overlay.views;
    compare(views[0].stretch, undefined);
    compare(views[1].stretch, undefined);
    compare(views[0].icon, "");
    compare(loaded.changes.filter(change => change.includes("stretch dropped")).length, 1);
    compare(errors(loaded.config), []);
  }

  function test_v33_weather_settings_become_global() {
    const loaded = load({
      "version": 32,
      "Bars": [
        {
          "id": "primary",
          "widgets": {
            "left": [
              {
                "type": "Weather",
                "properties": {
                  "location": "",
                  "units": "celsius",
                  "intervalMinutes": 30,
                  "showCondition": true
                }
              }
            ]
          }
        }
      ],
      "Overlay": {
        "views": [
          {
            "type": "Custom",
            "name": "Home",
            "modules": [
              {
                "type": "Weather",
                "place": {
                  "x": 0,
                  "y": 0,
                  "w": 4,
                  "h": 4
                },
                "properties": {
                  "location": "Kyoto",
                  "latitude": "",
                  "longitude": "",
                  "units": "fahrenheit"
                }
              }
            ]
          }
        ]
      },
      "EdgeMenus": [
        {
          "id": "a",
          "modules": [
            {
              "type": "Weather",
              "place": {
                "x": 0,
                "y": 0,
                "w": 2,
                "h": 1
              },
              "properties": {
                "location": "Oslo"
              }
            }
          ]
        }
      ]
    });
    const config = loaded.config;
    compare(config.Weather, {
      "location": "Kyoto",
      "latitude": "",
      "longitude": "",
      "units": "fahrenheit",
      "intervalMinutes": 30
    });
    compare(config.Bars[0].widgets.left[0].properties.location, undefined);
    compare(config.Bars[0].widgets.left[0].properties.showCondition, true);
    compare(config.Overlay.views[0].modules[0].properties, undefined);
    compare(config.EdgeMenus[0].modules[0].properties, undefined);
    verify(loaded.changes.some(change => change.includes("from Overlay.views[0].modules[0]")));
    verify(loaded.changes.some(change => change.startsWith("EdgeMenus[0].modules[0]: its own location dropped")));
    compare(errors(config), []);
  }

  function test_migration_is_idempotent() {
    const once = load(files.json("tests/fixtures/configs/v1.json")).config;
    const again = ConfigMigration.migrate(once);
    compare(again.migrated, false);
    compare(again.changes, []);
    compare(JSON.stringify(again.config), JSON.stringify(once));
  }

  function test_migrate_does_not_modify_its_input() {
    const input = files.json("tests/fixtures/configs/v1.json");
    const before = JSON.stringify(input);
    ConfigMigration.migrate(input);
    compare(JSON.stringify(input), before);
  }

  function test_newer_version_is_kept() {
    const result = ConfigMigration.migrate({
      "version": ConfigMigration.currentVersion + 1
    });
    compare(result.config.version, ConfigMigration.currentVersion + 1);
    compare(result.migrated, false);
  }

  function test_v34_lockscreen_becomes_modules_data() {
    return [
      {
        "tag": "with media",
        "showMedia": true,
        "types": ["Greeting", "NowPlaying", "Password"]
      },
      {
        "tag": "without media",
        "showMedia": false,
        "types": ["Greeting", "Password"]
      }
    ];
  }

  function test_v34_lockscreen_becomes_modules(data) {
    const loaded = load({
      "version": 33,
      "Lockscreen": {
        "mode": "quickshell",
        "showMedia": data.showMedia
      }
    });
    const lockscreen = loaded.config.Lockscreen;
    compare(lockscreen.showMedia, undefined);
    compare(lockscreen.layout.modules.map(module => module.type), data.types);
    compare(lockscreen.layout.columns, 16);
    compare(lockscreen.layout.modules[0].properties.text, "");
    compare(loaded.changes.filter(change => change.startsWith("Lockscreen:")).length, 1);
    compare(loaded.removed, []);
    compare(errors(loaded.config), []);
  }

  function test_lockscreen_default_layout_fits_its_grid() {
    const layout = SchemaValidation.applyDefaults({}, schema).Lockscreen.layout;
    const bounds = GridPlacement.bounds(layout.modules);
    verify(bounds.cols <= layout.columns && bounds.rows <= layout.rows);
    compare(layout.modules.filter(module => module.type === "Password").length, 1);
    layout.modules.forEach((module, i) => verify(GridPlacement.canPlace(layout.modules.slice(0, i), module.place, -1)));
  }
}
