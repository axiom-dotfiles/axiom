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
  // What `$` keys in an `x-showIf` read, by key (a bar widget's
  // `$bar.<key>`: Bar.lookContext)
  property var context: ({})
  // Keys to put first, in this order (the schema's `x-order`): the schema
  // reaches QML as a map, whose keys come out sorted
  property var order: []
  // Forces every integer row's control ("slider" or "stepper"), over the
  // schema's `x-control`; empty leaves it to each field
  property string numberMode: ""
  // Puts a field marked `x-beside` beside the one before it, each half wide,
  // while both are shown; off, every field takes the whole width
  property bool pairs: false

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

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Widget.spacing * 2
    rowSpacing: root.spacing

    Repeater {
      id: fields
      model: root.rows

      // The field, then its `x-link`s
      delegate: ColumnLayout {
        id: cell
        required property var modelData
        required property int index
        // SchemaField hides itself for `x-showIf`; follow it so the layout
        // doesn't keep its space (`shown`, not `visible`: that would read
        // false forever once this cell hides)
        readonly property bool shown: field.item?.shown ?? false
        readonly property bool _beside: modelData.schema?.["x-beside"] === true
        // Read again once every field exists (`count` changes after the
        // Repeater made them): itemAt doesn't notify, and the field after
        // this one doesn't exist yet when it's made
        readonly property var _partner: fields.count < 0 ? null : _beside ? fields.itemAt(index - 1) : root.rows[index + 1]?.schema?.["x-beside"] === true ? fields.itemAt(index + 1) : null
        readonly property bool half: root.pairs && (_partner?.shown ?? false)
        Layout.fillWidth: true
        Layout.columnSpan: half ? 1 : 2
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        visible: shown
        spacing: Widget.spacing / 2

        // Loaded by URL: SchemaField (through SchemaObjectArray and
        // SchemaArrayItem) instantiates this type, so naming it here would
        // make the types depend on each other
        Loader {
          id: field
          Layout.fillWidth: true
          Component.onCompleted: setSource(Qt.resolvedUrl("SchemaField.qml"), {
            "row": cell.modelData,
            "form": root
          })
        }

        FieldLinks {
          Layout.fillWidth: true
          links: cell.modelData.schema?.["x-link"]
        }
      }
    }
  }
}
