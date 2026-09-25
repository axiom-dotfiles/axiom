pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// Settings page, right: the selected category's groups as cards in two
// columns, or every setting matching the search. Acts as the `form` for
// its SchemaField rows.
Item {
  id: root

  required property var categories
  // The selected entry of `categories`
  required property var category

  readonly property var schema: ConfigManager.configSchema
  readonly property string query: SettingsManager.query.trim().toLowerCase()
  readonly property bool searching: query !== ""
  readonly property bool backups: !searching && category?.name === "Backups"

  signal edited(var path, var value)
  onEdited: (path, value) => SettingsManager.setValue(path, value)

  function valueAt(path) {
    let value = SettingsManager.localConfig;
    for (const key of path)
      value = value?.[key];
    return value;
  }

  function _groupsOf(category) {
    return [].concat(...(category?.sections ?? []).map(section => SchemaLayout.groups(root.schema, section)));
  }

  // Matches English and the translation, so either can be typed
  function _matches(text) {
    return !!text && (text.toLowerCase().includes(root.query) || I18n.tr(text).toLowerCase().includes(root.query));
  }

  // A card from an object with `x-showIf` (e.g. managed-only settings)
  function _groupShown(group) {
    return SchemaLayout.showIfHolds(group.showIf, key => key.startsWith("/") ? SettingsManager.configValueAt(key.slice(1)) : root.valueAt(group.showIfParent.concat(key)));
  }

  function _rowMatches(row) {
    return row.kind !== "group" && (_matches(row.title) || _matches(row.schema?.description) || row.path[row.path.length - 1].toLowerCase().includes(root.query));
  }

  // From the schema, category and search only: never from config values,
  // so editing doesn't rebuild the cards
  readonly property var groups: {
    if (!root.searching)
      return root._groupsOf(root.category);
    // Hand-built cards have no rows to search
    const all = [].concat(...root.categories.map(c => root._groupsOf(c))).filter(group => group.kind !== "card");
    return all.map(group => {
      const rows = root._matches(group.title) || root._matches(group.section) ? group.rows : group.rows.filter(row => root._rowMatches(row));
      return rows.length > 0 ? Object.assign({}, group, {
        "rows": rows
      }) : null;
    }).filter(group => group !== null);
  }

  // Which groups are shown, as a string so it only notifies when that
  // actually changes, not on every edit
  readonly property string _shownKey: root.groups.map(group => root._groupShown(group) ? "1" : "0").join("")

  // Masonry: each shown group goes to the shorter column, by estimated
  // height
  readonly property var columns: {
    const result = [[], []];
    const heights = [0, 0];
    const shown = root._shownKey;
    for (let i = 0; i < root.groups.length; i++) {
      if (shown[i] !== "1")
        continue;
      const group = root.groups[i];
      const weight = group.kind === "card" ? 6 : 2 + group.rows.reduce((sum, row) => sum + (row.kind === "array" ? 4 : row.schema?.description ? 1.6 : 1.2), 0);
      const target = heights[0] <= heights[1] ? 0 : 1;
      result[target].push(group);
      heights[target] += weight;
    }
    return result;
  }

  // Pages the category links to: the overlay editor always exists, others
  // only while they're in Overlay.views
  function _linkAvailable(type) {
    return type === "OverlayEditor" || OverlayConfig.views.some(view => view.type === type && view.visible !== false);
  }

  function _linkLabel(type) {
    switch (type) {
    case "Themes":
      return I18n.tr("Themes");
    case "BarEditor":
      return I18n.tr("Bar Editor");
    case "OverlayEditor":
      return I18n.tr("Overlay Editor");
    case "Keybinds":
      return I18n.tr("Keybinds");
    }
    return type;
  }

  readonly property var links: root.searching ? [] : (root.category?.links ?? []).filter(type => root._linkAvailable(type))

  TitledCard {
    color: Theme.background
    // I18n.tr("Search results") and category names, see SettingsSidebar
    title: root.searching ? I18n.tr("Search results") : (root.category ? I18n.tr(root.category.name) : "")
    dirty: SettingsManager.isDirty
    onSave: SettingsManager.saveChanges()
    onReset: SettingsManager.resetChanges()

    headerExtras: Flow {
      Layout.fillWidth: true
      visible: root.links.length > 0
      spacing: Widget.spacing

      StyledText {
        height: Widget.height - 4
        verticalAlignment: Text.AlignVCenter
        text: I18n.tr("More in")
        opacity: 0.6
      }

      Repeater {
        model: root.links

        delegate: StyledTextButton {
          required property string modelData
          height: Widget.height - 4
          text: root._linkLabel(modelData)
          iconText: "chevron_right"
          iconAfter: true
          onClicked: ShellManager.showOverlayPage(modelData)
        }
      }
    }

    StyledText {
      visible: root.searching && root.groups.length === 0
      text: I18n.tr("No settings match \"{0}\"", SettingsManager.query)
      opacity: 0.6
      Layout.fillWidth: true
      Layout.topMargin: Widget.padding
    }

    RowLayout {
      visible: !root.backups
      Layout.fillWidth: true
      spacing: Widget.spacing * 2

      Repeater {
        model: 2

        delegate: ColumnLayout {
          id: column
          required property int index
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.alignment: Qt.AlignTop
          spacing: Widget.spacing * 2

          Repeater {
            model: root.columns[column.index]

            // A hand-built card (`x-card`: settings/<name>Card.qml) or rows
            delegate: Loader {
              id: card
              required property var modelData
              Layout.fillWidth: true
              Component.onCompleted: {
                if (card.modelData.kind === "card")
                  card.setSource(Qt.resolvedUrl(card.modelData.card + "Card.qml"));
                else
                  card.sourceComponent = rowsCard;
              }

              Component {
                id: rowsCard
                SettingsGroupCard {
                  group: card.modelData
                  form: root
                  showSection: root.searching
                }
              }
            }
          }
        }
      }
    }

    SavedConfigsSection {
      visible: root.backups
      Layout.fillWidth: true
    }
  }
}
