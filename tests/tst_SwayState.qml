import QtQuick
import QtTest
import qs.components.methods

// SwayState: sway's IPC replies (tests/fixtures/sway, from a nested sway) as
// the shapes the shell reads.
TestCase {
  name: "SwayState"

  RepoFiles {
    id: files
  }

  function fixture(name) {
    return files.json("tests/fixtures/sway/" + name + ".json");
  }

  function test_treeListsTheWindows() {
    const info = SwayState.tree(fixture("get_tree"));
    compare(info.windows.map(w => w.title), ["foot", "second", "floater", "tab1", "tab2"]);
    compare(info.focusedId, "11");
    compare(info.counts, {
      "1": 2,
      "2": 1,
      "3": 2
    });
  }

  function test_window() {
    const info = SwayState.tree(fixture("get_tree"));
    const win = info.windows.find(w => w.title === "floater");
    compare(win, {
      "id": "9",
      "appId": "foot",
      "initialAppId": "foot",
      "title": "floater",
      "workspaceId": 2,
      "workspaceName": "2",
      "output": "WL-1",
      "floating": true,
      "fullscreen": false,
      "maximized": false,
      "hidden": false,
      "focusRank": undefined,
      "x": 81,
      "y": 445,
      "w": 766,
      "h": 1243
    });
  }

  function test_tabsBehindTheFrontOneAreHidden() {
    const windows = SwayState.tree(fixture("get_tree")).windows;
    compare(windows.find(w => w.title === "tab1").hidden, false);
    compare(windows.find(w => w.title === "tab2").hidden, true);
    compare(windows.find(w => w.title === "tab2").workspaceName, "3:web");
  }

  function test_xwaylandWindowsUseTheirClass() {
    const win = SwayState.window({
      "id": 7,
      "app_id": null,
      "window_properties": {
        "class": "steam"
      },
      "name": "Steam",
      "fullscreen_mode": 2,
      "rect": {
        "x": 0,
        "y": 0,
        "width": 10,
        "height": 10
      }
    }, {
      "num": 4,
      "name": "4"
    }, "DP-1", false, false);
    compare(win.appId, "steam");
    compare(win.fullscreen, true);
  }

  function test_focusOrderFollowsSwaysStacks() {
    compare(SwayState.tree(fixture("get_tree")).order.slice(0, 5), ["11", "12", "5", "6", "9"]);
  }

  function test_ranked() {
    const info = SwayState.tree(fixture("get_tree"));
    const ranked = SwayState.ranked(info.windows, ["9", "11"], info.order, info.focusedId);
    const rank = title => ranked.find(w => w.title === title).focusRank;
    compare(rank("tab1"), 0);
    compare(rank("floater"), 1);
    compare(rank("tab2"), 2);
    compare(rank("foot"), 3);
  }

  function test_touch() {
    compare(SwayState.touch(["a", "b", "c"], "c"), ["c", "a", "b"]);
    compare(SwayState.touch(["a", "b"], "z", 2), ["z", "a"]);
    compare(SwayState.touch(null, "a"), ["a"]);
  }

  function test_outputReservesWhatTheWorkspaceLeaves() {
    const info = SwayState.tree(fixture("get_tree"));
    const out = SwayState.output({
      "name": "WL-1",
      "x": 0,
      "y": 0,
      "width": 822,
      "height": 1336,
      "scale": 1,
      "focused": true,
      "activeWorkspace": {
        "num": 3,
        "name": "3:web"
      },
      "lastIpcObject": {
        "make": "AOC",
        "model": "CU34G4Z",
        "serial": "XJ9R7HA000000"
      }
    }, info);
    compare(out.description, "AOC CU34G4Z XJ9R7HA000000");
    compare(out.activeWorkspaceId, 3);
    compare(out.specialWorkspaceId, 0);
    compare(out.reserved, {
      "left": 48,
      "top": 58,
      "right": 8,
      "bottom": 8
    });
    // Sway takes the edge gaps off the workspace too
    compare(SwayState.output({
      "name": "WL-1",
      "x": 0,
      "y": 0,
      "width": 822,
      "height": 1336,
      "activeWorkspace": {
        "num": 3,
        "name": "3:web"
      }
    }, info, {
      "top": 8,
      "right": 8,
      "bottom": 8,
      "left": 8
    }).reserved, {
      "left": 40,
      "top": 50,
      "right": 0,
      "bottom": 0
    });
  }

  function test_outputOnANamedWorkspace() {
    const out = SwayState.output({
      "name": "WL-1",
      "activeWorkspace": {
        "num": -1,
        "name": "music"
      },
      "lastIpcObject": {
        "make": "Unknown",
        "model": "Unknown",
        "serial": "Unknown"
      }
    }, null);
    compare(out.activeWorkspaceId, -1);
    compare(out.description, "");
    compare(out.reserved.top, 0);
  }

  function test_workspace() {
    compare(SwayState.workspace({
      "num": 3,
      "name": "3:web",
      "monitor": {
        "name": "WL-1"
      },
      "active": true,
      "focused": true
    }, {
      "3": 2
    }), {
      "id": 3,
      "name": "3:web",
      "output": "WL-1",
      "windowCount": 2,
      "active": true,
      "focused": true
    });
    compare(SwayState.workspace({
      "num": -1,
      "name": "music"
    }, {}), null);
  }

  function test_keyboard() {
    compare(SwayState.keyboard(fixture("get_inputs"), ""), {
      "layouts": ["us"],
      "index": 0,
      "keymap": "English (US)"
    });
    const two = [
      {
        "type": "keyboard",
        "name": "Power Button",
        "xkb_layout_names": ["English (US)"]
      },
      {
        "type": "keyboard",
        "name": "Some Keyboard",
        "xkb_layout_names": ["English (US)", "German"],
        "xkb_active_layout_index": 1,
        "xkb_active_layout_name": "German"
      }
    ];
    compare(SwayState.keyboard(two, "us, de"), {
      "layouts": ["us", "de"],
      "index": 1,
      "keymap": "German"
    });
    compare(SwayState.keyboard(two, "us").layouts, ["us", "ge"]);
    compare(SwayState.keyboard([], "us"), null);
  }

  function test_configInfo() {
    const info = SwayState.configInfo("set $mod Mod4\n# gaps outer 99\ngaps inner 3\ngaps outer 6\ngaps vertical 2\nworkspace 2 gaps outer 40\ninput type:keyboard {\n    xkb_layout us,de\n}\ninput * xkb_layout fr\n");
    compare(info.gaps, {
      "top": 5,
      "right": 9,
      "bottom": 5,
      "left": 9
    });
    compare(info.layouts, "us,de");
    compare(SwayState.configInfo(""), {
      "gaps": {
        "top": 0,
        "right": 0,
        "bottom": 0,
        "left": 0
      },
      "layouts": ""
    });
  }

  function test_outputDetails() {
    const details = SwayState.outputDetails(fixture("get_outputs"));
    compare(details.length, 2);
    const main = details[0];
    compare(main.name, "DP-1");
    compare(main.description, "AOC CU34G4Z XJ9R7HA000000");
    compare([main.width, main.height, main.refreshRate, main.x, main.y, main.scale], [3440, 1440, 240, 15, 83, 1]);
    compare(main.transform, 0);
    compare(main.disabled, false);
    compare(main.mirrorOf, "none");
    compare(main.availableModes[0], "3440x1440@240.00Hz");
    // Reads back as the mode it is (MonitorLayout)
    compare(MonitorLayout.parseMode(main.availableModes[1]).rate, 60);
    const off = details[1];
    compare(off.disabled, true);
    compare(off.transform, 5);
    compare(off.vrr, false);
  }

  function test_specialToggle() {
    const info = SwayState.tree(fixture("get_tree"));
    const marks = SwayState.marks(fixture("get_tree"));
    compare(marks, {
      "15": ["axiom-special-gaming-x"]
    });
    // In the scratchpad: shown next
    compare(SwayState.specialToggle(info.windows, marks, "gaming", "WL-1"), {
      "ids": ["15"],
      "show": true
    });
    // Shown on this output: hidden next
    const shown = info.windows.concat([Object.assign({}, info.windows[0], {
        "id": "15"
      })]);
    compare(SwayState.specialToggle(shown, marks, "gaming", "WL-1").show, false);
    compare(SwayState.specialToggle(info.windows, marks, "music", "WL-1").ids, []);
  }

  // A group's name may hold "-": another group whose name it starts with
  // isn't it
  function test_specialGroup() {
    compare(SwayState.specialGroup("axiom-special-a-12"), "a");
    compare(SwayState.specialGroup("axiom-special-a-b-12"), "a-b");
    compare(SwayState.specialGroup("axiom-drop"), "");
    compare(SwayState.specialGroup("mine"), "");
    const marks = {
      "1": ["axiom-special-a-1"],
      "2": ["axiom-special-a-b-2"]
    };
    compare(SwayState.specialToggle([], marks, "a", "WL-1").ids, ["1"]);
    compare(SwayState.specialToggle([], marks, "a-b", "WL-1").ids, ["2"]);
  }
}
