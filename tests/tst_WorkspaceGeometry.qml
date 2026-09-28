import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "WorkspaceGeometry"

  function test_fitScale() {
    // 2×1 monitors of 100×50, 10 apart, in 210×200: width-bound at 1
    compare(WorkspaceGeometry.fitScale(210, 200, 100, 50, 10, 2, 1), 1);
    compare(WorkspaceGeometry.fitScale(210, 30, 100, 50, 10, 2, 1), 0.6);
    compare(WorkspaceGeometry.fitScale(10, 10, 0, 50, 0, 1, 1), 0.1);
  }

  function test_cellRect_and_cellAt_agree() {
    for (let i = 0; i < 5; i++) {
      const r = WorkspaceGeometry.cellRect(i, 40, 30, 5, 3);
      compare(WorkspaceGeometry.cellAt(r.x + 1, r.y + 1, 40, 30, 5, 3, 5), i);
    }
  }

  function test_cellAt_misses() {
    compare(WorkspaceGeometry.cellAt(42, 1, 40, 30, 5, 3, 5), -1, "gap");
    compare(WorkspaceGeometry.cellAt(-1, 1, 40, 30, 5, 3, 5), -1, "outside");
    compare(WorkspaceGeometry.cellAt(91, 36, 40, 30, 5, 3, 5), -1, "past the last cell");
  }

  function test_windowRect_clamps_into_the_cell() {
    const r = WorkspaceGeometry.windowRect({
      "at": [1900, 1000],
      "size": [400, 300]
    }, 1000, 0, 0.1, 100, 60);
    compare(r.w, 40);
    compare(r.h, 30);
    compare(r.x, 60);
    compare(r.y, 30);
    const tiny = WorkspaceGeometry.windowRect({}, 0, 0, 0.1, 100, 60);
    compare(tiny.w, 8);
  }

  function test_windowAt_prefers_floating() {
    const items = [
      {
        "address": "tiled",
        "floating": false,
        "rect": {
          "x": 0,
          "y": 0,
          "w": 100,
          "h": 100
        }
      },
      {
        "address": "float",
        "floating": true,
        "rect": {
          "x": 10,
          "y": 10,
          "w": 20,
          "h": 20
        }
      },
      {
        "address": "top",
        "floating": false,
        "rect": {
          "x": 0,
          "y": 0,
          "w": 50,
          "h": 50
        }
      }
    ];
    compare(WorkspaceGeometry.windowAt(items, 15, 15), "float");
    compare(WorkspaceGeometry.windowAt(items, 40, 40), "top");
    compare(WorkspaceGeometry.windowAt(items, 200, 200), "");
  }

  function test_dropTarget_splits_the_long_side() {
    const wide = [
      {
        "address": "w",
        "rect": {
          "x": 0,
          "y": 0,
          "w": 200,
          "h": 100
        }
      }
    ];
    const right = WorkspaceGeometry.dropTarget(wide, 150, 50, 1);
    compare(right.side, "right");
    compare(right.rect.x, 100);
    compare(right.rect.w, 100);
    // Multiplier 3: 200 wide is not > 300, so it splits top/bottom
    compare(WorkspaceGeometry.dropTarget(wide, 150, 10, 3).side, "top");
    compare(WorkspaceGeometry.dropTarget([], 0, 0, 1), null);
  }

  function test_resizeEdges() {
    const r = {
      "x": 0,
      "y": 0,
      "w": 90,
      "h": 90
    };
    const corner = WorkspaceGeometry.resizeEdges(r, 5, 85);
    verify(corner.left && corner.bottom && !corner.right && !corner.top);
    const middle = WorkspaceGeometry.resizeEdges(r, 40, 35);
    compare([middle.left, middle.right, middle.top, middle.bottom], [false, false, true, false]);
  }

  function test_orderMonitors_primary_first_then_by_key() {
    const monitors = [
      {
        "id": 2,
        "name": "HDMI-A-1",
        "key": "desc:c"
      },
      {
        "id": 0,
        "name": "DP-1",
        "key": "desc:a"
      },
      {
        "id": 1,
        "name": "DP-2",
        "key": "desc:b"
      }
    ];
    const ordered = WorkspaceGeometry.orderMonitors(monitors, "DP-2");
    compare(ordered.map(m => m.name), ["DP-2", "DP-1", "HDMI-A-1"]);
  }

  function test_orderMonitors_no_primary_connected_falls_back_to_key_order() {
    const monitors = [
      {
        "id": 2,
        "name": "HDMI-A-1",
        "key": "desc:c"
      },
      {
        "id": 0,
        "name": "DP-1",
        "key": "desc:a"
      }
    ];
    const ordered = WorkspaceGeometry.orderMonitors(monitors, "DP-2");
    compare(ordered.map(m => m.name), ["DP-1", "HDMI-A-1"]);
  }

  function test_orderMonitors_ignores_hyprland_connection_order() {
    const a = {
      "id": 0,
      "name": "DP-1",
      "key": "desc:a"
    };
    const b = {
      "id": 1,
      "name": "DP-2",
      "key": "desc:b"
    };
    const c = {
      "id": 2,
      "name": "HDMI-A-1",
      "key": "desc:c"
    };
    const expected = ["DP-2", "DP-1", "HDMI-A-1"];
    compare(WorkspaceGeometry.orderMonitors([a, b, c], "DP-2").map(m => m.name), expected);
    compare(WorkspaceGeometry.orderMonitors([c, a, b], "DP-2").map(m => m.name), expected);
    compare(WorkspaceGeometry.orderMonitors([b, c, a], "DP-2").map(m => m.name), expected);
  }

  function test_orderMonitors_survives_reconnect_by_key_not_name() {
    // DP-1 replugged into a different port: id/name change, key (the
    // description-based identity) stays the same.
    const monitors = [
      {
        "id": 5,
        "name": "DP-3",
        "key": "desc:a"
      },
      {
        "id": 1,
        "name": "DP-2",
        "key": "desc:b"
      }
    ];
    compare(WorkspaceGeometry.orderMonitors(monitors, "DP-2").map(m => m.key), ["desc:b", "desc:a"]);
  }

  function test_orderMonitors_removed_and_appended() {
    const a = {
      "id": 0,
      "name": "DP-1",
      "key": "desc:a"
    };
    const c = {
      "id": 2,
      "name": "HDMI-A-1",
      "key": "desc:c"
    };
    const d = {
      "id": 3,
      "name": "DP-3",
      "key": "desc:d"
    };
    // B disconnects, D connects later (appended, as Hyprland's own list
    // would do) — A and C should keep their relative order.
    compare(WorkspaceGeometry.orderMonitors([a, c, d], "").map(m => m.key), ["desc:a", "desc:c", "desc:d"]);
  }
}
