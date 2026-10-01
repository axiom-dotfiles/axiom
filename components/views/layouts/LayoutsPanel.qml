pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions)
// Layouts editor, left: the overlay pages and the edge menus, then what's
// selected: a page's name and icon, or a menu's settings in groups
// (from the schema's EdgeMenu definition, its Opening group led by how to
// try and open it), and anything that blocks saving
Item {
  id: root

  required property var dragLayer

  // What's being edited (Layouts): a page (`view`), or a `menu`
  required property bool editingMenu
  required property var view
  required property var menu
  readonly property bool isCustom: root.view?.type === "Custom"
  readonly property var problems: OverlayManager.problems.concat(EdgeMenuManager.problems)

  // StyledTextEntry writes each keystroke back to its `text`, which drops
  // any binding on it, so the name is pushed in rather than bound: on every
  // draft change unless it's being typed, always when another page is
  // selected
  function syncName(force) {
    if (force || !nameEntry.input.activeFocus)
      nameEntry.text = OverlayManager.selectedView()?.name ?? "";
  }
  Connections {
    target: OverlayManager
    function onSelectedViewIndexChanged() {
      root.syncName(true);
    }
    function onLocalViewsChanged() {
      root.syncName(false);
    }
  }
  Component.onCompleted: root.syncName(true)

  // Group titles: I18n.tr("General") I18n.tr("Opening") I18n.tr("Placement")
  // I18n.tr("Style") I18n.tr("Closing") I18n.tr("Advanced") I18n.tr("Other")
  TitledCard {
    title: I18n.tr("Layouts")
    showActions: false

    PagesSection {
      Layout.fillWidth: true
      dragLayer: root.dragLayer
    }

    MenusSection {
      Layout.fillWidth: true
      dragLayer: root.dragLayer
    }

    StyledSeparator {
      Layout.fillWidth: true
      Layout.topMargin: Widget.spacing
      opacity: 0.3
    }

    // A Custom page
    FieldGroup {
      visible: root.isCustom
      Layout.topMargin: Widget.spacing
      title: I18n.tr("Page")
      description: I18n.tr("Its name and icon show in the page navigator.")

      StyledTextEntry {
        id: nameEntry
        Layout.fillWidth: true
        placeholderText: I18n.tr("Page name")
        onTextChanged: {
          if (nameEntry.input.activeFocus)
            OverlayManager.renameView(OverlayManager.selectedViewIndex, nameEntry.text);
        }
      }

      SchemaPropertiesForm {
        Layout.fillWidth: true
        propertiesSchema: ({
            "icon": OverlayConfig.customViewSchema.icon
          })
        values: root.view ?? ({})
        onEdited: (path, value) => OverlayManager.updateViewField(OverlayManager.selectedViewIndex, path[0], value)
      }
    }

    // A tool page
    FieldGroup {
      visible: root.view !== null && !root.isCustom
      Layout.topMargin: Widget.spacing
      title: I18n.tr("Tool page")
      description: I18n.tr("A page of its own, with no layout to edit. Tools show as icons after your pages in the navigator.")

      SchemaSwitch {
        label: I18n.tr("Show in the navigator")
        checked: root.view?.visible !== false
        onToggled: newValue => OverlayManager.setViewVisible(OverlayManager.selectedViewIndex, newValue)
      }
    }

    // An edge menu. A ColumnLayout's Repeater re-runs its model on every
    // draft edit: the condition keeps the model the same while one is
    // selected
    Repeater {
      model: root.menu !== null ? EdgeMenusConfig.fieldGroups : []

      delegate: FieldGroup {
        id: group
        required property var modelData
        Layout.topMargin: Widget.spacing
        title: I18n.tr(group.modelData.title)

        Loader {
          Layout.fillWidth: true
          active: group.modelData.title === "Opening"
          visible: active
          sourceComponent: MenuOpening {
            menu: root.menu
          }
        }

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
      visible: root.problems.length > 0
      Layout.topMargin: Widget.spacing
      title: I18n.tr("Can't save yet")

      IssueList {
        issues: root.problems.map(text => ({
              "level": "error",
              "text": text
            }))
      }
    }
  }
}
