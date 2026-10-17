import QtQuick
import QtTest
import qs.components.methods

// SwayConf: sway's command and config text from axiom's settings.
TestCase {
  name: "SwayConf"

  RepoFiles {
    id: files
  }

  readonly property var ctx: ({
      "shellCommand": "qs -p '/opt/axiom'",
      "terminal": "foot",
      "fileManager": "nautilus --new-window",
      "browser": "firefox"
    })

  function test_quote() {
    compare(SwayConf.quote("DP-1"), "DP-1");
    compare(SwayConf.quote("AOC CU34G4Z XJ9"), "\"AOC CU34G4Z XJ9\"");
    // Sway keeps a backslash before a quote, so a `"` is single-quoted
    compare(SwayConf.quote("say \"hi\""), "\"say \"'\"'\"hi\"'\"'");
    compare(SwayConf.quote("\""), "'\"'");
    compare(SwayConf.quote(""), "\"\"");
    compare(SwayConf.quote("it's"), "\"it's\"");
  }

  // A bind's command: doubled backslashes in a file; quoted whole at
  // runtime when sway would split it or take its quotes out (checked
  // against sway 1.12: an unquoted `a, b` runs b at once, and an exec's
  // quotes are gone by the time the key is pressed)
  function test_bindCommand() {
    compare(SwayConf.bindCommand("kill", true), "kill");
    compare(SwayConf.bindCommand("kill", false), "kill");
    compare(SwayConf.bindCommand("resize grow width 5 px, resize grow height 5 px", true), "\"resize grow width 5 px, resize grow height 5 px\"");
    compare(SwayConf.bindCommand("exec \"a; b\"", true), "\"exec \"'\"'\"a; b\"'\"'");
    compare(SwayConf.bindCommand("exec \"a\\tb\"", false), "exec \"a\\\\tb\"");
    compare(SwayConf.bindCommand("exec \"a\nb\"", false), "exec \"a\\nb\"");
  }

  function test_runtimeBindLine() {
    compare(SwayConf.bindLine({
      "key": "SUPER + SHIFT + R",
      "action": "restartShell",
      "release": true
    }, ctx, true), "bindsym --no-warn --release --no-repeat Mod4+Shift+r \"exec \"'\"'\"qs kill -p '/opt/axiom'; qs -p '/opt/axiom' -d\"'\"'");
    compare(SwayConf.bindLine({
      "key": "SUPER + Q",
      "action": "closeWindow"
    }, ctx, true), "bindsym --no-warn --no-repeat Mod4+q kill");
  }

  // An exec holding double quotes reaches the shell with them
  function test_execWithQuotes() {
    compare(SwayConf.command({
      "key": "SUPER + S",
      "action": "exec",
      "argument": "grim -g \"$(slurp)\" /tmp/a.png"
    }, ctx), "exec \"grim -g \"'\"'\"$(slurp)\"'\"'\" /tmp/a.png\"");
  }

  function test_key() {
    compare(SwayConf.key("SUPER + SHIFT + Q"), {
      "command": "bindsym",
      "spec": "Mod4+Shift+q",
      "mouse": false
    });
    compare(SwayConf.key("CTRL + ALT + Delete").spec, "Ctrl+Mod1+Delete");
    compare(SwayConf.key("SUPER + code:49"), {
      "command": "bindcode",
      "spec": "Mod4+49",
      "mouse": false
    });
    compare(SwayConf.key("SUPER + mouse_down"), {
      "command": "bindsym",
      "spec": "Mod4+button5",
      "mouse": true
    });
    compare(SwayConf.key("SUPER + mouse:272").spec, "Mod4+BTN_LEFT");
    compare(SwayConf.key("HYPER + Q"), null);
    compare(SwayConf.key("SUPER + mouse:999"), null);
    compare(SwayConf.key(""), null);
  }

  function test_bindLine() {
    compare(SwayConf.bindLine({
      "key": "SUPER + Q",
      "action": "closeWindow"
    }, ctx), "bindsym --no-warn --no-repeat Mod4+q kill");
    compare(SwayConf.bindLine({
      "key": "XF86AudioRaiseVolume",
      "action": "volumeUp",
      "locked": true,
      "repeating": true
    }, ctx), "bindsym --no-warn --locked XF86AudioRaiseVolume exec \"qs -p '/opt/axiom' ipc call audio volumeUp\"");
    compare(SwayConf.bindLine({
      "key": "SUPER + mouse_down",
      "action": "workspaceStep",
      "argument": "right"
    }, ctx), "bindsym --no-warn --whole-window --no-repeat Mod4+button5 exec \"qs -p '/opt/axiom' ipc call workspaces step 'right' go\"");
    compare(SwayConf.bindLine({
      "key": "SUPER + ALT + L",
      "action": "resizeWindow",
      "argument": "50 -20",
      "repeating": true
    }, ctx), "bindsym --no-warn Mod4+Mod1+l resize grow width 50 px, resize shrink height 20 px");
    compare(SwayConf.bindLine({
      "key": "SUPER + SHIFT + R",
      "action": "restartShell",
      "release": true
    }, ctx), "bindsym --no-warn --release --no-repeat Mod4+Shift+r exec \"qs kill -p '/opt/axiom'; qs -p '/opt/axiom' -d\"");
  }

  function test_switcherAndSpecialAreAxiomsOwn() {
    compare(SwayConf.command({
      "key": "ALT + Tab",
      "action": "windowSwitcher"
    }, ctx), "nop axiom switcher step 1");
    compare(SwayConf.command({
      "key": "ALT + SHIFT + Tab",
      "action": "windowSwitcherReverse"
    }, ctx), "nop axiom switcher step -1");
    compare(SwayConf.command({
      "key": "SUPER + V",
      "action": "toggleSpecial",
      "argument": "magic"
    }, ctx), "nop axiom special toggle magic");
    compare(SwayConf.command({
      "key": "SUPER + SHIFT + V",
      "action": "moveToSpecial",
      "argument": "magic"
    }, ctx), "nop axiom special move magic");
  }

  function test_whatSwayCantDo() {
    for (const action of ["pseudo", "toggleGroup", "stripWider", "stripFit"])
      compare(SwayConf.command({
        "key": "SUPER + P",
        "action": action
      }, ctx), "", action);
    compare(SwayConf.command({
      "key": "SUPER + P",
      "action": "raw",
      "argument": "hl.dsp.layout(\"swapsplit\")"
    }, ctx), "");
    compare(SwayConf.command({
      "key": "SUPER + P",
      "action": "raw",
      "argument": "layout tabbed",
      "compositor": "sway"
    }, ctx), "layout tabbed");
    compare(SwayConf.command({
      "key": "SUPER + H",
      "action": "focusDir",
      "argument": "l"
    }, ctx), "");
  }

  function test_execQuotesWhatSwayWouldSplit() {
    compare(SwayConf.command({
      "key": "SUPER + E",
      "action": "exec",
      "argument": "notify-send a, b"
    }, ctx), "exec \"notify-send a, b\"");
    compare(SwayConf.command({
      "key": "SUPER + E",
      "action": "exec",
      "argument": "foot -e htop"
    }, ctx), "exec foot -e htop");
  }

  function test_floatingModifier() {
    compare(SwayConf.floatingModifier([
      {
        "key": "SUPER + mouse:272",
        "action": "mouseDrag"
      }
    ]), "floating_modifier Mod4 normal");
    compare(SwayConf.floatingModifier([
      {
        "key": "ALT + mouse:273",
        "action": "mouseDrag"
      }
    ]), "floating_modifier Mod1 inverse");
    compare(SwayConf.floatingModifier([]), "");
    // A resize bind alone sets it too; resizing with the left button is
    // sway's inverse
    compare(SwayConf.floatingModifier([
      {
        "key": "SUPER + mouse:273",
        "action": "mouseResize"
      }
    ]), "floating_modifier Mod4 normal");
    compare(SwayConf.floatingModifier([
      {
        "key": "SUPER + mouse:272",
        "action": "mouseResize"
      }
    ]), "floating_modifier Mod4 inverse");
    // One modifier, the left or right button: else sway can't
    verify(!SwayConf.isComplete({
      "key": "SUPER + SHIFT + mouse:272",
      "action": "mouseDrag"
    }, ctx));
    verify(!SwayConf.isComplete({
      "key": "SUPER + mouse:274",
      "action": "mouseDrag"
    }, ctx));
    compare(SwayConf.floatingModifier([
      {
        "key": "SUPER + mouse:274",
        "action": "mouseDrag"
      }
    ]), "");
    verify(SwayConf.isComplete({
      "key": "SUPER + mouse:273",
      "action": "mouseResize"
    }, ctx));
  }

  // Every default bind binds on sway, but what sway has no way to do
  function test_defaultBinds() {
    const schema = files.json("config/json/config.schema.json");
    const binds = schema.properties.Keybinds.properties.binds["default"];
    const unbound = binds.filter(bind => !SwayConf.isComplete(bind, ctx)).map(bind => bind.action);
    compare(unbound, []);
    const lines = SwayConf.bindLines(binds, ctx);
    verify(lines.includes("floating_modifier Mod4 normal"));
    compare(SwayConf.unbindLines(binds, ctx).length, lines.length - 1);
  }

  // An unbind names the flags sway tells binds apart by, or it misses
  function test_unbindLinesCarryTheConflictFlags() {
    compare(SwayConf.unbindLines([
      {
        "key": "XF86AudioRaiseVolume",
        "action": "volumeUp",
        "locked": true,
        "repeating": true
      },
      {
        "key": "SUPER + Q",
        "action": "closeWindow",
        "release": true
      },
      {
        "key": "SUPER + mouse:274",
        "action": "closeWindow"
      }
    ], ctx), ["unbindsym --locked XF86AudioRaiseVolume", "unbindsym --release Mod4+q", "unbindsym --whole-window Mod4+BTN_MIDDLE"]);
  }

  function test_lookLines() {
    const look = CompositorLayer.look({
      "borders": true,
      "shape": true,
      "gaps": true,
      "gapsIn": 3,
      "gapsOut": 6
    }, {
      "activeHex": "9ccfd8",
      "inactiveHex": "403d52",
      "borderWidth": 2,
      "radius": 8
    });
    compare(SwayConf.lookLines(look, false), ["client.focused #9ccfd8 #9ccfd8 #000000 #9ccfd8 #9ccfd8", "client.focused_inactive #403d52 #403d52 #ffffff #403d52 #403d52", "client.unfocused #403d52 #403d52 #ffffff #403d52 #403d52", "default_border pixel 2", "default_floating_border pixel 2", "gaps inner 3", "gaps outer 6"]);
    const live = SwayConf.lookLines(look, true);
    verify(live.includes("[all] border pixel 2"));
    verify(live.includes("gaps outer all set 6"));
    compare(SwayConf.lookLines(CompositorLayer.look({}, {}), true), []);
  }

  function test_inputLines() {
    const schema = files.json("config/json/config.schema.json").properties.Input;
    const input = CompositorLayer.input({
      "keyboard": true,
      "kbLayout": "us,de",
      "kbVariant": "",
      "kbOptions": "caps:escape",
      "repeatRate": 50,
      "repeatDelay": 300,
      "numlockByDefault": true,
      "mouse": true,
      "accelProfile": "default",
      "sensitivity": -25,
      "leftHanded": false,
      "touchpad": false,
      "naturalScroll": true,
      "cursor": true,
      "cursorTheme": "Bibata Modern",
      "cursorSize": 24
    });
    verify(!SwayConf.inputLines(input, schema, true).includes("input type:keyboard xkb_numlock enabled"));
    compare(SwayConf.inputLines(input, schema, false), ["input type:keyboard xkb_layout \"us,de\"", "input type:keyboard xkb_variant \"\"", "input type:keyboard xkb_options caps:escape", "input type:keyboard repeat_rate 50", "input type:keyboard repeat_delay 300", "input type:keyboard xkb_numlock enabled", "input type:pointer pointer_accel -0.25", "input type:pointer left_handed disabled", "seat * xcursor_theme \"Bibata Modern\" 24"]);
  }

  function test_moduleText() {
    const text = SwayConf.moduleText({
      "header": "# Generated by axiom",
      "includeLines": "include /state/axiom/sway.conf",
      "binds": ["bindsym --no-warn --no-repeat Mod4+q kill"],
      "look": [],
      "input": ["input type:keyboard repeat_rate 50"]
    });
    verify(text.startsWith("# Generated by axiom from its settings"));
    verify(text.includes(`mode "${SwayConf.loadedMode}" bindsym --no-warn F35 mode default`));
    verify(text.includes("# Binds\nbindsym --no-warn --no-repeat Mod4+q kill\n"));
    verify(!text.includes("# Window borders"));
    verify(text.includes("# Input\ninput type:keyboard repeat_rate 50\n"));
    verify(!text.includes("# Monitors"));
    const withOutputs = SwayConf.moduleText({
      "header": "# Generated by axiom",
      "includeLines": "include /state/axiom/sway.conf",
      "binds": [],
      "look": [],
      "input": [],
      "outputs": ["output DP-1 enable pos 0 0 scale 1 transform normal adaptive_sync off render_bit_depth 8"]
    });
    verify(withOutputs.includes("# Monitors\noutput DP-1 enable"));
    // Read back, as the writer does until the outputs are known
    compare(SwayConf.fileOutputLines(withOutputs), ["output DP-1 enable pos 0 0 scale 1 transform normal adaptive_sync off render_bit_depth 8"]);
    compare(SwayConf.fileOutputLines(SwayConf.managedText(withOutputs, {
      "header": "# Generated by axiom",
      "userDir": "/u/user",
      "start": {
        "command": "qs -n"
      }
    })).length, 1);
  }

  function test_configBinds() {
    const text = `set $mod Mod4
set $ipc qs ipc call
# bindsym $mod+x nothing
bindsym $mod+Return exec foot
bindsym --release $mod+Shift+e exit
bindsym $mod+Q kill
bindcode $mod+49 exec \\
  something
bindsym --whole-window $mod+button4 focus left
bindsym Hyper+x nop
input type:keyboard {
    xkb_layout us
}
mode "resize" {
    bindsym h resize shrink width 10px
    bindsym Escape mode default
}
mode "launch" bindsym f exec firefox
bindsym $mod+space exec $ipc appLauncher toggle`;

    compare(SwayConf.configBinds(text), [
      {
        "modmask": 64,
        "key": "Return",
        "keycode": 0,
        "submap": "",
        "description": "exec foot"
      },
      {
        "modmask": 65,
        "key": "e",
        "keycode": 0,
        "submap": "",
        "description": "exit"
      },
      {
        "modmask": 64,
        "key": "Q",
        "keycode": 0,
        "submap": "",
        "description": "kill"
      },
      {
        "modmask": 64,
        "key": "",
        "keycode": 49,
        "submap": "",
        "description": "exec something"
      },
      {
        "modmask": 64,
        "key": "mouse_up",
        "keycode": 0,
        "submap": "",
        "description": "focus left"
      },
      {
        "modmask": 0,
        "key": "h",
        "keycode": 0,
        "submap": "resize",
        "description": "resize shrink width 10px"
      },
      {
        "modmask": 0,
        "key": "Escape",
        "keycode": 0,
        "submap": "resize",
        "description": "mode default"
      },
      {
        "modmask": 0,
        "key": "f",
        "keycode": 0,
        "submap": "launch",
        "description": "exec firefox"
      },
      {
        "modmask": 64,
        "key": "space",
        "keycode": 0,
        "submap": "",
        "description": "exec qs ipc call appLauncher toggle"
      }
    ]);
  }

  // The user's binds are what the runtime layer skips (BindKeys)
  function test_configBindsAgainstAxioms() {
    const entries = SwayConf.configBinds("set $mod Mod4\nbindsym $mod+q kill\nbindsym $mod+button4 focus left\nbindcode Mod4+49 nop");
    const plan = BindKeys.runtimeBinds([
      {
        "key": "SUPER + Q"
      },
      {
        "key": "SUPER + mouse_up"
      },
      {
        "key": "SUPER + code:49"
      },
      {
        "key": "SUPER + W"
      }
    ], entries);
    compare(plan.skipped, ["SUPER + Q", "SUPER + mouse_up", "SUPER + code:49"]);
    compare(plan.apply.map(bind => bind.key), ["SUPER + W"]);
  }

  function test_bindEntries() {
    compare(SwayConf.bindEntries([
      {
        "key": "SUPER + Q",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + mouse:272",
        "action": "mouseDrag"
      },
      {
        "key": "",
        "action": "launcher"
      }
    ], ctx).map(entry => [BindKeys.entryId(entry), entry.description]), [["64:q", BindActions.descriptionFor({
          "action": "closeWindow"
        })], ["64:mouse:272", BindActions.descriptionFor({
          "action": "mouseDrag"
        })]]);
  }

  function test_optionLines() {
    const schema = files.json("config/json/config.schema.json").properties;
    compare(SwayConf.optionLines(schema.WindowBehaviour, {
      "followMouse": true,
      "focusOnActivate": false,
      "workspaceBackAndForth": false,
      "cursorHideTimeout": 5,
      "hideCursorOnKeyPress": true,
      "noWarps": true
    }), ["focus_follows_mouse yes", "focus_on_window_activation urgent", "workspace_auto_back_and_forth no", "seat * hide_cursor 5000", "seat * hide_cursor when-typing enable", "mouse_warping none"]);
    const sway = SwayConf.optionLines(schema.Sway, {
      "workspaceLayout": "tabbed",
      "hideEdgeBorders": "smart",
      "smartGaps": "off",
      "focusWrapping": "yes",
      "popupDuringFullscreen": "smart",
      "xwayland": "enable",
      "font": ""
    });
    compare(sway[0], "workspace_layout tabbed");
    verify(!sway.some(line => line.startsWith("font")));
    verify(SwayConf.optionLines(schema.Sway, {
      "font": "pango:Inter 10"
    }).includes("font pango:Inter 10"));
  }

  function test_managedText() {
    const module = SwayConf.moduleText({
      "header": "# Generated by axiom",
      "includeLines": "include /s/sway.conf",
      "binds": ["bindsym --no-warn --no-repeat Mod4+q kill"],
      "look": [],
      "input": []
    });
    const text = SwayConf.managedText(module, {
      "header": "# Generated by axiom",
      "userDir": "/home/u/.config/sway/user",
      "options": ["focus_follows_mouse yes"],
      "env": [
        {
          "name": "QT_QPA_PLATFORM",
          "value": "wayland;xcb"
        },
        {
          "name": "bad name",
          "value": "x"
        },
        {
          "name": "GREETING",
          "value": "it's"
        }
      ],
      "start": {
        "command": "qs -p '/opt/axiom' -n",
        "idle": true,
        "polkit": false
      },
      "autostart": [
        {
          "command": "hypridle",
          "enabled": true
        },
        {
          "command": "nm-applet",
          "enabled": true
        },
        {
          "command": "off",
          "enabled": false
        },
        {
          "command": "printf a\\tb",
          "enabled": true
        }
      ]
    });
    verify(text.startsWith("# Generated by axiom (sway mode: managed)"));
    // Escaped for sway's unescaping of the line
    verify(text.includes("GREETING='it'\\\\''s'"));
    verify(text.includes("exec \"printf a\\\\tb\"\n"));
    // The module's lines, without its own comment header
    verify(text.includes(`mode "${SwayConf.loadedMode}"`));
    verify(!text.includes("Include it near the top"));
    verify(text.includes("bindsym --no-warn --no-repeat Mod4+q kill"));
    verify(text.includes("\nfocus_follows_mouse yes\n"));
    verify(text.includes("exec \"dbus-update-activation-environment --systemd QT_QPA_PLATFORM='wayland;xcb' GREETING="));
    verify(text.includes("exec \"env QT_QPA_PLATFORM='wayland;xcb' GREETING='it'\\\\''s' qs -p '/opt/axiom' -n\"\n"));
    verify(!text.includes("hypridle"));
    verify(text.includes("exec nm-applet\n"));
    verify(!text.includes("exec off"));
    verify(text.endsWith("include /home/u/.config/sway/user/*\n"));
  }

  function test_releasedText() {
    const text = SwayConf.releasedText("/u/user", "exec qs -n");
    verify(text.startsWith("# Given back by axiom"));
    verify(text.includes("\nexec qs -n\n"));
    verify(text.endsWith("include /u/user/*\n"));
  }

  function test_outputCommand() {
    compare(SwayConf.outputCommand({
      "output": "desc:AOC CU34G4Z XJ9",
      "mode": "3440x1440@240",
      "x": 15,
      "y": 83,
      "scale": 1,
      "transform": 0,
      "vrr": 1
    }), "output \"AOC CU34G4Z XJ9\" enable mode 3440x1440@240Hz pos 15 83 scale 1 transform normal adaptive_sync on render_bit_depth 8");
    compare(SwayConf.outputCommand({
      "output": "HDMI-A-1",
      "mode": "preferred",
      "x": 0,
      "y": 0,
      "scale": 1.5,
      "transform": 5,
      "bitdepth": 10
    }), "output HDMI-A-1 enable pos 0 0 scale 1.5 transform flipped-90 adaptive_sync off render_bit_depth 10");
    compare(SwayConf.outputCommand({
      "output": "DP-2",
      "disabled": true
    }), "output DP-2 disable");
  }

  function test_outputCommandsDisableLast() {
    compare(SwayConf.outputCommands([
      {
        "output": "DP-2",
        "disabled": true
      },
      {
        "output": "DP-1",
        "mode": "1920x1080"
      }
    ]), "output DP-1 enable mode 1920x1080 pos 0 0 scale 1 transform normal adaptive_sync off render_bit_depth 8; output DP-2 disable");
  }

  // SwayFX's part of the look, sent at runtime only
  function test_fxLines() {
    compare(SwayConf.fxLines(null, null).filter(line => !line.startsWith("layer_effects")), []);
    const lines = SwayConf.fxLines({
      "shape": {
        "width": 2,
        "radius": 14
      },
      "blur": {
        "windows": true,
        "surfaces": true,
        "size": 16,
        "passes": 3,
        "xray": false,
        "noise": 12,
        "contrast": 89
      },
      "shadow": {
        "size": 8,
        "power": 3,
        "color": "101010ee",
        "offset": 2
      },
      "dim": {
        "strength": 15
      }
    }, {
      "blur": true,
      "throughWindows": true,
      "backdrops": false
    });
    verify(lines.includes("corner_radius 14"));
    verify(lines.includes("blur_radius 10"), "the radius capped at SwayFX's 10");
    verify(!lines.includes("blur enable") && !lines.includes("shadows enable"), "a window's blur and shadow are SwayManager's, a window at a time");
    verify(lines.includes("blur_passes 3") && lines.includes("blur_xray disable"));
    verify(lines.includes("blur_noise 0.012") && lines.includes("blur_contrast 0.89"));
    verify(lines.includes("shadow_blur_radius 8") && lines.includes("shadow_offset 0 2"));
    verify(lines.includes("shadow_color #101010ee") && lines.includes("shadow_inactive_color #101010ee"));
    verify(lines.includes("default_dim_inactive 0.15"));
    verify(lines.includes("layer_effects axiom-overlay \"blur enable; blur_xray disable; blur_ignore_transparent enable\""), "through windows: no xray");
    verify(lines.includes("layer_effects axiom-backdrop \"blur disable; blur_xray disable; blur_ignore_transparent enable\""), "backdrops only when asked");
    verify(lines.includes("layer_effects axiom-blur-backing-overlay \"blur enable; blur_xray disable; blur_ignore_transparent enable\""));
    // Surfaces not blurring: every layer's blur off
    verify(SwayConf.fxLines(null, {
      "blur": false
    }).every(line => line.includes("\"blur disable;")));
    // No shadow color: SwayFX's own
    verify(!SwayConf.fxLines({
      "shadow": {
        "size": 8,
        "power": 3,
        "color": "",
        "offset": 0
      }
    }, null).some(line => line.startsWith("shadow_color")));
    // Matching axiom's (soft): fitted to its glow, the strength on top
    const soft = (size, baseAlpha, strength) => SwayConf.fxLines({
        "shadow": {
          "size": size,
          "power": 3,
          "color": "ffffff00",
          "rgb": "ffffff",
          "baseAlpha": baseAlpha,
          "strength": strength,
          "offset": 0,
          "soft": true
        }
      }, null);
    const glow = soft(64, 1, 1);
    verify(glow.includes("shadow_blur_radius 45"), "the radius 0.7 × axiom's size");
    verify(glow.includes("shadow_color #ffffffd4") && glow.includes("shadow_inactive_color #ffffffd4"), "the alpha 0.2 ln(64) × axiom's");
    verify(soft(20, 1, 1).includes("shadow_color #ffffff99"), "softer at a smaller size");
    verify(soft(64, 1, 0.5).includes("shadow_color #ffffff6a"), "the strength scales it");
    verify(soft(64, 1, 4).includes("shadow_color #ffffffff"), "capped at opaque");
  }
}
