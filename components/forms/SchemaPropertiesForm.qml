pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A form for one flat object, generated from its `properties` schema: one
// SchemaField per key (keys marked `x-settings: false` skipped), valued
// from `values` with schema defaults for what's missing. Used for array
// items, bar widget options and overlay module options; it acts as the
// `form` for its SchemaField rows.
ColumnLayout {
  id: root

  // { key: propertySchema }
  required property var propertiesSchema
  property var values: ({})
  // Keys to put first, in this order (the schema's `x-order`): the schema
  // reaches QML as a map, whose keys come out sorted
  property var order: []

  // Emitted with the key path ([key]) of the edited field
  signal edited(var path, var value)

  // Depends on the schema only, so edits update the rows in place
  readonly property var rows: Object.keys(root.propertiesSchema ?? {}).sort((a, b) => {
    const rank = key => {
      const index = (root.order ?? []).indexOf(key);
      return index < 0 ? Infinity : index;
    };
    return rank(a) - rank(b);
  }).filter(key => {
    const prop = root.propertiesSchema[key];
    return prop["x-settings"] !== false && prop.type !== "object";
  }).map(key => {
    const prop = root.propertiesSchema[key];
    return {
      "kind": prop.type === "array" && prop.items?.properties ? "array" : "field",
      "title": prop.title ?? key,
      "path": [key],
      "schema": prop
    };
  })

  function valueAt(path) {
    return root.values?.[path[0]] ?? root.propertiesSchema?.[path[0]]?.default;
  }

  spacing: Widget.spacing

  Repeater {
    model: root.rows

    // Loaded by URL: SchemaField (through SchemaObjectArray and
    // SchemaArrayItem) instantiates this type, so naming it here would make
    // the types depend on each other
    delegate: Loader {
      required property var modelData
      Layout.fillWidth: true
      // SchemaField hides itself for `x-showIf`; follow it so the layout
      // doesn't keep its space (`shown`, not `visible`: that would read
      // false forever once this Loader hides)
      visible: item?.shown ?? false
      Component.onCompleted: setSource(Qt.resolvedUrl("SchemaField.qml"), {
        "row": modelData,
        "form": root
      })
    }
  }
}
