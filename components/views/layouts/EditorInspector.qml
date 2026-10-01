pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
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
  readonly property var place: root.module?.place ?? null
  readonly property var rect: root.place ? GridPlacement.rectOf(root.place) : null
  readonly property bool fits: !root.module || OverlayConfig.fits(root.moduleType, root.rect)
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
          visible: root.module !== null
          iconText: "content_copy"
          tooltipText: I18n.tr("Duplicate")
          onClicked: root.editor.duplicateModule(root.index)
        }

        SquareIconButton {
          visible: root.module !== null
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

              RowLayout {
                id: sizeRow
                required property var modelData
                readonly property int value: root.place ? (sizeRow.modelData.axis === 0 ? root.place.w : root.place.h) : 0
                function sized(by) {
                  if (!root.place)
                    return [0, 0];
                  const w = root.place.w + (sizeRow.modelData.axis === 0 ? by : 0);
                  const h = root.place.h + (sizeRow.modelData.axis === 1 ? by : 0);
                  return [w, h];
                }
                function canStep(by) {
                  if (!root.place)
                    return false;
                  const size = sizeRow.sized(by);
                  return root.module !== null && size[0] >= 1 && size[1] >= 1 && root.editor.canResize(root.index, size[0], size[1]);
                }
                Layout.fillWidth: true
                spacing: Widget.spacing

                StyledText {
                  Layout.fillWidth: true
                  text: I18n.tr(sizeRow.modelData.label)
                }
                SquareIconButton {
                  size: Widget.height - 4
                  iconText: "remove"
                  enabled: sizeRow.canStep(-1)
                  opacity: enabled ? 1 : 0.35
                  onClicked: {
                    const size = sizeRow.sized(-1);
                    root.editor.resizeModule(root.index, size[0], size[1]);
                  }
                }
                StyledText {
                  Layout.preferredWidth: Appearance.fontSize * 3
                  horizontalAlignment: Text.AlignHCenter
                  text: String(sizeRow.value)
                  font.bold: true
                }
                SquareIconButton {
                  size: Widget.height - 4
                  iconText: "add"
                  enabled: sizeRow.canStep(1)
                  opacity: enabled ? 1 : 0.35
                  onClicked: {
                    const size = sizeRow.sized(1);
                    root.editor.resizeModule(root.index, size[0], size[1]);
                  }
                }
              }
            }

            StyledText {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              readonly property var info: OverlayConfig.moduleInfo(root.moduleType)
              // Shapes are shown translated: I18n.tr("square") I18n.tr("horizontal") I18n.tr("vertical")
              text: info ? I18n.tr("Fits: {0}", info.shapes.map(shape => I18n.tr(shape)).join(", ")) + (info.minSize ? " · " + I18n.tr("at least {0} × {1}", info.minSize[0], info.minSize[1]) : "") : ""
              opacity: 0.6
              textSize: Appearance.fontSize - 2
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
        problem: root.fits ? "" : I18n.tr("{0} doesn't fit a {1} × {2} place: resize it.", root.dragLayer.moduleLabel(root.moduleType), root.place?.w ?? 0, root.place?.h ?? 0)
        emptyText: I18n.tr("This module has no options")
        onEdited: (path, value) => root.editor.updateModuleProperty(root.index, path[0], value)
      }
    }
  }
}
