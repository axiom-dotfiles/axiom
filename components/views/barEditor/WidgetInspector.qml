pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions, type labels)
// Bar editor: the selected widget's options and sizing, or with nothing
// selected, the library of widget types to drag onto the bar
Item {
  id: root

  required property var dragLayer

  readonly property var selection: BarManager.selectedWidget
  readonly property var widget: BarManager.selectedWidgetConfig()
  // A new form per widget (KeyedLoader)
  readonly property string selectionKey: root.widget ? [BarManager.selectedBarIndex, root.selection.zone, root.selection.index, root.widget.type].join(":") : ""

  Card {
    color: Theme.background
    border.color: Theme.border

    Item {
      anchors.fill: parent
      anchors.margins: Widget.padding

      KeyedLoader {
        anchors.fill: parent
        key: root.selectionKey
        sourceComponent: editor
      }

      Loader {
        anchors.fill: parent
        active: root.selectionKey === ""
        sourceComponent: library
      }
    }
  }

  Component {
    id: editor

    ColumnLayout {
      id: editorRoot

      readonly property string zone: root.selection.zone
      readonly property int index: root.selection.index
      readonly property var widget: root.widget ?? ({})
      readonly property bool hidden: editorRoot.widget.visible === false
      readonly property var propertiesSchema: root.dragLayer.typeInfo(editorRoot.widget.type)?.propertiesSchema ?? ({})

      anchors.fill: parent
      spacing: Widget.spacing

      InspectorHeader {
        icon: root.dragLayer.icon(editorRoot.widget.type)
        title: root.dragLayer.label(editorRoot.widget.type)
        subtitle: editorRoot.hidden ? I18n.tr("{0} section, position {1} · hidden on the bar", root.dragLayer.zoneLabel(editorRoot.zone), editorRoot.index + 1) : I18n.tr("{0} section, position {1}", root.dragLayer.zoneLabel(editorRoot.zone), editorRoot.index + 1)

        SquareIconButton {
          iconText: editorRoot.hidden ? "visibility_off" : "visibility"
          iconColor: editorRoot.hidden ? Theme.background : Theme.foreground
          backgroundColor: editorRoot.hidden ? Theme.accent : Theme.backgroundAlt
          tooltipText: I18n.tr(editorRoot.hidden ? "Hidden on the bar: click to show it" : "Hide it on the bar, keeping its settings")
          onClicked: BarManager.setWidgetVisible(editorRoot.zone, editorRoot.index, editorRoot.hidden)
        }

        SquareIconButton {
          iconText: "content_copy"
          tooltipText: I18n.tr("Duplicate")
          onClicked: BarManager.duplicateWidget(editorRoot.zone, editorRoot.index)
        }

        SquareIconButton {
          iconText: "delete"
          hoverColor: Theme.error
          tooltipText: I18n.tr("Remove")
          onClicked: BarManager.removeWidget(editorRoot.zone, editorRoot.index)
        }

        SquareIconButton {
          iconText: "close"
          tooltipText: I18n.tr("Close")
          onClicked: BarManager.clearSelection()
        }
      }

      ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        RowLayout {
          width: scroll.availableWidth
          spacing: Widget.spacing * 2

          OptionsGroup {
            Layout.preferredWidth: 3
            propertiesSchema: editorRoot.propertiesSchema
            numberMode: "stepper"
            values: editorRoot.widget.properties ?? ({})
            emptyText: I18n.tr("This widget has no options")
            onEdited: (path, value) => BarManager.updateWidgetProperty(editorRoot.zone, editorRoot.index, path[0], value)
          }

          FieldGroup {
            Layout.preferredWidth: 2
            title: I18n.tr(Bar.widgetLayoutSchema.title ?? "Layout")
            description: Bar.widgetLayoutSchema.description ? I18n.tr(Bar.widgetLayoutSchema.description) : ""

            Repeater {
              model: [
                {
                  "key": "size",
                  "initial": 100
                },
                {
                  "key": "minSize",
                  "initial": 0
                },
                {
                  "key": "priority",
                  "initial": 0
                }
              ]

              delegate: LayoutOverrideField {
                required property var modelData
                key: modelData.key
                initial: modelData.initial
                fieldSchema: Bar.widgetLayoutSchema.properties?.[modelData.key] ?? ({})
                value: editorRoot.widget.layout?.[modelData.key]
                onEdited: value => BarManager.updateWidgetLayout(editorRoot.zone, editorRoot.index, modelData.key, value)
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: library

    ColumnLayout {
      spacing: Widget.spacing

      CardHeader {
        title: I18n.tr("Widget library")
        showActions: false
      }

      StyledText {
        Layout.fillWidth: true
        text: I18n.tr("Drag a widget onto a section, or click one to add it to the center. Click a widget in a section to edit it.")
        opacity: 0.6
        textSize: Appearance.fontSize - 2
        wrapMode: Text.WordWrap
      }

      ScrollView {
        id: libraryScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Widget.spacing / 2
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        TileFlow {
          id: flow
          minColumns: 2
          width: libraryScroll.availableWidth

          Repeater {
            model: Bar.availableWidgetTypes

            delegate: WidgetChip {
              id: tile
              required property var modelData
              dragLayer: root.dragLayer
              width: flow.tileWidth
              type: tile.modelData.type
              payload: ({
                  "kind": "add",
                  "type": tile.modelData.type
                })
              onClicked: BarManager.addWidget("center", tile.modelData.type)
            }
          }
        }
      }
    }
  }
}
