pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// i18n: keys from the schema (titles, descriptions)
// One group of settings (a section's own fields, or one nested object) as
// a card: title, help text, then its rows. Clicking the header folds it
// (remembered by SettingsManager); search results are always unfolded.
FoldingCard {
  id: root

  // A SchemaLayout.groups() entry, rows possibly filtered by a search
  required property var group
  // Provides valueAt(path) and edited(path, value) (SettingsContent)
  required property var form
  // Searching: name the section too, since cards come from all over
  property bool showSection: false

  title: I18n.tr(root.group.title)
  description: root.group.description === "" ? "" : I18n.tr(root.group.description)
  section: root.showSection && root.group.section !== root.group.title ? I18n.tr(root.group.section) : ""
  foldable: !root.showSection
  collapsed: !root.showSection && SettingsManager.isCollapsed(root.group.key)
  // Folded with unsaved edits inside: marked, so they aren't forgotten
  marked: root.group.rows.some(row => SettingsManager.hasChangesUnder(row.path.join(".")))
  onToggled: SettingsManager.setCollapsed(root.group.key, !root.collapsed)

  // The section's `x-intro` (settings/<name>.qml): status and actions
  // above the fields
  Loader {
    active: !!root.group.intro
    visible: active
    Layout.fillWidth: true
    source: active ? Qt.resolvedUrl(root.group.intro + ".qml") : ""
  }

  // Rows a field marked `x-beside` shares with the field before it, each
  // taking half; every other field takes the whole width
  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Widget.spacing * 2
    rowSpacing: Widget.spacing * 1.5

    Repeater {
      model: root.group.rows

      delegate: SettingsField {
        required property var modelData
        required property int index
        readonly property bool half: modelData.schema?.["x-beside"] === true || root.group.rows[index + 1]?.schema?.["x-beside"] === true
        row: modelData
        form: root.form
        Layout.columnSpan: half ? 1 : 2
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
      }
    }
  }
}
