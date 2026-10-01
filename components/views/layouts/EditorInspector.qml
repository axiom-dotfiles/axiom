pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.methods
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions, module labels)
// Layouts editor, below the canvas: the selected module's options, with
// its size beside them; with nothing selected, the library of modules to
// add.
Item {
  id: root

  required property var dragLayer
  readonly property GridEditor editor: root.dragLayer.editor
  // Whether there are modules to edit (a Custom page or a menu)
  property bool editable: true
  // The subtitle with nothing selected, when not editable
  property string notEditableHint: ""
  readonly property int index: root.editor.selected
  readonly property var module: root.editor.selectedModule()
  readonly property string moduleType: root.module?.type ?? ""
  // A required module (x-required) stays: no Duplicate or Remove
  readonly property bool removable: root.module !== null && !OverlayConfig.isRequired(root.moduleType)
  readonly property var place: root.module?.place ?? null
  // A new form per module (KeyedLoader)
  readonly property string selectionKey: root.module ? [root.editor.scopeKey, root.index, root.moduleType].join(":") : ""

  // A size in grid units as cards: 4 → "1", 2 → "½", 5 → "1¼"
  function cards(units) {
    const whole = Math.floor(units / 4);
    const part = ["", "¼", "½", "¾"][units % 4];
    return part === "" ? String(whole) : (whole > 0 ? whole : "") + part;
  }

  Card {
    color: Theme.background
    border.color: Theme.border

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      InspectorHeader {
        icon: root.module ? root.dragLayer.moduleIcon(root.moduleType) : "extension"
        filled: root.module !== null
        title: root.module ? root.dragLayer.moduleLabel(root.moduleType) : I18n.tr("Library")
        subtitle: root.place ? I18n.tr("{0} × {1} cards", root.cards(root.place.w), root.cards(root.place.h)) : root.editable ? I18n.tr("Click a module on the canvas to edit it") : root.notEditableHint

        SquareIconButton {
          visible: root.removable
          iconText: "content_copy"
          tooltipText: I18n.tr("Duplicate")
          onClicked: root.editor.duplicateModule(root.index)
        }

        SquareIconButton {
          visible: root.removable
          iconText: "delete"
          hoverColor: Theme.error
          tooltipText: I18n.tr("Remove")
          onClicked: root.editor.removeModule(root.index)
        }

        SquareIconButton {
          visible: root.module !== null
          iconText: "close"
          tooltipText: I18n.tr("Close")
          onClicked: root.editor.clearSelection()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Widget.spacing * 2

        // Left: the module's options, or the library
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 3

          KeyedLoader {
            anchors.fill: parent
            key: root.selectionKey
            sourceComponent: options
          }

          ModuleLibrary {
            anchors.fill: parent
            visible: root.selectionKey === "" && root.editable
            dragLayer: root.dragLayer
          }
        }

        // Right: its size
        ScrollView {
          id: sizeScroll
          visible: root.module !== null
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 2
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

          FieldGroup {
            width: sizeScroll.availableWidth
            title: I18n.tr("Size")
            description: I18n.tr("In quarter cards. Drag its corner on the canvas, or step it here.")

            Repeater {
              // I18n.tr("Width") I18n.tr("Height")
              model: [
                {
                  "label": "Width",
                  "axis": 0
                },
                {
                  "label": "Height",
                  "axis": 1
                }
              ]

              SchemaNumberField {
                id: sizeField
                required property var modelData
                readonly property bool across: sizeField.modelData.axis === 0
                // The size it can grow to before it would overlap a module
                // (or reach the grid's limit), keeping the other side
                readonly property int grows: {
                  if (!root.place)
                    return 1;
                  let n = sizeField.currentConfigValue;
                  while (n < GridPlacement.maxSpan && root.editor.canResize(root.index, sizeField.across ? n + 1 : root.place.w, sizeField.across ? root.place.h : n + 1))
                    n++;
                  return n;
                }
                label: sizeField.modelData.label
                currentConfigValue: root.place ? (sizeField.across ? root.place.w : root.place.h) : 1
                minimum: 1
                maximum: sizeField.grows
                mode: "stepper"
                showCoarse: false
                // The field stays as the selection changes
                debounced: false
                onCommitted: value => root.editor.resizeModule(root.index, sizeField.across ? value : root.place.w, sizeField.across ? root.place.h : value)
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: options

    ScrollView {
      id: optionsScroll
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

      OptionsGroup {
        width: optionsScroll.availableWidth
        propertiesSchema: OverlayConfig.moduleInfo(root.moduleType)?.propertiesSchema ?? ({})
        values: root.module?.properties ?? ({})
        emptyText: I18n.tr("This module has no options")
        onEdited: (path, value) => root.editor.updateModuleProperty(root.index, path[0], value)
      }
    }
  }
}
