pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.components.methods
import qs.components.views.settings

// The settings page, generated from the config schema: categories and
// search on the left, the selected category's groups in two columns on the
// right. Edits go through SettingsManager's draft.
BaseView {
  id: root

  // `x-category` groups from the schema, then saved configurations
  readonly property var categories: SchemaLayout.categories(ConfigManager.configSchema).concat([
    {
      "name": "Backups",
      "sections": [],
      "links": []
    }
  ])
  readonly property var category: categories.find(c => c.name === SettingsManager.category) ?? categories[0]

  readonly property real pageHeight: root.grid.span(4)

  Component.onCompleted: SettingsManager.ensureLoaded()

  SettingsSidebar {
    implicitWidth: root.grid.unit * 0.6
    implicitHeight: root.pageHeight
    categories: root.categories
    selected: root.category.name
  }

  SettingsContent {
    implicitWidth: root.grid.unit * 2
    implicitHeight: root.pageHeight
    // Schema categories only: search never covers Backups
    categories: root.categories.slice(0, -1)
    category: root.category
  }
}
