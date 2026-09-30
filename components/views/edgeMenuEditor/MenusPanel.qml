pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions)
// Edge menu editor, left: the menus, the switch that holds the selected one
// open on screen, then its own settings in groups (from the schema's
// EdgeMenu definition) and anything that blocks saving
Item {
  id: root

  readonly property bool hasMenu: root.menu !== null
  readonly property var menu: EdgeMenuManager.selectedMenu()
  readonly property bool previewingThis: !!root.menu && EdgeMenuManager.previewing !== "" && EdgeMenuManager.previewing === root.menu.id

  // Group titles: I18n.tr("General") I18n.tr("Placement") I18n.tr("Style")
  // I18n.tr("Behaviour") I18n.tr("Other")
  TitledCard {
    title: I18n.tr("Edge Menu Editor")
    dirty: EdgeMenuManager.isDirty
    canSave: EdgeMenuManager.problems.length === 0
    onSave: EdgeMenuManager.saveChanges()
    onReset: EdgeMenuManager.resetChanges()

    headerExtras: ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      Repeater {
        model: EdgeMenuManager.localMenus?.length ?? 0

        delegate: ListEntryRow {
          id: entry
          required property int index
          readonly property var entryMenu: EdgeMenuManager.localMenus[index] ?? ({})

          icon: Utils.edgeArrow(entry.entryMenu.edge)
          label: EdgeMenuManager.menuLabel(entry.entryMenu, entry.index)
          selected: EdgeMenuManager.selectedMenuIndex === entry.index
          dimmed: entry.entryMenu.enabled === false
          changed: EdgeMenuManager.menuChanged(entry.index)
          onClicked: EdgeMenuManager.selectMenu(entry.index)

          // Held open on screen by the editor
          badges: StyledIcon {
            visible: EdgeMenuManager.previewing !== "" && EdgeMenuManager.previewing === entry.entryMenu.id
            text: "visibility"
            textColor: entry.ink
          }

          RowAction {
            row: entry
            iconText: "content_copy"
            tooltipText: I18n.tr("Duplicate this menu")
            onClicked: EdgeMenuManager.duplicateMenu(entry.index)
          }

          RowAction {
            row: entry
            danger: true
            iconText: "close"
            tooltipText: I18n.tr("Remove this menu")
            onClicked: EdgeMenuManager.removeMenu(entry.index)
          }
        }
      }

      AddEntryButton {
        Layout.topMargin: Widget.spacing
        Layout.bottomMargin: Widget.spacing
        text: I18n.tr("New menu")
        onClicked: EdgeMenuManager.addMenu()
      }
    }

    FieldGroup {
      visible: root.menu !== null
      Layout.fillWidth: true
      title: I18n.tr("Try it")
      description: EdgeMenuManager.canPreview(root.menu) ? I18n.tr("Holds the menu open on its screen while you edit it, showing unsaved changes. Opened elsewhere by a bar Button (Edge menu action) or `qs -c axiom ipc call edgeMenu toggle {0}`.", root.menu?.id ?? "") : I18n.tr("Give the menu an id and enable it to show it.")

      StyledTextButton {
        Layout.fillWidth: true
        enabled: EdgeMenuManager.canPreview(root.menu)
        opacity: enabled ? 1 : 0.5
        iconText: root.previewingThis ? "visibility_off" : "visibility"
        text: root.previewingThis ? I18n.tr("Hide from screen") : I18n.tr("Show on screen")
        textPadding: 6
        backgroundColor: root.previewingThis ? Theme.accent : Theme.backgroundHighlight
        textColor: root.previewingThis ? Theme.background : Theme.foreground
        onClicked: EdgeMenuManager.togglePreviewing()
      }
    }

    // A ColumnLayout's Repeater re-runs its model on every draft edit:
    // `hasEntry` keeps the model the same while one is selected
    Repeater {
      model: root.hasMenu ? EdgeMenusConfig.fieldGroups : []

      delegate: FieldGroup {
        id: group
        required property var modelData
        title: I18n.tr(group.modelData.title)

        SchemaPropertiesForm {
          Layout.fillWidth: true
          propertiesSchema: group.modelData.schema
          order: group.modelData.keys
          // The whole menu, so x-showIf sees keys from other groups
          values: root.menu ?? ({})
          onEdited: (path, value) => EdgeMenuManager.updateMenuField(path[0], value)
        }
      }
    }

    FieldGroup {
      visible: EdgeMenuManager.problems.length > 0
      title: I18n.tr("Can't save yet")

      IssueList {
        issues: EdgeMenuManager.problems.map(text => ({
              "level": "error",
              "text": text
            }))
      }
    }
  }
}
