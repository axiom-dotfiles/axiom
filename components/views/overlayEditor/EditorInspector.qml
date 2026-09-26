pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions, module labels)
// Overlay / edge menu editor, below the canvas: what's selected there. A module's
// options, with its cell's layout beside them; an empty slot or a cell,
// the library beside its cell; nothing, the library of modules and
// cell layouts to drag onto the page.
Item {
  id: root

  required property var dragLayer
  readonly property ColumnsEditor editor: root.dragLayer.editor
  // Whether there are columns to add modules to
  property bool editable: true
  // The subtitle with nothing selected, when not editable
  property string notEditableHint: ""
  readonly property var sel: root.editor.selected
  readonly property var cell: root.editor.selectedCell()
  readonly property var module: root.editor.selectedModule()
  readonly property bool slotSelected: root.sel !== null && root.sel.slot !== "" && root.cell !== null
  readonly property bool cellSelected: root.sel !== null && root.cell !== null
  readonly property var rect: root.slotSelected ? root.editor.slotRect(root.sel.column, root.sel.cell, root.sel.slot) : null
  // Shapes and slot names are shown translated. Dynamic keys, declared for
  // scripts/check_i18n.py: I18n.tr("square") I18n.tr("horizontal") I18n.tr("vertical")
  // I18n.tr("main") I18n.tr("topLeft") I18n.tr("topRight") I18n.tr("bottomLeft")
  // I18n.tr("bottomRight") I18n.tr("top") I18n.tr("bottom") I18n.tr("left") I18n.tr("right")
  readonly property string shape: root.rect ? OverlayConfig.slotShape(root.rect) : ""
  readonly property string moduleType: root.module?.type ?? ""
  readonly property bool fits: !root.module || !root.rect || OverlayConfig.fits(root.moduleType, root.rect)
  // A new form per slot: SchemaField rows commit when their value
  // changes, so reusing one for another module would write the old values
  readonly property string selectionKey: root.module ? [root.editor.scopeKey, root.sel.column, root.sel.cell, root.sel.slot, root.moduleType].join(":") : ""

  readonly property string where: root.cellSelected ? I18n.tr("Column {0} · cell {1}", root.sel.column + 1, root.sel.cell + 1) + (root.slotSelected ? " · " + I18n.tr("{0} slot ({1})", I18n.tr(root.sel.slot), I18n.tr(root.shape)) : "") : ""

  Card {
    color: Theme.background
    border.color: Theme.border

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height + Widget.padding
        spacing: Widget.spacing

        Rectangle {
          Layout.preferredWidth: Widget.height + 4
          Layout.preferredHeight: Widget.height + 4
          radius: Appearance.borderRadius
          color: root.cellSelected ? Theme.accent : Theme.backgroundAlt

          StyledIcon {
            anchors.centerIn: parent
            text: root.module ? root.dragLayer.moduleIcon(root.moduleType) : root.slotSelected ? "add" : root.cellSelected ? "view_quilt" : "extension"
            textColor: root.cellSelected ? Theme.background : Theme.accent
            textSize: Appearance.fontSize + 4
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          StyledText {
            text: root.module ? root.dragLayer.moduleLabel(root.moduleType) : root.slotSelected ? I18n.tr("Empty slot") : root.cellSelected ? I18n.tr("{0} cell", root.dragLayer.layoutLabel(root.cell.layout)) : I18n.tr("Library")
            textSize: Appearance.fontSize + 4
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          StyledText {
            text: root.cellSelected ? root.where : root.editable ? I18n.tr("Click a slot, or a cell's grip, on the page to edit it") : root.notEditableHint
            opacity: 0.6
            textSize: Appearance.fontSize - 2
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        SquareIconButton {
          visible: root.module !== null
          iconText: "ink_eraser"
          hoverColor: Theme.error
          tooltipText: I18n.tr("Empty this slot")
          onClicked: root.editor.clearSlot(root.sel.column, root.sel.cell, root.sel.slot)
        }

        SquareIconButton {
          visible: root.cellSelected
          iconText: "close"
          tooltipText: I18n.tr("Close")
          onClicked: root.editor.clearSelection()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
        opacity: 0.3
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

          Repeater {
            model: root.selectionKey === "" ? [] : [root.selectionKey]
            delegate: options
          }

          ModuleLibrary {
            anchors.fill: parent
            visible: root.selectionKey === "" && root.editable
            dragLayer: root.dragLayer
            shape: root.slotSelected ? root.shape : ""
          }
        }

        // Right: the cell around the selection
        ScrollView {
          id: cellScroll
          visible: root.cellSelected
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 2
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

          FieldGroup {
            width: cellScroll.availableWidth
            title: I18n.tr("Cell")
            description: I18n.tr("Its layout splits it into slots. Switching keeps every module that fits the new one.")

            Flow {
              Layout.fillWidth: true
              spacing: Widget.spacing

              Repeater {
                model: root.cellSelected ? Object.keys(OverlayConfig.layouts) : []

                Rectangle {
                  id: choice
                  required property string modelData
                  readonly property bool current: root.cell?.layout === choice.modelData
                  width: choiceThumb.step * 4 + Widget.padding
                  height: choiceThumb.step * 4 + Widget.padding
                  radius: Appearance.borderRadius
                  color: choice.current ? Qt.alpha(Theme.accent, 0.15) : (choiceArea.containsMouse ? Theme.backgroundHighlight : Theme.background)
                  border.color: choice.current || choiceArea.containsMouse ? Theme.accent : Theme.border
                  border.width: choice.current ? 2 : 1

                  LayoutThumb {
                    id: choiceThumb
                    anchors.centerIn: parent
                    layout: choice.modelData
                    step: Appearance.fontSize * 0.7
                    selected: choice.current
                  }

                  MouseArea {
                    id: choiceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editor.setCellLayout(root.sel.column, root.sel.cell, choice.modelData)
                  }

                  LazyLoader {
                    active: choiceArea.containsMouse
                    StyledToolTip {
                      target: choice
                      text: root.dragLayer.layoutLabel(choice.modelData)
                    }
                  }
                }
              }
            }

            SchemaSwitch {
              label: "Fill space"
              description: "Grow into free room: the rest of its row and spare height in its column, shared evenly with other cells that fill. In an edge menu, the menu then takes its whole edge."
              checked: root.cell?.fill === true
              onToggled: newValue => root.editor.setCellFill(root.sel.column, root.sel.cell, newValue)
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Widget.spacing

              StyledTextButton {
                text: I18n.tr("Duplicate cell")
                textPadding: 6
                onClicked: root.editor.duplicateCell(root.sel.column, root.sel.cell)
              }

              StyledTextButton {
                text: I18n.tr("Remove cell")
                textPadding: 6
                hoverColor: Theme.error
                onClicked: root.editor.removeCell(root.sel.column, root.sel.cell)
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

      readonly property var sel: root.sel
      readonly property var propertiesSchema: OverlayConfig.moduleInfo(root.moduleType)?.propertiesSchema ?? ({})

      FieldGroup {
        width: optionsScroll.availableWidth
        title: I18n.tr("Options")

        StyledText {
          visible: !root.fits
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: I18n.tr("{0} doesn't fit a {1} slot: move it, or change the cell's layout.", root.dragLayer.moduleLabel(root.moduleType), I18n.tr(root.shape))
          textColor: Theme.error
        }

        SchemaPropertiesForm {
          id: optionsForm
          Layout.fillWidth: true
          propertiesSchema: optionsScroll.propertiesSchema
          values: root.module?.properties ?? ({})
          onEdited: (path, value) => root.editor.updateModuleProperty(optionsScroll.sel.column, optionsScroll.sel.cell, optionsScroll.sel.slot, path[0], value)
        }

        StyledText {
          visible: optionsForm.rows.length === 0
          text: I18n.tr("This module has no options")
          opacity: 0.6
          Layout.fillWidth: true
        }
      }
    }
  }
}
