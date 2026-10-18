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

  // Through a string, so it only notifies when the categories actually
  // change: sections' `x-showIf` read the config (`/Compositor.mode`), and
  // new objects on every edit would rebuild every card (a flash per edit)
  readonly property string _categoriesKey: JSON.stringify(SchemaLayout.categories(ConfigManager.configSchema, SettingsManager.showIfValue))
  readonly property var categories: JSON.parse(_categoriesKey)
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
