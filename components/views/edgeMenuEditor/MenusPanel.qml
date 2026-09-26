pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions)
// Edge menu editor, left: the menus, the switch that holds the selected one
// open on screen, then its own settings in groups (from the schema's
// EdgeMenu definition) and anything that blocks saving
Item {
  id: root

  readonly property var menu: EdgeMenuManager.selectedMenu()
  readonly property var menuSchema: ConfigManager.configSchema.definitions?.EdgeMenu?.properties ?? ({})
  readonly property bool previewingThis: !!root.menu && EdgeMenuManager.previewing !== "" && EdgeMenuManager.previewing === root.menu.id

  // The EdgeMenu keys by group; any the schema adds later land in "Other".
  // Titles: I18n.tr("General") I18n.tr("Placement") I18n.tr("Style")
  // I18n.tr("Behaviour") I18n.tr("Other")
  readonly property var groups: {
    const named = [
      {
        "title": "General",
        "keys": ["name", "id", "enabled", "monitor"]
      },
      {
        "title": "Placement",
        "keys": ["mode", "edge", "position", "edgeDistance", "cardSize", "extraDepth"]
      },
      {
        "title": "Style",
        "keys": ["frame", "margin", "padding", "backgroundColor", "borderColor"]
      },
      {
        "title": "Behaviour",
        "keys": ["openOnHover", "openDelay", "triggerSize", "triggerLength", "closeOnLeave", "closeDelay", "closeOnOutsideClick"]
      }
    ];
    const grouped = [].concat(...named.map(g => g.keys)).concat(["columns"]);
    const other = Object.keys(root.menuSchema).filter(key => !grouped.includes(key));
    return named.concat(other.length > 0 ? [
      {
        "title": "Other",
        "keys": other
      }
    ] : []).map(g => ({
          "title": g.title,
          "keys": g.keys,
          "schema": g.keys.filter(key => key in root.menuSchema).reduce((out, key) => {
            out[key] = root.menuSchema[key];
            return out;
          }, {})
        }));
  }

  // Material Symbols arrow for the edge a menu opens from
  function edgeIcon(edge) {
    switch (edge) {
    case "Top":
      return "arrow_upward";
    case "Bottom":
      return "arrow_downward";
    case "Right":
      return "arrow_forward";
    }
    return "arrow_back";
  }

  TitledCard {
    color: Theme.background
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

        delegate: StyledContainer {
          id: entry
          required property int index
          readonly property var entryMenu: EdgeMenuManager.localMenus[index] ?? ({})
          readonly property bool selected: EdgeMenuManager.selectedMenuIndex === index
          readonly property color contentColor: entry.selected ? Theme.background : Theme.foreground

          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height + Widget.padding
          backgroundColor: entry.selected ? Theme.accent : (entryArea.containsMouse ? Theme.backgroundHighlight : "transparent")
          borderWidth: 0

          MouseArea {
            id: entryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: EdgeMenuManager.selectMenu(entry.index)
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Widget.padding
            anchors.rightMargin: Widget.padding / 2
            spacing: Widget.spacing

            StyledIcon {
              text: root.edgeIcon(entry.entryMenu.edge)
              textColor: entry.selected ? Theme.background : Theme.accent
              Layout.preferredWidth: Appearance.fontSize * 1.5
            }

            StyledText {
              text: EdgeMenuManager.menuLabel(entry.entryMenu, entry.index)
              textColor: entry.contentColor
              font.bold: entry.selected
              opacity: entry.entryMenu.enabled === false ? 0.5 : 1
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            // Held open on screen by the editor
            StyledIcon {
              visible: EdgeMenuManager.previewing !== "" && EdgeMenuManager.previewing === entry.entryMenu.id
              text: "visibility"
              textColor: entry.contentColor
              textSize: Appearance.fontSize
            }

            // Unsaved edits to this menu
            Rectangle {
              visible: EdgeMenuManager.menuChanged(entry.index)
              implicitWidth: 8
              implicitHeight: 8
              radius: 4
              color: entry.selected ? Theme.background : Theme.accent
            }

            SquareIconButton {
              size: Widget.height - 6
              iconText: "content_copy"
              iconColor: entry.contentColor
              backgroundColor: "transparent"
              hoverColor: entry.selected ? Qt.darker(Theme.accent, 1.15) : Theme.backgroundAlt
              opacity: entry.selected || entryArea.containsMouse ? 1 : 0.35
              tooltipText: I18n.tr("Duplicate this menu")
              onClicked: EdgeMenuManager.duplicateMenu(entry.index)
            }

            SquareIconButton {
              size: Widget.height - 6
              iconText: "close"
              iconColor: entry.contentColor
              backgroundColor: "transparent"
              hoverColor: Theme.error
              tooltipText: I18n.tr("Remove this menu")
              onClicked: EdgeMenuManager.removeMenu(entry.index)
            }
          }
        }
      }

      StyledContainer {
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        Layout.topMargin: Widget.spacing
        Layout.bottomMargin: Widget.spacing
        backgroundColor: addArea.containsMouse ? Theme.backgroundHighlight : "transparent"
        borderColor: Theme.border
        borderWidth: 1

        StyledText {
          anchors.centerIn: parent
          text: "+  " + I18n.tr("New menu")
          opacity: addArea.containsMouse ? 1 : 0.7
        }

        MouseArea {
          id: addArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: EdgeMenuManager.addMenu()
        }
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

    Repeater {
      model: root.menu ? root.groups : []

      delegate: StyledContainer {
        id: group
        required property var modelData

        Layout.fillWidth: true
        implicitHeight: groupColumn.implicitHeight + Widget.padding * 2
        backgroundColor: Theme.backgroundAlt

        ColumnLayout {
          id: groupColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Widget.padding
          spacing: Widget.spacing * 1.5

          StyledText {
            text: I18n.tr(group.modelData.title)
            textColor: Theme.accent
            textSize: Appearance.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
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
    }

    FieldGroup {
      visible: EdgeMenuManager.problems.length > 0
      Layout.fillWidth: true
      title: I18n.tr("Can't save yet")

      Repeater {
        model: EdgeMenuManager.problems

        StyledText {
          required property string modelData
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "•  " + modelData
          textColor: Theme.error
        }
      }
    }
  }
}
