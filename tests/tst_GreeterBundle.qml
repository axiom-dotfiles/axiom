import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "GreeterBundle"

  RepoFiles {
    id: files
  }

  readonly property var schema: files.json("config/json/config.schema.json")
  readonly property var inputSchema: schema.properties.Input

  function config(mode) {
    const config = SchemaValidation.applyDefaults({}, schema);
    config.Appearance.wallpaper = "file:///home/u/Pictures/a.png";
    config.Appearance.wallpapers = {
      "DP-1": "file:///home/u/Pictures/a.png",
      "HDMI-A-1": "file:///home/u/Pictures/b.png",
      "DP-2": "file:///home/u/Pictures/gone.png"
    };
    config.Compositor.mode = mode;
    config.Input.keyboard = mode === "managed";
    config.Input.kbLayout = "us,de";
    config.Hyprland.managed.dimStrength = 9;
    config.Monitors.profiles = [
      {
        "name": "desk",
        "outputs": [
          {
            "output": "desc:Dell"
          }
        ]
      }
    ];
    config.Chat.keepConversations = 3;
    return config;
  }

  readonly property var copies: ({
      "file:///home/u/Pictures/a.png": "file:///var/lib/axiom-greeter/config/wallpapers/0.png",
      "file:///home/u/Pictures/b.png": "file:///var/lib/axiom-greeter/config/wallpapers/1.png"
    })

  function test_export_takes_only_its_sections() {
    const bundle = GreeterBundle.exportConfig(config("detached"), inputSchema, copies);
    compare(Object.keys(bundle).sort(), ["Appearance", "Compositor", "General", "Greeter", "Input", "Monitors", "Weather", "Widget", "version"]);
    compare(bundle.Monitors.profiles[0].name, "desk");
    compare(bundle.Hyprland, undefined);
    compare(bundle.Compositor.mode, "detached");
  }

  function test_export_renames_wallpapers_to_copies() {
    const bundle = GreeterBundle.exportConfig(config("detached"), inputSchema, copies);
    compare(bundle.Appearance.wallpaper, "file:///var/lib/axiom-greeter/config/wallpapers/0.png");
    compare(bundle.Appearance.wallpapers, {
      "DP-1": "file:///var/lib/axiom-greeter/config/wallpapers/0.png",
      "HDMI-A-1": "file:///var/lib/axiom-greeter/config/wallpapers/1.png"
    });
    compare(GreeterBundle.wallpaperSources(config("detached")), ["file:///home/u/Pictures/a.png", "file:///home/u/Pictures/b.png", "file:///home/u/Pictures/gone.png"]);
  }

  function test_export_takes_only_greeter_options() {
    const bundle = GreeterBundle.exportConfig(config("managed"), inputSchema, copies);
    compare(bundle.Input.keyboard, true);
    compare(bundle.Input.kbLayout, "us,de");
    verify(bundle.Input.sensitivity !== undefined);
    compare(bundle.Hyprland, undefined, "Hyprland's own options stay home");
  }

  // The exported bundle is a valid config once filled with defaults
  function test_export_round_trips() {
    const bundle = GreeterBundle.exportConfig(config("managed"), inputSchema, copies);
    const filled = SchemaValidation.applyDefaults(bundle, schema);
    compare(SchemaValidation.validationErrors(filled, schema), []);
    compare(filled.Chat.keepConversations, schema.properties.Chat.properties.keepConversations.default);
  }

  function prepare(raw) {
    const config = SchemaValidation.applyDefaults(raw, schema);
    return {
      "config": config,
      "errors": SchemaValidation.validationErrors(config, schema)
    };
  }

  function defaults() {
    return {
      "defaults": true
    };
  }

  function test_pick_prefers_the_bundle() {
    const picked = GreeterBundle.pick([
      {
        "source": "bundle",
        "text": "{\"Greeter\": {\"rememberUser\": false}}"
      },
      {
        "source": "fallback",
        "text": "{}"
      }
    ], prepare, defaults);
    compare(picked.source, "bundle");
    compare(picked.problems, []);
  }

  function test_pick_falls_back_on_a_broken_bundle() {
    const picked = GreeterBundle.pick([
      {
        "source": "bundle",
        "text": "{ broken"
      },
      {
        "source": "fallback",
        "text": "{}"
      }
    ], prepare, defaults);
    compare(picked.source, "fallback");
    compare(picked.problems.length, 1);
    verify(picked.problems[0].error.startsWith("not JSON"));
  }

  function test_pick_falls_back_on_an_invalid_bundle() {
    const picked = GreeterBundle.pick([
      {
        "source": "bundle",
        "text": "{\"Greeter\": {\"rememberUser\": \"yes\"}}"
      },
      {
        "source": "fallback",
        "text": ""
      }
    ], prepare, defaults);
    compare(picked.source, "defaults");
    compare(picked.config, {
      "defaults": true
    });
    compare(picked.problems.map(problem => problem.source), ["bundle", "fallback"]);
    compare(picked.problems[1].error, "missing");
  }
}
