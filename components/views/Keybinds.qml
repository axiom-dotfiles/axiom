pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts
import qs.components.views.keybinds

// The keybinds page: the compositor's binds by section, as cards in
// columns, with a search over labels, sections and keys and toggle chips
// by section, modifier and source (KeybindFilter); or the editor for
// axiom's own binds: their list by section (BindEditor) beside an
// inspector for the selected one (BindInspector), or with none selected,
// the key map (KeyMapPanel)
BaseView {
  id: root

  readonly property bool editing: KeybindManager.editing
  readonly property real inspectorWidth: root.sideWidth * 1.45
  // The list beside it: rows need little room, so three quarters of an
  // editor's width (narrower still where the screen has no room for both)
  readonly property real listWidth: root.grid ? Math.max(root.grid.unit * 1.2, Math.min(root.editorWidth * 0.75, root.grid.availableWidth - root.inspectorWidth - OverlayConfig.cardSpacing * 3)) : 0

  Component.onCompleted: KeybindManager.ensureLoaded()

  readonly property int columnCount: Math.max(1, Math.floor(root.cardPageWidth / (root.grid.unit * 0.8)))

  readonly property string query: KeybindManager.query.trim()

  // From the binds, the search and the chips only, so nothing rebuilds
  // while it's shown
  readonly property var sections: KeybindFilter.filter(KeybindManager.keybindings, root.query, {
    "sections": KeybindManager.sectionFilter,
    "mods": KeybindManager.modFilter,
    "sources": KeybindManager.sourceFilter
  })

  readonly property int shownCount: root.sections.reduce((sum, section) => sum + section.binds.length, 0)
  readonly property int totalCount: KeybindManager.sectionOptions.reduce((sum, option) => sum + option.count, 0)

  // Masonry: each section goes to the shortest column, by row count
  readonly property var columns: KeybindFilter.columns(root.sections, root.columnCount)

  Item {
    id: listSide
    implicitWidth: root.editing ? root.listWidth : root.cardPageWidth
    implicitHeight: root.pageHeight

    TitledCard {
      id: listCard
      title: I18n.tr("Keybinds")
      showActions: false

      headerExtras: [
        RowLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing * 2

          SegmentRow {
            Repeater {
              // I18n.tr("All binds") I18n.tr("Edit axiom binds")
              model: ["All binds", "Edit axiom binds"]

              delegate: SegmentButton {
                required property string modelData
                required property int index
                readonly property bool selected: root.editing === (index === 1)
                implicitHeight: Widget.height
                text: I18n.tr(modelData) + (index === 1 && KeybindManager.isDirty ? "  •" : "")
                active: selected
                Layout.fillWidth: false
                onClicked: {
                  if (index === 0)
                    KeybindManager.stopRecording();
                  KeybindManager.editing = index === 1;
                }
              }
            }
          }

          StyledTextEntry {
            visible: !root.editing
            Layout.fillWidth: true
            Layout.preferredHeight: Widget.height
            placeholderText: I18n.tr("Search keybinds")
            Component.onCompleted: input.text = KeybindManager.query
            onTextChanged: KeybindManager.query = text
          }

          StyledTextEntry {
            id: editSearch
            visible: root.editing
            Layout.fillWidth: true
            Layout.preferredHeight: Widget.height
            placeholderText: I18n.tr("Search binds by key, action or label")
            Component.onCompleted: input.text = KeybindManager.editQuery
            onTextChanged: KeybindManager.editQuery = text
            // Add bind clears the search
            Connections {
              target: KeybindManager
              function onEditQueryChanged() {
                if (editSearch.input.text !== KeybindManager.editQuery)
                  editSearch.input.text = KeybindManager.editQuery;
              }
            }
          }

          StyledTextButton {
            visible: root.editing
            implicitHeight: Widget.height
            iconText: "playlist_add"
            text: I18n.tr("Presets")
            onClicked: presetSheet.open()
          }

          StyledTextButton {
            visible: root.editing
            implicitHeight: Widget.height
            iconText: "add"
            text: I18n.tr("Add bind")
            onClicked: KeybindManager.addAndStartRecording({})
          }

          StyledText {
            visible: !root.editing
            text: root.query !== "" || KeybindManager.filtering ? I18n.tr("{0} of {1} binds", root.shownCount, root.totalCount) : I18n.tr("{0} binds", root.totalCount)
            opacity: 0.6
          }
        },
        FilterChips {
          visible: !root.editing
          Layout.fillWidth: true
          groups: [
            {
              "id": "section",
              "options": KeybindManager.sectionOptions.map(option => ({
                    "value": option.key,
                    "label": (option.undescribed ? I18n.tr("Undescribed") : (option.title || I18n.tr("Other"))) + "  " + option.count
                  }))
            },
            {
              "id": "mod",
              "options": KeybindManager.modOptions.map(mod => ({
                    "value": mod,
                    "label": KeyNames.modifierLabel(mod)
                  }))
            },
            {
              "id": "source",
              "options": [
                {
                  "value": "axiom",
                  "label": I18n.tr("Axiom binds")
                },
                {
                  "value": "user",
                  "label": I18n.tr("Your binds")
                }
              ]
            }
          ]
          selection: ({
              "section": KeybindManager.sectionFilter,
              "mod": KeybindManager.modFilter,
              "source": KeybindManager.sourceFilter
            })
          filtering: KeybindManager.filtering
          onToggled: (group, value) => KeybindManager.toggleFilter(group, value)
          onCleared: KeybindManager.clearFilters()
        },
        FilterChips {
          visible: root.editing && KeybindManager.binds.length > 0
          Layout.fillWidth: true
          groups: [
            {
              "id": "editSection",
              "options": KeybindManager.editSectionOptions.map(option => ({
                    "value": option.key,
                    "label": I18n.tr(option.title) + "  " + option.count
                  }))
            },
            {
              "id": "editMod",
              "options": KeybindManager.editModOptions.map(mod => ({
                    "value": mod,
                    "label": KeyNames.modifierLabel(mod)
                  }))
            },
            {
              "id": "editIssues",
              "options": KeybindManager.issueCount > 0 || KeybindManager.editIssuesOnly ? [
                {
                  "value": "issues",
                  "label": I18n.tr("With issues") + "  " + KeybindManager.issueCount
                }
              ] : []
            }
          ]
          selection: ({
              "editSection": KeybindManager.editSectionFilter,
              "editMod": KeybindManager.editModFilter,
              "editIssues": KeybindManager.editIssuesOnly ? ["issues"] : []
            })
          filtering: KeybindManager.editFiltering
          onToggled: (group, value) => {
            if (group === "editIssues")
              KeybindManager.editIssuesOnly = !KeybindManager.editIssuesOnly;
            else
              KeybindManager.toggleFilter(group, value);
          }
          onCleared: KeybindManager.clearEditFilters()
        }
      ]

      Loader {
        active: root.editing
        visible: active
        Layout.fillWidth: true
        sourceComponent: BindEditor {
          scrollTo: item => listCard.scrollTo(item)
        }
      }

      StyledText {
        visible: !root.editing && (root.query !== "" || KeybindManager.filtering) && root.sections.length === 0
        text: root.query !== "" ? I18n.tr("No keybinds match \"{0}\"", root.query) : I18n.tr("No keybinds match the filters")
        opacity: 0.6
        Layout.fillWidth: true
        Layout.topMargin: Widget.padding
      }

      RowLayout {
        visible: !root.editing
        Layout.fillWidth: true
        spacing: Widget.spacing * 2

        Repeater {
          model: root.columnCount

          delegate: ColumnLayout {
            id: column
            required property int index
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Widget.spacing * 2

            Repeater {
              model: root.columns[column.index]

              delegate: KeybindSection {
                required property var modelData
                section: modelData
              }
            }
          }
        }
      }
    }

    PresetSheet {
      id: presetSheet
      width: listSide.width - Widget.padding * 4
      height: listSide.height * 0.8
      x: (listSide.width - width) / 2
      y: (listSide.height - height) / 2
    }
  }

  // The selected bind, or the key map; Save and Discard for the page
  Item {
    visible: root.editing
    implicitWidth: root.inspectorWidth
    implicitHeight: root.pageHeight

    TitledCard {
      title: KeybindManager.selectedIndex >= 0 ? I18n.tr("Bind") : I18n.tr("Key map")
      showActions: true
      dirty: KeybindManager.isDirty
      onSave: KeybindManager.save()
      onReset: KeybindManager.reset()

      Repeater {
        model: root.editing && KeybindManager.selectedIndex >= 0 ? [KeybindManager.selectedIndex] : []

        delegate: BindInspector {
          required property int modelData
          bindIndex: modelData
          Layout.fillWidth: true
        }
      }

      KeyMapPanel {
        visible: root.editing && KeybindManager.selectedIndex < 0
        Layout.fillWidth: true
      }
    }
  }
}
