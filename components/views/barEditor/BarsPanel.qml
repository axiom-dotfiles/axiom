pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions)
// Bar editor, left: the bars, then the selected bar's own settings in
// groups, generated from the schema's Bar definition
Item {
  id: root

  readonly property bool hasBar: root.bar !== null
  readonly property var bar: BarManager.selectedBar()
  // A style is copied (BarManager.copyStyle), from the selected bar
  readonly property bool copied: BarManager.copiedStyle !== null
  readonly property bool copiedHere: BarManager.copiedStyle?.index === BarManager.selectedBarIndex

  // Group titles: I18n.tr("General") I18n.tr("Size") I18n.tr("Style")
  // I18n.tr("Behaviour") I18n.tr("Other")
  TitledCard {
    title: I18n.tr("Bar Editor")
    showActions: false

    headerExtras: ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      Repeater {
        model: BarManager.localConfig?.length ?? 0

        delegate: ListEntryRow {
          id: entry
          required property int index
          readonly property var entryBar: BarManager.localConfig[index] ?? ({})

          icon: Utils.edgeArrow(entry.entryBar.location)
          label: BarManager.barLabel(entry.index)
          selected: BarManager.selectedBarIndex === entry.index
          dimmed: entry.entryBar.enabled === false
          changed: BarManager.barChanged(entry.index)
          onClicked: BarManager.selectBar(entry.index)

          // One copy per monitor
          badges: StyledIcon {
            id: everyMonitor
            visible: entry.entryBar.monitor === "*"
            text: "desktop_windows"
            textColor: entry.ink
            opacity: 0.7

            HoverHandler {
              id: everyMonitorHover
            }
            LazyLoader {
              active: everyMonitorHover.hovered
              StyledToolTip {
                target: everyMonitor
                text: I18n.tr("On every monitor")
              }
            }
          }

          RowAction {
            row: entry
            iconText: "content_copy"
            tooltipText: I18n.tr("Copy this bar")
            onClicked: BarManager.duplicateBar(entry.index)
          }

          RowAction {
            row: entry
            visible: (BarManager.localConfig?.length ?? 0) > 1
            danger: true
            iconText: "close"
            tooltipText: I18n.tr("Remove this bar")
            onClicked: BarManager.removeBar(entry.index)
          }
        }
      }

      AddEntryButton {
        Layout.topMargin: Widget.spacing
        Layout.bottomMargin: Widget.spacing
        text: I18n.tr("New bar")
        onClicked: BarManager.addBar()
      }
    }

    // A ColumnLayout's Repeater re-runs its model on every draft edit:
    // `hasEntry` keeps the model the same while one is selected
    Repeater {
      model: root.hasBar ? Bar.fieldGroups : []

      delegate: FieldGroup {
        id: group
        required property var modelData
        title: I18n.tr(group.modelData.title)

        // The Style group carries the bar's look (BarManager.styleKeys:
        // its Size, Style, Widgets, Accents and Shadow settings) to other bars
        headerExtras: [
          SquareIconButton {
            visible: group.modelData.title === "Style"
            iconText: "format_paint"
            iconColor: root.copiedHere ? Theme.background : Theme.foreground
            backgroundColor: root.copiedHere ? Theme.accent : Theme.backgroundAlt
            tooltipText: I18n.tr("Copy this bar's size and style")
            onClicked: BarManager.copyStyle(BarManager.selectedBarIndex)
          },
          SquareIconButton {
            visible: group.modelData.title === "Style" && root.copied && !root.copiedHere
            iconText: "content_paste"
            tooltipText: I18n.tr("Paste the size and style of {0}", BarManager.barLabel(BarManager.copiedStyle?.index ?? 0))
            onClicked: BarManager.pasteStyle(BarManager.selectedBarIndex)
          },
          SquareIconButton {
            visible: group.modelData.title === "Style" && root.copied
            iconText: "done_all"
            tooltipText: I18n.tr("Paste the size and style of {0} onto every bar", BarManager.barLabel(BarManager.copiedStyle?.index ?? 0))
            onClicked: BarManager.pasteStyleToAll()
          }
        ]

        SchemaPropertiesForm {
          Layout.fillWidth: true
          propertiesSchema: group.modelData.schema
          order: group.modelData.keys
          numberMode: "stepper"
          // The whole bar, so x-showIf sees keys from other groups
          values: root.bar ?? ({})
          onEdited: (path, value) => BarManager.updateBarField(path[0], value)
        }

        // The thickness the size settings add up to
        StyledText {
          visible: "widgetSize" in group.modelData.schema
          text: I18n.tr("Bar thickness: {0} px", Math.round(Bar.enrichBarConfig(root.bar ?? ({}), HyprlandManager.gapsOut).extent))
          textColor: Theme.foreground
          opacity: 0.7
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }
  }
}
