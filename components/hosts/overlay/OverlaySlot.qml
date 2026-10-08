pragma ComponentBehavior: Bound
import QtQuick
// Modules are loaded by URL; importing their directory is what makes qs
// scan them, so their own qs.* imports (e.g. modules.settings) resolve
import qs.components.content // qmllint disable unused-imports

// Hosts one overlay module in its slot on a grid: loads content/<type>.qml and
// hands it the entry's `properties` (defaults filled from the schema, as
// for bar widgets). An empty slot renders nothing.
Item {
  id: root

  // A slot entry: { type, properties }, or undefined for an empty slot
  property var config
  // The slot's [x, y, w, h] in grid units (its place); passed on
  // as the module's `slotRect`, from which Card derives its shape
  property var rect: [0, 0, 4, 4]
  // Where the module is shown: { kind: "overlay" } or { kind: "edgeMenu",
  // id }, passed on as its `host`
  property var host: ({
      "kind": "overlay"
    })

  // The ModuleGrid hosting it, passed on as the module's `expander`
  property var expander: null

  anchors.fill: parent

  readonly property string componentPath: root.config?.type ? Qt.resolvedUrl("../../content/" + root.config.type + ".qml") : ""

  // Created with its properties already set, then bound so later config
  // edits reach it (as BarWidgetHost does)
  function _load() {
    if (!root.componentPath) {
      loader.source = "";
      return;
    }
    loader.setSource(root.componentPath, {
      "properties": root.config.properties || {},
      "slotRect": root.rect,
      "embedded": true,
      "host": root.host,
      "expander": root.expander
    });
  }
  onComponentPathChanged: _load()
  Component.onCompleted: _load()

  Loader {
    id: loader
    anchors.fill: parent
    onLoaded: {
      item.properties = Qt.binding(() => root.config?.properties || {});
      item.slotRect = Qt.binding(() => root.rect);
      item.host = Qt.binding(() => root.host);
      item.expander = Qt.binding(() => root.expander);
    }
  }
}
