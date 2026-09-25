pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.reusable

// One settings row: the SchemaField, with a dot while it has an unsaved
// edit and a button that puts it back to the schema default
Item {
  id: root

  required property var row
  required property var form

  readonly property bool isValue: row.kind !== "group"
  readonly property var defaultValue: row.schema?.default
  readonly property bool changed: isValue && SettingsManager.isChanged(row.path)
  readonly property bool atDefault: defaultValue === undefined || JSON.stringify(field.current) === JSON.stringify(defaultValue)

  Layout.fillWidth: true
  implicitHeight: field.implicitHeight
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

  Row {
    anchors.top: parent.top
    anchors.right: parent.right
    spacing: Widget.spacing / 2
    visible: root.isValue

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.changed
      width: 8
      height: 8
      radius: 4
      color: Theme.accent
    }

    SquareIconButton {
      visible: !root.atDefault
      size: Appearance.fontSize + 8
      width: size
      height: size
      iconText: "undo"
      iconSize: Appearance.fontSize - 1
      backgroundColor: Theme.backgroundHighlight
      tooltipText: I18n.tr("Reset to default")
      onClicked: root.form.edited(root.row.path, JSON.parse(JSON.stringify(root.defaultValue)))
    }
  }
}
