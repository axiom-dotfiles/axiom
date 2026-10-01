pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.methods
import qs.components.reusable

// One settings row: the SchemaField, with a dot while it has an unsaved
// edit and a button that puts it back to the schema default, and under a
// field with `x-hookup` (theme integrations) the IntegrationHookup panel
Item {
  id: root

  required property var row
  required property var form

  readonly property bool isValue: row.kind !== "group"
  readonly property var defaultValue: row.schema?.default
  readonly property bool changed: isValue && SettingsManager.isChanged(row.path)
  readonly property bool atDefault: defaultValue === undefined || JSON.stringify(field.current) === JSON.stringify(defaultValue)

  Layout.fillWidth: true
  implicitHeight: field.implicitHeight + hookup.shownHeight
  visible: field.shown

  SchemaField {
    id: field
    width: root.width
    row: root.row
    form: root.form
    // The dot and reset button's full width, kept even while they're
    // hidden, so their appearing doesn't shift a stepper under the cursor
    headerInset: 8 + Widget.spacing / 2 + Appearance.fontSize + 8 + Widget.spacing
  }

  Loader {
    id: hookup
    // Its height and the gap above it, while it shows
    readonly property real shownHeight: {
      const panel = hookup.item as Item;
      return panel && panel.visible ? panel.implicitHeight + Widget.spacing : 0;
    }
    y: field.implicitHeight + Widget.spacing
    width: root.width
    active: root.isValue && !!root.row.schema?.["x-hookup"]
    sourceComponent: IntegrationHookup {
      integration: root.row.path[root.row.path.length - 1]
      active: field.current === true
    }
  }

  Row {
    anchors.top: parent.top
    anchors.right: parent.right
    spacing: Widget.spacing / 2
    visible: root.isValue

    UnsavedDot {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.changed
    }

    SquareIconButton {
      visible: !root.atDefault
      size: Appearance.fontSize + 8
      iconText: "undo"
      iconSize: Appearance.fontSize - 1
      backgroundColor: Theme.backgroundHighlight
      tooltipText: I18n.tr("Reset to default")
      onClicked: root.form.edited(root.row.path, Utils.clone(root.defaultValue))
    }
  }
}
