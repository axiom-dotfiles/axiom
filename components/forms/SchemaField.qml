pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// i18n: keys from callers and the schema (titles, descriptions, type labels)
// One row of a schema-driven form: picks the control for the row's schema
// type (or a list editor for an array of objects), hidden while its
// `x-showIf` doesn't hold. `form` provides valueAt(path) and an
// edited(path, value) signal (SchemaPropertiesForm, or the settings page's
// SettingsContent).
Loader {
  id: root

  required property var row
  required property var form

  readonly property var fieldSchema: row.schema ?? ({})
  readonly property var current: form.valueAt(row.path)
  readonly property string label: row.title
  readonly property string description: fieldSchema.description ?? ""
  readonly property bool isColor: fieldSchema["x-options"] === "colors"
  readonly property var options: SettingsManager.optionsFor(fieldSchema)
  // Labels shown for option values (`x-enumLabels`, or language names)
  readonly property var optionLabels: {
    if (fieldSchema["x-options"] === "languages")
      return I18n.languages.reduce((labels, l) => {
        labels[l.code] = l.name;
        return labels;
      }, {});
    // Schema labels are English, translated like titles
    const labels = fieldSchema["x-enumLabels"] ?? {};
    return Object.keys(labels).reduce((out, value) => {
      out[value] = I18n.tr(labels[value]);
      return out;
    }, {});
  }

  // `x-showIf`, checked against sibling keys of this row's path (or a
  // `/`-rooted config path), in any form
  readonly property bool shown: {
    const parent = row.path.slice(0, -1);
    return SchemaLayout.showIfHolds(fieldSchema["x-showIf"], key => key.startsWith("/") ? SettingsManager.configValueAt(key.slice(1)) : form.valueAt(parent.concat(key)));
  }

  visible: shown

  Layout.fillWidth: true

  function commit(value) {
    // Arrays (a string list) are new each time: compare their contents
    const same = Array.isArray(value) ? JSON.stringify(value) === JSON.stringify(root.current) : value === root.current;
    if (!same)
      root.form.edited(root.row.path, value);
  }

  // Array rows: every edit commits a modified copy of the whole array
  function _arrayCopy() {
    return JSON.parse(JSON.stringify(root.current ?? []));
  }

  function addItem() {
    const items = _arrayCopy();
    items.push(SchemaValidation.applyDefaults({}, root.fieldSchema.items));
    root.commit(items);
  }

  function removeItem(index) {
    const items = _arrayCopy();
    items.splice(index, 1);
    root.commit(items);
  }

  function moveItem(from, to) {
    const items = _arrayCopy();
    items.splice(to, 0, items.splice(from, 1)[0]);
    root.commit(items);
  }

  function editItem(index, key, value) {
    const items = _arrayCopy();
    items[index][key] = value;
    root.commit(items);
  }

  sourceComponent: {
    if (row.kind === "group")
      return groupHeader;
    if (row.kind === "array")
      return arrayField;
    switch (fieldSchema.type) {
    case "array":
      // Strings only: from a fixed set (chips), or free text
      return fieldSchema.items?.enum ? chipsField : stringListField;
    case "boolean":
      return switchField;
    case "integer":
      return spinField;
    default:
      return root.options ? comboField : textField;
    }
  }

  Component {
    id: groupHeader
    StyledText {
      text: I18n.tr(root.label)
      font.bold: true
      textColor: Theme.accent
      topPadding: Widget.spacing
    }
  }

  Component {
    id: switchField
    SchemaSwitch {
      label: root.label
      description: root.description
      checked: root.current === true
      onToggled: value => root.commit(value)
    }
  }

  Component {
    id: spinField
    SchemaSpinBox {
      label: root.label
      description: root.description
      currentConfigValue: root.current ?? 0
      minimum: root.fieldSchema.minimum ?? 0
      maximum: root.fieldSchema.maximum ?? 9999
      onValueChanged: root.commit(value)
    }
  }

  Component {
    id: comboField
    SchemaComboBox {
      label: root.label
      description: root.description
      options: root.options
      optionLabels: root.optionLabels
      swatches: root.isColor
      currentValue: root.current ?? ""
      onSelectionChanged: value => root.commit(value)
    }
  }

  Component {
    id: arrayField
    SchemaObjectArray {
      label: root.label
      description: root.description
      items: root.current ?? []
      itemDelegate: Component {
        SchemaArrayItem {
          itemSchema: root.fieldSchema.items
          onItemEdited: (index, key, value) => root.editItem(index, key, value)
        }
      }
      onItemAdded: root.addItem()
      onItemRemoved: index => root.removeItem(index)
      onItemMoved: (from, to) => root.moveItem(from, to)
    }
  }

  Component {
    id: textField
    SchemaTextField {
      label: root.label
      description: root.description
      multiline: root.fieldSchema["x-multiline"] === true
      currentConfigValue: root.current ?? ""
      onValueChanged: root.commit(value)
    }
  }

  // An array of strings from `items.enum`: one toggle chip per option,
  // committed in the enum's order
  Component {
    id: chipsField
    ColumnLayout {
      spacing: 4
      StyledText {
        text: I18n.tr(root.label)
        Layout.fillWidth: true
      }
      Flow {
        Layout.fillWidth: true
        spacing: Widget.spacing / 2
        Repeater {
          model: root.fieldSchema.items.enum
          StyledTextButton {
            id: chip
            required property string modelData
            readonly property bool selected: (root.current ?? []).includes(chip.modelData)
            text: root.optionLabels[chip.modelData] ?? I18n.tr(chip.modelData)
            backgroundColor: chip.selected ? Theme.accent : Theme.backgroundHighlight
            textColor: chip.selected ? Theme.background : Theme.foreground
            onClicked: {
              const current = root.current ?? [];
              const next = chip.selected ? current.filter(v => v !== chip.modelData) : current.concat([chip.modelData]);
              root.commit(root.fieldSchema.items.enum.filter(v => next.includes(v)));
            }
          }
        }
      }
      StyledText {
        visible: root.description !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr(root.description)
        textSize: Appearance.fontSize - 2
        opacity: 0.6
      }
    }
  }

  // A free array of strings, edited as a comma-separated list
  Component {
    id: stringListField
    SchemaTextField {
      label: root.label
      description: root.description
      currentConfigValue: (root.current ?? []).join(", ")
      onValueChanged: root.commit(value.split(",").map(v => v.trim()).filter(v => v !== ""))
    }
  }
}
