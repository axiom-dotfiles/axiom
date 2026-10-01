pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.base
import qs.components.views.keybinds

// The keybinds page: Hyprland's binds by section, as cards in columns,
// with a search over labels, sections and keys and toggle chips by section,
// modifier and source (KeybindFilter); or the editor for axiom's own binds
// (BindEditor)
BaseView {
  id: root

  readonly property bool editing: KeybindManager.editing

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
  readonly property var columns: {
    const result = [];
    const heights = [];
    for (let i = 0; i < root.columnCount; i++) {
      result.push([]);
      heights.push(0);
    }
    for (const section of root.sections) {
      const target = heights.indexOf(Math.min(...heights));
      result[target].push(section);
      heights[target] += 1.5 + section.binds.length + (section.undescribed ? 2 : 0);
    }
    return result;
  }

  Item {
    implicitWidth: root.cardPageWidth
    implicitHeight: root.pageHeight

    TitledCard {
      title: I18n.tr("Keybinds")
      showActions: root.editing
      dirty: KeybindManager.isDirty
      onSave: KeybindManager.save()
      onReset: KeybindManager.reset()

      headerExtras: [
        RowLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing * 2

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

          StyledTextEntry {
            visible: !root.editing
            Layout.fillWidth: true
            Layout.preferredHeight: Widget.height
            placeholderText: I18n.tr("Search keybinds")
            Component.onCompleted: input.text = KeybindManager.query
            onTextChanged: KeybindManager.query = text
          }

          Item {
            visible: root.editing
            Layout.fillWidth: true
          }

          StyledText {
            visible: !root.editing
            text: root.query !== "" || KeybindManager.filtering ? I18n.tr("{0} of {1} binds", root.shownCount, root.totalCount) : I18n.tr("{0} binds", root.totalCount)
            opacity: 0.6
          }
        },

        // Toggle chips: sections, then modifiers, then sources, each group
        // set apart by a divider
        Flow {
          visible: !root.editing
          Layout.fillWidth: true
          spacing: Widget.spacing

          Repeater {
            model: KeybindManager.sectionOptions

            delegate: SegmentButton {
              required property var modelData
              implicitHeight: Widget.height
              text: (modelData.undescribed ? I18n.tr("Undescribed") : (modelData.title || I18n.tr("Other"))) + "  " + modelData.count
              active: KeybindManager.sectionFilter.includes(modelData.key)
              onClicked: KeybindManager.toggleFilter("section", modelData.key)
            }
          }

          ChipDivider {}

          Repeater {
            model: KeybindManager.modOptions

            delegate: SegmentButton {
              required property string modelData
              implicitHeight: Widget.height
              text: KeyNames.modifierLabel(modelData)
              active: KeybindManager.modFilter.includes(modelData)
              onClicked: KeybindManager.toggleFilter("mod", modelData)
            }
          }

          ChipDivider {}

          Repeater {
            // I18n.tr("Axiom binds") I18n.tr("Your binds")
            model: [
              {
                "key": "axiom",
                "label": "Axiom binds"
              },
              {
                "key": "user",
                "label": "Your binds"
              }
            ]

            delegate: SegmentButton {
              required property var modelData
              implicitHeight: Widget.height
              text: I18n.tr(modelData.label)
              active: KeybindManager.sourceFilter.includes(modelData.key)
              onClicked: KeybindManager.toggleFilter("source", modelData.key)
            }
          }

          SegmentButton {
            visible: KeybindManager.filtering
            implicitHeight: Widget.height
            text: I18n.tr("Clear")
            onClicked: KeybindManager.clearFilters()
          }
        }
      ]

      Loader {
        active: root.editing
        visible: active
        Layout.fillWidth: true
        sourceComponent: BindEditor {}
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
  }

  // A short upright line between chip groups
  component ChipDivider: Item {
    implicitWidth: Widget.spacing
    implicitHeight: Widget.height

    StyledSeparator {
      anchors.centerIn: parent
      width: 1
      separatorHeight: parent.height * 0.6
      opacity: 0.6
    }
  }
}
