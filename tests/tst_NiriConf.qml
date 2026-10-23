import QtQuick
import QtTest
import qs.components.methods

// NiriConf: niri's config text and requests from axiom's settings. The
// files also go to tests/.out/ as *.niri.kdl, which run_tests.sh has niri
// itself validate where it's installed.
TestCase {
  name: "NiriConf"

  RepoFiles {
    id: files
  }

  readonly property var ctx: ({
      "axiomPath": "/opt/axiom",
      "axiomBin": "/usr/bin/axiom",
      "shellCommand": "'/usr/bin/axiom'",
      "restartCommand": "'/usr/bin/axiom' restart",
      "terminal": "foot",
      "fileManager": "nautilus",
      "browser": "firefox"
    })
  readonly property var schema: files.json("config/json/config.schema.json").properties

  function _write(path, text) {
    const written = files.write(path, text);
    tryVerify(() => written.done, 2000);
  }

  // --- KDL ---

  function test_serialize() {
    const n = NiriConf.node;
    compare(NiriConf.serialize([n("layout", [], {}, [n("gaps", [8]), n("focus-ring", [], {}, [n("off")])]), n("spawn", ["a \"b\"", "c\\d"]), n("position", [], {
        "x": 0,
        "y": -10
      }), n("empty", [], {}, []), n("Super+Shift+Q", [], {
        "repeat": false
      }, [n("close-window")]), n("odd name")]), `layout {
    gaps 8
    focus-ring {
        off
    }
}
spawn "a \\"b\\"" "c\\\\d"
position x=0 y=-10
empty {}
Super+Shift+Q repeat=false {
    close-window
}
"odd name"`);
  }

  function test_setPathAndMerged() {
    const nodes = [];
    NiriConf.setPath(nodes, "input.keyboard.xkb.layout", ["us"]);
    NiriConf.setPath(nodes, "input.keyboard.repeat-rate", [50]);
    NiriConf.setPath(nodes, "input.keyboard.xkb.layout", ["de"]);
    compare(NiriConf.serialize(nodes), `input {
    keyboard {
        xkb {
            layout "de"
        }
        repeat-rate 50
    }
}`);
    // Sections of one name joined; rules that repeat kept apart
    const n = NiriConf.node;
    const joined = NiriConf.merged([n("layout", [], {}, [n("gaps", [4]), n("border", [], {}, [n("width", [2])])]), n("window-rule", [], {}, [n("opacity", [0.9])]), n("layout", [], {}, [n("gaps", [8]), n("border", [], {}, [n("on")])]), n("window-rule", [], {}, [n("opacity", [0.5])])]);
    compare(joined.map(x => x.name), ["layout", "window-rule", "window-rule"]);
    compare(NiriConf.serialize([joined[0]]), `layout {
    gaps 8
    border {
        width 2
        on
    }
}`);
  }

  // --- Keys and binds ---

  function test_key() {
    compare(NiriConf.key("SUPER + SHIFT + Q"), "Super+Shift+Q");
    compare(NiriConf.key("CTRL + ALT + Delete"), "Ctrl+Alt+Delete");
    compare(NiriConf.key("SUPER + mouse_down"), "Super+WheelScrollDown");
    compare(NiriConf.key("SUPER + mouse:274"), "Super+MouseMiddle");
    compare(NiriConf.key("XF86AudioRaiseVolume"), "XF86AudioRaiseVolume");
    // What niri can't bind
    compare(NiriConf.key("SUPER + code:10"), null);
    compare(NiriConf.key("CAPS + A"), null);
    compare(NiriConf.key("SUPER + mouse:280"), null);
    compare(NiriConf.key("Super_L"), null, "niri has no release binds");
    compare(NiriConf.key(""), null);
  }

  function bindText(bind) {
    const n = NiriConf.bindNode(bind, ctx);
    return n ? NiriConf.serialize([n]) : "";
  }

  function test_binds() {
    compare(bindText({
      "key": "SUPER + D",
      "action": "launcher",
      "call": "open"
    }), `Super+D hotkey-overlay-title="Axiom: App launcher (open)" repeat=false {
    spawn "/usr/bin/axiom" "ipc" "appLauncher" "open"
}`);
    // An argument stays one word
    compare(NiriConf.actionFor({
      "key": "SUPER + 1",
      "action": "workspaceNth",
      "argument": "1"
    }, ctx).args, ["/usr/bin/axiom", "ipc", "workspaces", "nth", "1", "go"]);
    compare(bindText({
      "key": "XF86AudioRaiseVolume",
      "action": "volumeUp",
      "locked": true,
      "repeating": true
    }), `XF86AudioRaiseVolume hotkey-overlay-title="Media: Volume up" allow-when-locked=true {
    spawn "/usr/bin/axiom" "ipc" "audio" "volumeUp"
}`);
    compare(bindText({
      "key": "SUPER + mouse_down",
      "action": "focusDir",
      "argument": "right"
    }), `Super+WheelScrollDown hotkey-overlay-title="Window: Focus right" repeat=false cooldown-ms=150 {
    focus-column-or-monitor-right
}`);
    compare(NiriConf.actionFor({
      "key": "SUPER + E",
      "action": "exec",
      "argument": "thunar ~"
    }, ctx), NiriConf.node("spawn-sh", ["thunar ~"]));
    compare(NiriConf.actionFor({
      "key": "SUPER + M",
      "action": "exitSession"
    }, ctx), NiriConf.node("quit", [], {
      "skip-confirmation": true
    }));
    compare(NiriConf.actionFor({
      "key": "ALT + Tab",
      "action": "windowSwitcherReverse"
    }, ctx).args.slice(-2), ["windowSwitcher", "previous"]);
    compare(NiriConf.actionFor({
      "key": "SUPER + right",
      "action": "resizeWindow",
      "argument": "40 0"
    }, ctx), NiriConf.node("set-column-width", ["+40"]));
    compare(NiriConf.actionFor({
      "key": "SUPER + up",
      "action": "resizeWindow",
      "argument": "0 -40"
    }, ctx), NiriConf.node("set-window-height", ["-40"]));
    // Raw binds: niri's own pass through; another compositor's, nothing
    compare(bindText({
      "key": "SUPER + Home",
      "action": "raw",
      "argument": "focus-column-first",
      "compositor": "niri"
    }), `Super+Home hotkey-overlay-title="Custom: focus-column-first" repeat=false {
    focus-column-first
}`);
  }

  function test_incompleteBinds() {
    const incomplete = [
      {
        "key": "SUPER + P",
        "action": "pin"
      },
      {
        "key": "SUPER + mouse:272",
        "action": "mouseDrag"
      },
      {
        "key": "SUPER + S",
        "action": "toggleSpecial",
        "argument": "magic"
      },
      {
        "key": "SUPER + R",
        "action": "resizeWindow",
        "argument": "40 40"
      },
      {
        "key": "SUPER + X",
        "action": "raw",
        "argument": "killactive",
        "compositor": "hyprland"
      },
      {
        "key": "SUPER + code:10",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + L",
        "action": "exec",
        "argument": ""
      }
    ];
    for (const bind of incomplete)
      compare(NiriConf.isComplete(bind, ctx), false, bind.action);
  }

  function test_bindsNodeBindsAKeyOnce() {
    const node = NiriConf.bindsNode([
      {
        "key": "SUPER + Q",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + q",
        "action": "fullscreen"
      },
      {
        "key": "SUPER + P",
        "action": "pin"
      }
    ], ctx);
    compare(node.children.map(c => c.name), ["Super+Q"]);
    compare(NiriConf.bindsNode([], ctx), null);
  }

  function test_bindEntries() {
    compare(NiriConf.bindEntries([
      {
        "key": "SUPER + SHIFT + Q",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + P",
        "action": "pin"
      }
    ], ctx), [
      {
        "modmask": 65,
        "key": "q",
        "keycode": 0,
        "submap": "",
        "description": "Window: Close"
      }
    ]);
  }

  // --- The look, input and options ---

  // WindowLook with every part off, `parts` over it
  function lookOf(parts, shadow) {
    const values = {};
    for (const part of CompositorLayer.lookPartNames)
      values[part] = Object.assign({
        "enabled": false
      }, parts[part] ?? {});
    return CompositorLayer.look(values, {
      "activeHex": "89b4fa",
      "inactiveHex": "45475a",
      "borderWidth": 2,
      "radius": 10,
      "surfacesBlur": true,
      "shadow": shadow ?? null
    });
  }

  function test_look() {
    const look = lookOf({
      "borders": {
        "enabled": true
      },
      "shape": {
        "enabled": true
      },
      "gaps": {
        "enabled": true,
        "inner": 4,
        "outer": 10
      },
      "opacity": {
        "enabled": true,
        "active": 100,
        "inactive": 90
      }
    });
    compare(NiriConf.serialize(NiriConf.merged(NiriConf.lookNodes(look))), `layout {
    border {
        active-color "#89b4fa"
        inactive-color "#45475a"
        on
        width 2
    }
    focus-ring {
        active-color "#89b4fa"
        inactive-color "#45475a"
        off
    }
    gaps 4
    struts {
        left 6
        right 6
        top 6
        bottom 6
    }
}
window-rule {
    geometry-corner-radius 10
    clip-to-geometry true
}
window-rule {
    match is-focused=true
    opacity 1.0
}
window-rule {
    match is-focused=false
    opacity 0.9
}`);
    // Nothing on, nothing written
    compare(NiriConf.lookNodes(lookOf({})), []);
  }

  function test_shadowAndBlur() {
    const look = lookOf({
      "shadow": {
        "enabled": true,
        "power": 3
      },
      "blur": {
        "enabled": true,
        "windowBlur": true,
        "size": 4,
        "passes": 3,
        "xray": false,
        "noise": 12
      }
    }, {
      "size": 20,
      "color": "000000",
      "alpha": 0.5,
      "offset": 5,
      "soft": true
    });
    const text = NiriConf.serialize(NiriConf.merged(NiriConf.lookNodes(look)));
    const soft = CompositorLayer.gaussianShadow(look.shadow);
    verify(text.includes(`softness ${soft.radius}`), text);
    verify(text.includes("offset x=0 y=5"), text);
    verify(text.includes(`color "#000000${CompositorLayer.alphaHex(soft.alpha)}"`), text);
    verify(text.includes("blur {\n    passes 3\n    offset 4\n    noise 0.012\n}"), text);
    verify(text.includes("background-effect {\n        blur true\n        xray false\n    }"), text);
  }

  function test_surfaceBlur() {
    const nodes = surfaces => NiriConf.serialize(NiriConf.surfaceBlurNodes(Object.assign({
        "blur": true,
        "threshold": 0.5
      }, surfaces)));
    const on = nodes({});
    verify(on.includes('match namespace="^axiom-(blur-backing|dock-preview|overlay|'), on);
    verify(on.includes("background-effect {\n        xray true\n    }"), "the wallpaper alone by default");
    verify(!on.includes("blur true"), "what blurs is the shell's regions, never a rule's whole rectangle");
    verify(on.includes('match namespace="^axiom-(blur-backing-overlay)$"') && on.includes("xray false"), "the blur window over the overlay blurs the overlay");
    verify(!on.includes("backdrop|polkit"), "backdrops only when asked");
    const chrome = on.split("layer-rule").find(rule => /[(|]bar[|)]/.test(rule));
    verify(chrome && chrome.includes("xray false") && !/[(|]border[|)]/.test(on), "the chrome's popups (tooltips, menus) never xray, as Hyprland's; the chrome itself is drawn by the blur window");
    const through = nodes({
      "throughWindows": true,
      "backdrops": true
    });
    verify(through.includes('"^axiom-(backdrop|polkit)$"'), through);
    verify(!through.includes("xray true"), "through windows: never xray");
    compare(NiriConf.surfaceBlurNodes({
      "blur": false
    }), [], "nothing while the surfaces don't blur");
    const written = files.write("tests/.out/surface_blur.niri.kdl", through + "\n");
    tryVerify(() => written.done, 2000);
  }

  function test_input() {
    const values = {
      "keyboard": {
        "enabled": true,
        "layout": "us,de",
        "variant": "",
        "options": "",
        "repeatRate": 30,
        "repeatDelay": 300,
        "numlock": true
      },
      "mouse": {
        "enabled": false,
        "accel": "flat"
      },
      "touchpad": {
        "enabled": true,
        "naturalScroll": true,
        "tapToClick": false,
        "disableWhileTyping": true,
        "scrollFactor": 50
      },
      "cursor": {
        "enabled": true,
        "theme": "Bibata",
        "size": 24
      }
    };
    const text = NiriConf.serialize(NiriConf.inputNodes(CompositorLayer.input(values), schema.Input));
    compare(text, `input {
    keyboard {
        xkb {
            layout "us,de"
            variant ""
            options ""
        }
        repeat-rate 30
        repeat-delay 300
        numlock
    }
    touchpad {
        natural-scroll
        dwt
        scroll-factor 0.5
    }
}
cursor {
    xcursor-theme "Bibata"
    xcursor-size 24
}`);
    // The companion theme filling in the names the theme lacks
    verify(NiriConf.serialize(NiriConf.inputNodes(CompositorLayer.input(values, "axiom-cursor"), schema.Input)).includes(`xcursor-theme "axiom-cursor"`));
  }

  function test_options() {
    const text = NiriConf.serialize(NiriConf.optionNodes(schema.WindowBehaviour, {
      "followMouse": true,
      "focusOnActivate": true,
      "workspaceBackAndForth": false,
      "cursorHideTimeout": 3000,
      "hideCursorOnKeyPress": true,
      "noWarps": false
    }, false));
    // Never moving the cursor is niri's own default: nothing written
    compare(NiriConf.serialize(NiriConf.optionNodes(schema.WindowBehaviour, {
      "noWarps": true
    }, false)), "");
    compare(text, `input {
    focus-follows-mouse
    warp-mouse-to-focus
}
cursor {
    hide-after-inactive-ms 3000
    hide-when-typing
}`);
    compare(NiriConf.serialize(NiriConf.optionNodes(schema.Workspaces, {
      "stripColumnWidth": 50
    }, false)), `layout {
    default-column-width {
        proportion 0.5
    }
}`);
    compare(NiriConf.serialize(NiriConf.optionNodes(schema.Compositor.properties.niri, {
      "centerFocusedColumn": "on-overflow",
      "alwaysCenterSingleColumn": true,
      "emptyWorkspaceAboveFirst": false,
      "defaultColumnDisplay": "normal",
      "hotCorner": false,
      "overviewZoom": 50,
      "animations": true,
      "animationSlowdown": 100,
      "preferNoCsd": false,
      "skipHotkeyOverlay": true,
      "primaryClipboard": false,
      "xwayland": true
    }, false)), `layout {
    center-focused-column "on-overflow"
    always-center-single-column
    default-column-display "normal"
}
gestures {
    hot-corners {
        off
    }
}
overview {
    zoom 0.5
}
hotkey-overlay {
    skip-at-startup
}
clipboard {
    disable-primary
}`);
    compare(NiriConf.serialize(NiriConf.optionNodes(schema.Compositor.properties.niri, {
      "animations": false,
      "animationSlowdown": 200
    }, false)), `animations {
    off
    slowdown 2.0
}`);
  }

  // --- Outputs ---

  readonly property var rules: [
    {
      "output": "desc:Dell Inc. U2720Q 1234",
      "mode": "3840x2160@60",
      "x": 0,
      "y": 0,
      "scale": 1.5,
      "transform": 1,
      "vrr": 2
    },
    {
      "output": "HDMI-A-1",
      "disabled": true
    }
  ]

  function test_outputNodes() {
    compare(NiriConf.serialize(NiriConf.outputNodes(rules)), `output "Dell Inc. U2720Q 1234" {
    mode "3840x2160@60.000"
    scale 1.5
    transform "90"
    position x=0 y=0
    variable-refresh-rate on-demand=true
}
output "HDMI-A-1" {
    off
}`);
  }

  function test_outputRequests() {
    const requests = NiriConf.outputRequests(rules, [
      {
        "name": "DP-1",
        "description": "Dell Inc. U2720Q 1234"
      }
    ]);
    compare(requests[0], {
      "Output": {
        "output": "DP-1",
        "action": "On"
      }
    });
    compare(requests[1].Output.action.Mode.mode.Specific, {
      "width": 3840,
      "height": 2160,
      "refresh": 60
    });
    compare(requests.map(r => r.Output.output), ["DP-1", "DP-1", "DP-1", "DP-1", "DP-1", "DP-1", "HDMI-A-1"]);
    compare(requests[requests.length - 1].Output.action, "Off");
    compare(requests[3].Output.action.Transform.transform, "_90");
    compare(requests[5].Output.action.Vrr.vrr, {
      "vrr": true,
      "on_demand": true
    });
    // A description nothing connected has: left out
    compare(NiriConf.outputRequests([rules[0]], []), []);
  }

  function test_fileOutputNodes() {
    const text = NiriConf.moduleText({
      "header": "// Generated by axiom",
      "includeLines": "include \"/x\"",
      "outputs": NiriConf.outputNodes(rules)
    });
    compare(NiriConf.serialize(NiriConf.fileOutputNodes(text)), NiriConf.serialize(NiriConf.outputNodes(rules)));
    // A file's outputs, kept as text until the outputs are read, go into
    // the next file as they were
    const again = NiriConf.moduleText({
      "header": "// Generated by axiom",
      "includeLines": "include \"/x\"",
      "outputs": NiriConf.fileOutputNodes(text)
    });
    compare(again, text);
  }

  // --- The files, which niri itself checks (run_tests.sh) ---

  function test_files() {
    const binds = NiriConf.bindsNode([
      {
        "key": "SUPER + Return",
        "action": "terminal"
      },
      {
        "key": "SUPER + Q",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + 1",
        "action": "workspaceNth",
        "argument": "1"
      },
      {
        "key": "ALT + Tab",
        "action": "windowSwitcher"
      },
      {
        "key": "SUPER + mouse_down",
        "action": "focusDir",
        "argument": "right"
      },
      {
        "key": "SUPER + W",
        "action": "toggleGroup"
      },
      {
        "key": "SUPER + equal",
        "action": "stripWider"
      },
      {
        "key": "SUPER + F",
        "action": "stripFit"
      },
      {
        "key": "SUPER + SHIFT + M",
        "action": "exitSession"
      },
      {
        "key": "SUPER + SHIFT + R",
        "action": "restartShell"
      },
      {
        "key": "XF86AudioMute",
        "action": "toggleMute",
        "locked": true
      }
    ], ctx);
    const look = NiriConf.lookNodes(lookOf({
      "borders": {
        "enabled": true
      },
      "shape": {
        "enabled": true
      },
      "gaps": {
        "enabled": true,
        "inner": 4,
        "outer": 10
      },
      "blur": {
        "enabled": true,
        "windowBlur": true,
        "size": 4,
        "passes": 3,
        "xray": true,
        "noise": 12
      },
      "shadow": {
        "enabled": true
      },
      "opacity": {
        "enabled": true,
        "active": 100,
        "inactive": 90
      }
    }, {
      "size": 12,
      "color": "000000",
      "alpha": 0.4,
      "offset": 3,
      "soft": true
    }));
    const input = NiriConf.inputNodes(CompositorLayer.input({
      "keyboard": {
        "enabled": true,
        "layout": "us",
        "repeatRate": 40
      },
      "mouse": {
        "enabled": false
      },
      "touchpad": {
        "enabled": true,
        "tapToClick": true
      },
      "cursor": {
        "enabled": true,
        "theme": "Adwaita",
        "size": 24
      }
    }), schema.Input);
    const options = NiriConf.optionNodes(schema.WindowBehaviour, {
      "followMouse": true,
      "workspaceBackAndForth": true,
      "cursorHideTimeout": 0,
      "hideCursorOnKeyPress": false
    }, false).concat(NiriConf.optionNodes(schema.Workspaces, {
      "stripColumnWidth": 50
    }, false));
    const module = NiriConf.moduleText({
      "header": "// Generated by axiom",
      "includeLines": "include \"/home/u/.local/state/axiom/niri.kdl\"",
      "binds": binds,
      "outputs": NiriConf.outputNodes(rules),
      "options": options,
      "look": look,
      "input": input
    });
    _write("tests/.out/module.niri.kdl", module);
    const managed = NiriConf.managedText({
      "header": "// Generated by axiom",
      "userDir": "/home/u/.config/niri/user",
      "userFiles": ["00-previous.kdl", "10-mine.kdl"],
      "binds": binds,
      "outputs": NiriConf.outputNodes(rules),
      "options": options,
      "look": look,
      "input": input,
      "env": [
        {
          "name": "QT_QPA_PLATFORM",
          "value": "wayland;xcb"
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
          "command": "off-thing",
          "enabled": false
        }
      ],
      "isAgent": command => false
    });
    _write("tests/.out/managed.niri.kdl", managed);
    verify(managed.startsWith("// Generated by axiom (niri mode: managed)"), managed);
    verify(managed.includes(`include "/home/u/.config/niri/user/00-previous.kdl" optional=true`), managed);
    verify(managed.includes(`spawn-sh-at-startup "nm-applet"`) && !managed.includes("hypridle") && !managed.includes("off-thing"), managed);
    verify(managed.indexOf("binds {") < managed.indexOf("include ") && managed.indexOf("include ") < managed.indexOf("layout {"), managed);
    verify(managed.includes(`environment {\n    QT_QPA_PLATFORM "wayland;xcb"\n}`), managed);
    _write("tests/.out/released.niri.kdl", NiriConf.releasedText("/home/u/.config/niri/user", ["00-previous.kdl"], [NiriConf.node("spawn-sh-at-startup", ["qs -p '/opt/axiom' -n"])]));
    // The included mode's module after the user's files, so its look wins
    // (not written: niri would look for the module)
    const released = NiriConf.releasedText("/home/u/.config/niri/user", ["00-previous.kdl"], [NiriConf.node("spawn-sh-at-startup", ["qs -p '/opt/axiom' -n"])], [NiriConf.node("include", ["/home/u/.local/state/axiom/niri.kdl"])]);
    compare(released.split("\n").filter(line => line.startsWith("include")), [`include "/home/u/.config/niri/user/00-previous.kdl" optional=true`, `include "/home/u/.local/state/axiom/niri.kdl"`]);
    _write("tests/.out/empty.niri.kdl", NiriConf.emptyModuleText("// Generated by axiom"));
    // One `layout` and one `binds` in a file: niri refuses a second
    compare(module.match(/^layout \{/gm).length, 1);
    compare(module.match(/^binds \{/gm).length, 1);
  }

  function test_wrapper() {
    compare(NiriConf.wrapperText("// Generated by axiom", "/home/u/.config/niri/config.kdl", "/home/u/.local/state/axiom/niri-detached-module.kdl").split("\n").filter(line => line.startsWith("include")), [`include "/home/u/.config/niri/config.kdl"`, `include "/home/u/.local/state/axiom/niri-detached-module.kdl"`]);
  }
}
