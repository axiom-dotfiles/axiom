import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "CompositorLayer"

  RepoFiles {
    id: files
  }

  readonly property var opts: ({
      "activeHex": "aabbcc",
      "inactiveHex": "112233",
      "borderWidth": 2,
      "radius": 8,
      "surfacesBlur": true
    })

  function defaults() {
    const schema = files.json("config/json/config.schema.json");
    return SchemaValidation.applyDefaults({}, schema.properties.WindowLook, schema);
  }

  // WindowLook's defaults with `parts` over them, each group's keys one by one
  function lookWith(parts) {
    const values = defaults();
    for (const part in parts)
      Object.assign(values[part], parts[part]);
    return values;
  }

  function test_hex() {
    compare(CompositorLayer.hex({
      "r": 1,
      "g": 0,
      "b": 0.5
    }), "ff0080");
  }

  function test_look_off_by_default() {
    const look = CompositorLayer.look(defaults(), opts);
    compare(look.parts, []);
    compare(look.borders, null);
    compare(look.shape, null);
    compare(look.gaps, null);
    compare(look.blur, null);
    compare(look.shadow, null);
    compare(look.dim, null);
    compare(look.opacity, null);
  }

  function test_look_shadow_and_dim() {
    const values = lookWith({
      "shadow": {
        "enabled": true,
        "size": 12
      },
      "dim": {
        "enabled": true,
        "strength": 15
      }
    });
    const cast = (color, alpha, offset) => Object.assign({}, opts, {
        "shadow": {
          "size": 12,
          "color": color,
          "alpha": alpha,
          "offset": offset
        }
      });
    const look = CompositorLayer.look(values, cast("101010", 0.6, 3));
    compare(look.parts, ["shadow", "dim"]);
    compare(look.shadow, {
      "size": 12,
      "power": values.shadow.power,
      "color": "10101099",
      "rgb": "101010",
      "alpha": 0.6,
      "baseAlpha": 0.6,
      "strength": 1,
      "offset": 3,
      "soft": false
    });
    compare(look.dim, {
      "strength": 15
    });
    compare(CompositorLayer.look(values, cast("", 1, 0)).shadow.color, "", "no color: the compositor's own");
    compare(CompositorLayer.look(values, cast("c4a7e7", 1, 0)).shadow.color, "c4a7e7ff");
    const strong = cast("101010", 0.4, 0);
    strong.shadow.strength = 2;
    compare(CompositorLayer.look(values, strong).shadow.color, "101010cc", "the strength scales the alpha");
    strong.shadow.strength = 4;
    compare(CompositorLayer.look(values, strong).shadow.color, "101010ff", "up to opaque");
  }

  function test_recommendedEnv() {
    const names = CompositorLayer.recommendedEnv.map(entry => entry[0]);
    verify(names.includes("QT_QPA_PLATFORM") && names.includes("GDK_BACKEND"));
    verify(!names.includes("SDL_VIDEODRIVER"), "breaks games with an older SDL");
    verify(CompositorLayer.recommendedEnv.every(entry => entry.length === 2 && /^[A-Z_]+$/.test(entry[0])));
  }

  function test_sessionEnv() {
    const session = {
      "recommendedEnv": true,
      "env": [
        {
          "name": " QT_QPA_PLATFORM ",
          "value": "wayland"
        },
        {
          "name": "XCURSOR_SIZE",
          "value": "32"
        },
        {
          "name": "1BAD",
          "value": "x"
        },
        {
          "name": "bad name",
          "value": "x"
        }
      ]
    };
    const env = CompositorLayer.sessionEnv(session, {
      "theme": "Bibata",
      "size": 24
    });
    const value = name => env.filter(entry => entry.name === name).map(entry => entry.value);
    compare(value("QT_QPA_PLATFORM"), ["wayland"], "the session's own wins over the recommended one, named once");
    compare(value("XCURSOR_SIZE"), ["32"], "and over the cursor's");
    compare(value("XCURSOR_THEME"), ["Bibata"]);
    compare(CompositorLayer.sessionEnv({}, {
      "theme": "Bibata",
      "size": 24,
      "xcursor": "axiom-cursor"
    }).find(entry => entry.name === "XCURSOR_THEME").value, "axiom-cursor", "XCursor readers' name, where it differs");
    verify(env.every(entry => /^[A-Za-z_][A-Za-z0-9_]*$/.test(entry.name)), "invalid names are left out");
    compare(env[env.length - 1].name, "XCURSOR_SIZE", "a name overridden goes where its winner is");
    compare(CompositorLayer.sessionEnv({
      "recommendedEnv": false,
      "env": []
    }, null), []);
  }

  function test_integrationEnv() {
    compare(CompositorLayer.sessionEnv({}, null, {
      "qt": true
    }), [
      {
        "name": "QT_QPA_PLATFORMTHEME",
        "value": "qt5ct"
      }
    ], "the Qt integration loads qt5ct / qt6ct");
    compare(CompositorLayer.sessionEnv({}, null, {
      "qt": false
    }), []);
    compare(CompositorLayer.sessionEnv({
      "env": [
        {
          "name": "QT_QPA_PLATFORMTHEME",
          "value": "kde"
        }
      ]
    }, null, {
      "qt": true
    }).map(entry => entry.value), ["kde"], "the session's own wins");
  }

  function test_luminance() {
    compare(CompositorLayer.luminance("000000"), 0);
    compare(CompositorLayer.luminance("ffffff"), 1);
    fuzzyCompare(CompositorLayer.luminance("c4a7e7"), 0.45, 0.01);
  }

  // Matching axiom's shadow while it casts none: no shadow, the part off
  function test_look_shadow_none() {
    const values = Object.assign(defaults(), {
      "shadow": true
    });
    const look = CompositorLayer.look(values, Object.assign({}, opts, {
      "shadow": null
    }));
    compare(look.shadow, null);
    compare(look.parts, []);
  }

  function test_look_parts() {
    const values = lookWith({
      "borders": {
        "enabled": true
      },
      "shape": {
        "enabled": true
      },
      "gaps": {
        "enabled": true,
        "inner": 4,
        "outer": 12
      },
      "blur": {
        "enabled": true,
        "windowBlur": false
      },
      "opacity": {
        "enabled": true,
        "inactive": 90
      }
    });
    const look = CompositorLayer.look(values, opts);
    compare(look.parts, ["borders", "shape", "gaps", "blur", "opacity"]);
    compare(look.borders, {
      "active": "aabbcc",
      "inactive": "112233"
    });
    compare(look.shape, {
      "width": 2,
      "radius": 8
    });
    compare(look.gaps, {
      "inner": 4,
      "outer": 12
    });
    compare(look.blur, {
      "windows": false,
      "surfaces": true,
      "size": values.blur.size,
      "passes": values.blur.passes,
      "xray": values.blur.xray,
      "noise": values.blur.noise,
      "contrast": values.blur.contrast
    });
    compare(look.opacity.inactive, 90);
    compare(look.opacity.active, 100);
    compare(look.values, values, "the values, for annotation-driven fields");
  }

  function test_input_parts() {
    const schema = files.json("config/json/config.schema.json");
    const values = SchemaValidation.applyDefaults({}, schema.properties.Input, schema);
    compare(CompositorLayer.input(values).parts, []);
    values.keyboard.enabled = true;
    values.cursor.enabled = true;
    compare(CompositorLayer.input(values).parts, ["keyboard", "cursor"]);
    compare(CompositorLayer.input(values).cursor, null, "no theme: the cursor is left alone");
    values.cursor.theme = "Bibata";
    compare(CompositorLayer.input(values).cursor, {
      "theme": "Bibata",
      "size": 24,
      "xcursor": "Bibata"
    }, "XCursor readers get the theme's own name");
    compare(CompositorLayer.input(values, "axiom-cursor").cursor.xcursor, "axiom-cursor", "or the companion theme filling in its names");
    compare(CompositorLayer.input(values, "axiom-cursor").cursor.theme, "Bibata");
  }

  function test_surfaceBlur() {
    const rules = CompositorLayer.surfaceBlur({
      "blur": true,
      "threshold": 0.5,
      "backdrops": false
    });
    compare(rules.map(rule => rule.name), ["axiom-blur", "axiom-blur-popups", "axiom-blur-backdrops", "axiom-blur-no-anim", "axiom-blur-over-overlay"]);
    const by = name => rules.find(rule => rule.name === name);
    verify(by("axiom-blur").blur && by("axiom-blur").popups && by("axiom-blur").xray === true && by("axiom-blur").threshold === 0.5);
    verify(!by("axiom-blur-popups").blur && by("axiom-blur-popups").popups && by("axiom-blur-popups").xray === false, "the chrome's popups alone, never xray (as Hyprland)");
    verify(!by("axiom-blur-backdrops").on && by("axiom-blur-backdrops").threshold === 0.01, "backdrops only when asked, at every alpha");
    verify(by("axiom-blur-no-anim").noAnim && !by("axiom-blur-no-anim").blur);
    verify(by("axiom-blur-over-overlay").xray === false, "the overlay under it is what blurs");
    verify(CompositorLayer.surfaceBlur({
      "blur": true,
      "throughWindows": true
    }).every(rule => rule.xray !== true), "through windows: no xray anywhere");
    verify(CompositorLayer.surfaceBlur(null).every(rule => !rule.on && (rule.threshold === null || rule.threshold === 0.01)));
  }
}
