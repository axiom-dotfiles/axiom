import QtQuick
import QtTest
import qs.components.methods

// The stacking order of axiom's layer surfaces (LayerStack)
TestCase {
  name: "LayerStack"

  function order(ns) {
    return LayerStack.layers.find(l => l.namespace === ns).order;
  }

  function test_one_entry_per_namespace() {
    const names = LayerStack.layers.map(l => l.namespace);
    compare(names.length, new Set(names).size);
  }

  // The order BarEnds.rank assumes: solid, the border, pills, transparent,
  // floating, then docks; of a kind, the shorter edge's bar first
  function test_bar_layers_in_corner_order() {
    const chain = ["bar", "bar-long", "border", "bar-pill", "bar-pill-long", "bar-transparent", "bar-transparent-long", "bar-floating", "bar-floating-long", "dock"];
    for (let i = 1; i < chain.length; i++)
      verify(order(chain[i - 1]) > order(chain[i]), chain[i - 1] + " before " + chain[i]);
    compare(LayerStack.barLayers.length, 8);
  }

  // The blur window over the overlay sits strictly between the overlay and
  // every Overlay-layer surface it draws fills for
  function test_blur_over_overlay_order() {
    const backing = order("blur-backing-overlay");
    verify(order("overlay") > backing);
    for (const ns of ["osd", "dock-preview", "edge-popout", "popout"])
      verify(backing > order(ns), "under " + ns);
    verify(LayerStack.layers.find(l => l.namespace === "blur-backing-overlay").noAnim);
  }

  function test_orderOf() {
    compare(LayerStack.orderOf("axiom-bar"), 5);
    compare(LayerStack.orderOf("dock"), -7);
    compare(LayerStack.orderOf("axiom-desktop"), 0, "listed without an order");
    compare(LayerStack.orderOf("someone-else"), 0, "not listed");
  }
}
