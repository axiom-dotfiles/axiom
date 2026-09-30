import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "OverlayLayout"

  function cell(layout, extra) {
    return Object.assign({
      "layout": layout,
      "slots": {}
    }, extra ?? {});
  }

  function test_span() {
    // cardUnit 500, cardSpacing 20: a half unit is 240
    compare(OverlayLayout.halfUnitOf(), 240);
    compare(OverlayLayout.span(1), 240);
    compare(OverlayLayout.span(2), 500, "two halves are one card");
    compare(OverlayLayout.span(4), 1020, "two cards and the gap between");
    compare(OverlayLayout.span(2, 300), 300, "at another card size");
  }

  function test_slotShape() {
    compare(OverlayLayout.slotShape([0, 0, 2, 2]), "square");
    compare(OverlayLayout.slotShape([0, 0, 2, 1]), "horizontal");
    compare(OverlayLayout.slotShape([0, 0, 1, 2]), "vertical");
    verify(OverlayLayout.fitsShapes(["square", "vertical"], [0, 0, 1, 2]));
    verify(!OverlayLayout.fitsShapes(["square"], [0, 0, 4, 2]));
  }

  function test_columnFlow_empty() {
    const flow = OverlayLayout.columnFlow([]);
    compare(flow.width, 0);
    compare(flow.height, 0);
    compare(flow.rows, 0);
    compare(flow.rects.length, 0);
  }

  function test_columnFlow_wraps_at_widest() {
    // Singles after a Wide sit side by side under it
    const flow = OverlayLayout.columnFlow([cell("Wide"), cell("Single"), cell("Single")]);
    compare(flow.rows, 2);
    compare(flow.width, 1020);
    compare(flow.height, 1020);
    compare(flow.rects[1].x, 0);
    compare(flow.rects[1].y, 520);
    compare(flow.rects[2].x, 520);
    compare(flow.rects[2].y, 520);
    compare(flow.rects[2].row, 1);
  }

  function test_columnFlow_unknown_layout_is_single() {
    const flow = OverlayLayout.columnFlow([cell("Nope")]);
    compare(flow.width, 500);
    compare(flow.height, 500);
  }

  function test_columnFlow_fillWidth() {
    const flow = OverlayLayout.columnFlow([cell("Single", {
        "fillWidth": true
      })], undefined, {
      "width": 800
    });
    compare(flow.width, 800);
    compare(flow.rects[0].width, 800);
    // Without room to grow into, nothing changes
    compare(OverlayLayout.columnFlow([cell("Single", {
        "fillWidth": true
      })]).width, 500);
  }

  function test_columnFlow_fillHeight() {
    // Spare height goes to the row holding the fill cell
    const flow = OverlayLayout.columnFlow([cell("Single"), cell("Single", {
        "fillHeight": true
      })], undefined, {
      "height": 1500
    });
    compare(flow.height, 1500);
    compare(flow.rects[0].height, 500);
    compare(flow.rects[1].y, 520);
    compare(flow.rects[1].height, 980);
  }

  function test_columnFlow_extra() {
    // Every cell grows: the width per row, the height split between rows
    const flow = OverlayLayout.columnFlow([cell("Single"), cell("Single")], undefined, null, {
      "width": 100,
      "height": 40
    });
    compare(flow.width, 600);
    compare(flow.height, 1060);
    compare(flow.rects[0].width, 600);
    compare(flow.rects[0].height, 520);
    compare(flow.rects[1].y, 540);
  }

  function test_columnsLength() {
    const flows = [
      {
        "width": 500,
        "height": 1020
      },
      {
        "width": 1020,
        "height": 500
      }
    ];
    compare(OverlayLayout.columnsLength(flows, true, 0), 1020, "vertical: the tallest");
    compare(OverlayLayout.columnsLength(flows, false, 0), 1540, "horizontal: end to end");
    compare(OverlayLayout.columnsLength(flows, false, 60), 1600);
    compare(OverlayLayout.columnsLength([], false, 60), 0, "no extra without columns");
  }

  function test_moveTo() {
    let arr = ["a", "b", "c", "d"];
    compare(OverlayLayout.moveTo(arr, 0, 2), 1);
    compare(arr, ["b", "a", "c", "d"]);
    arr = ["a", "b", "c", "d"];
    compare(OverlayLayout.moveTo(arr, 0, 1), -1, "just after itself stays");
    compare(arr, ["a", "b", "c", "d"]);
    compare(OverlayLayout.moveTo(arr, 3, 0), 0);
    compare(arr, ["d", "a", "b", "c"]);
    compare(OverlayLayout.moveTo(arr, 7, 0), -1);
  }

  function test_remapSlots() {
    const fits = (module, rect) => OverlayLayout.fitsShapes(module.shapes, rect);
    const a = {
      "shapes": ["horizontal"]
    };
    const b = {
      "shapes": ["vertical"]
    };
    const horiz = OverlayLayout.layouts.Horiz1x1.slots;
    const result = OverlayLayout.remapSlots({
      "left": a,
      "right": b
    }, horiz, fits);
    compare(result.slots.top, a, "moved to a free slot it fits");
    verify(!("bottom" in result.slots), "one fitting nowhere is dropped");
    compare(result.moved.left, "top");
    // Same-named slots are kept as they are
    const same = OverlayLayout.remapSlots({
      "main": b
    }, OverlayLayout.layouts.Wide.slots, fits);
    compare(same.slots.main, b);
    compare(Object.keys(same.moved).length, 0);
  }
}
