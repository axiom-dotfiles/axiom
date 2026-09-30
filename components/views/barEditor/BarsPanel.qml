pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.base

// i18n: keys from the schema (titles, descriptions)
// Bar editor, left: the bars, then the selected bar's own settings in
// groups, generated from the schema's Bar definition
Item {
  id: root

  readonly property var bar: BarManager.selectedBar()
  readonly property var barSchema: ConfigManager.configSchema.definitions?.Bar?.properties ?? ({})

  // The Bar keys by group; any the schema adds later land in "Other".
  // Titles: I18n.tr("General") I18n.tr("Size") I18n.tr("Style")
  // I18n.tr("Behaviour") I18n.tr("Other")
  readonly property var groups: {
    const named = [
      {
        "title": "General",
        "keys": ["id", "enabled", "monitor", "location"]
      },
      {
        "title": "Size",
        "keys": BarManager.sizeKeys
      },
      {
        "title": "Style",
        "keys": BarManager.styleOnlyKeys
      },
      {
        "title": "Behaviour",
        "keys": ["lockCenter", "reserveSpace"]
      }
    ];
    const grouped = [].concat(...named.map(g => g.keys)).concat(["widgets"]);
    const other = Object.keys(root.barSchema).filter(key => !grouped.includes(key));
    return named.concat(other.length > 0 ? [
      {
        "title": "Other",
        "keys": other
      }
    ] : []).map(g => ({
          "title": g.title,
          "keys": g.keys,
          "schema": g.keys.filter(key => key in root.barSchema).reduce((out, key) => {
            out[key] = root.barSchema[key];
            return out;
          }, {})
        }));
  }

  // Material Symbols arrow for the edge a bar sits on
  function locationIcon(location) {
    switch (location) {
    case "Bottom":
      return "arrow_downward";
    case "Left":
      return "arrow_back";
    case "Right":
      return "arrow_forward";
    }
    return "arrow_upward";
  }

  TitledCard {
    color: Theme.background
    title: I18n.tr("Bar Editor")
    dirty: BarManager.isDirty
    onSave: BarManager.saveChanges()
    onReset: BarManager.resetChanges()

    headerExtras: ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      Repeater {
        model: BarManager.localConfig?.length ?? 0

        delegate: StyledContainer {
          id: entry
          required property int index
          readonly property var entryBar: BarManager.localConfig[index] ?? ({})
          readonly property bool selected: BarManager.selectedBarIndex === index
          readonly property bool primary: index === 0

          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height + Widget.padding
          backgroundColor: entry.selected ? Theme.accent : (entryArea.containsMouse ? Theme.backgroundHighlight : "transparent")
          borderWidth: 0

          MouseArea {
            id: entryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: BarManager.selectedBarIndex = entry.index
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Widget.padding
            anchors.rightMargin: Widget.padding / 2
            spacing: Widget.spacing

            StyledIcon {
              text: root.locationIcon(entry.entryBar.location)
              textColor: entry.selected ? Theme.background : Theme.accent
              Layout.preferredWidth: Appearance.fontSize * 1.5
            }

            StyledText {
              text: BarManager.barLabel(entry.index)
              textColor: entry.selected ? Theme.background : Theme.foreground
              font.bold: entry.selected
              opacity: entry.entryBar.enabled === false ? 0.5 : 1
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            // One copy per monitor
            StyledIcon {
              id: everyMonitor
              visible: entry.entryBar.monitor === "*"
              text: "desktop_windows"
              textColor: entry.selected ? Theme.background : Theme.foreground
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

            // Unsaved edits to this bar
            Rectangle {
              visible: BarManager.barChanged(entry.index)
              implicitWidth: 8
              implicitHeight: 8
              radius: 4
              color: entry.selected ? Theme.background : Theme.accent
            }

            // Copy this bar's look, then paste it onto others
            SquareIconButton {
              readonly property bool source: BarManager.copiedStyle?.index === entry.index
              size: Widget.height - 6
              iconText: "format_paint"
              iconColor: entry.selected ? Theme.background : (source ? Theme.accent : Theme.foreground)
              backgroundColor: "transparent"
              hoverColor: entry.selected ? Qt.darker(Theme.accent, 1.15) : Theme.backgroundAlt
              opacity: source || entry.selected || entryArea.containsMouse ? 1 : 0.35
              tooltipText: I18n.tr("Copy style")
              onClicked: BarManager.copyStyle(entry.index)
            }

            SquareIconButton {
              visible: !!BarManager.copiedStyle && BarManager.copiedStyle.index !== entry.index
              size: Widget.height - 6
              iconText: "content_paste"
              iconColor: entry.selected ? Theme.background : Theme.foreground
              backgroundColor: "transparent"
              hoverColor: entry.selected ? Qt.darker(Theme.accent, 1.15) : Theme.backgroundAlt
              opacity: entry.selected || entryArea.containsMouse ? 1 : 0.6
              tooltipText: I18n.tr("Paste style from {0}", BarManager.barLabel(BarManager.copiedStyle?.index ?? 0))
              onClicked: BarManager.pasteStyle(entry.index)
            }

            SquareIconButton {
              size: Widget.height - 6
              iconText: "content_copy"
              iconColor: entry.selected ? Theme.background : Theme.foreground
              backgroundColor: "transparent"
              hoverColor: entry.selected ? Qt.darker(Theme.accent, 1.15) : Theme.backgroundAlt
              opacity: entry.selected || entryArea.containsMouse ? 1 : 0.35
              tooltipText: I18n.tr("Copy this bar")
              onClicked: BarManager.duplicateBar(entry.index)
            }

            // The primary bar is the first; the star makes another one it
            SquareIconButton {
              size: Widget.height - 6
              iconText: entry.primary ? "star" : "star_border"
              iconColor: entry.selected ? Theme.background : (entry.primary ? Theme.accent : Theme.foreground)
              backgroundColor: "transparent"
              hoverColor: entry.selected ? Qt.darker(Theme.accent, 1.15) : Theme.backgroundAlt
              opacity: entry.primary || entry.selected || entryArea.containsMouse ? 1 : 0.35
              tooltipText: I18n.tr(entry.primary ? "Primary bar" : "Make this the primary bar")
              onClicked: BarManager.setPrimary(entry.index)
            }

            SquareIconButton {
              visible: (BarManager.localConfig?.length ?? 0) > 1
              size: Widget.height - 6
              iconText: "close"
              iconColor: entry.selected ? Theme.background : Theme.foreground
              backgroundColor: "transparent"
              hoverColor: Theme.error
              tooltipText: I18n.tr("Remove this bar")
              onClicked: BarManager.removeBar(entry.index)
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
          text: "+  " + I18n.tr("New bar")
          opacity: addArea.containsMouse ? 1 : 0.7
        }

        MouseArea {
          id: addArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: BarManager.addBar()
        }
      }

      StyledContainer {
        visible: !!BarManager.copiedStyle
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        Layout.bottomMargin: Widget.spacing
        backgroundColor: pasteAllArea.containsMouse ? Theme.backgroundHighlight : "transparent"
        borderColor: Theme.border
        borderWidth: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Widget.spacing

          StyledIcon {
            text: "format_paint"
            opacity: pasteAllArea.containsMouse ? 1 : 0.7
          }
          StyledText {
            text: I18n.tr("Paste style to all bars")
            opacity: pasteAllArea.containsMouse ? 1 : 0.7
          }
        }

        MouseArea {
          id: pasteAllArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: BarManager.pasteStyleToAll()
        }
      }
    }

    Repeater {
      model: root.bar ? root.groups : []

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
            numberMode: "stepper"
            // The whole bar, so x-showIf sees keys from other groups
            values: root.bar ?? ({})
            onEdited: (path, value) => BarManager.updateBarField(path[0], value)
          }

          // The thickness the size settings add up to
          StyledText {
            visible: "widgetSize" in group.modelData.schema
            text: I18n.tr("Bar thickness: {0} px", Math.round(Bar.enrichBarConfig(root.bar ?? ({})).extent))
            textColor: Theme.foreground
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
