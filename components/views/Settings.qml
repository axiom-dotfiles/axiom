pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.components.methods
import qs.components.views.settings

// The settings page, generated from the config schema: categories (in
// `x-categories` order) and search on the left, the selected category's
// groups in two columns on the right. Edits go through SettingsManager's
// draft.
BaseView {
  id: root

  readonly property var categories: SchemaLayout.categories(ConfigManager.configSchema)
  readonly property var category: categories.find(c => c.name === SettingsManager.category) ?? categories[0]

  Component.onCompleted: SettingsManager.ensureLoaded()

  SettingsSidebar {
    implicitWidth: root.grid.unit * 0.6
    implicitHeight: root.pageHeight
    categories: root.categories
    selected: root.category.name
    cards: content.shownGroups
  }

  SettingsContent {
    id: content
    implicitWidth: root.grid.unit * 2
    implicitHeight: root.pageHeight
    categories: root.categories
    category: root.category
  }
}
