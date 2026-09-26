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
}
