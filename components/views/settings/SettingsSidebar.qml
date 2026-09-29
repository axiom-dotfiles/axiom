pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// Settings page, left: search and the category list. The selection and
// search text live in SettingsManager, so they survive the page reloading.
Item {
  id: root

  // SchemaLayout.categories(), plus the built-in Backups page
  required property var categories
  // The category shown (the first one until one is picked)
  required property string selected

  // Material Symbols icon per category
  function icon(name) {
    switch (name) {
    case "Desktop":
      return "monitor";
    case "Hyprland":
      return "desktop_windows";
    case "Look & Feel":
      return "palette";
    case "Bar & Popouts":
      return "dashboard";
    case "Overlay & OSD":
      return "layers";
    case "Dock":
      return "dock_to_bottom";
    case "Chat":
      return "chat";
    case "Notes":
      return "sticky_note_2";
    case "Updates":
      return "update";
    case "Backups":
      return "settings_backup_restore";
    }
    return "settings";
  }

  Card {
    color: Theme.background
    border.color: Theme.border

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      StyledText {
        text: I18n.tr("Settings")
        textSize: Appearance.fontSize + 4
        font.bold: true
        Layout.fillWidth: true
        Layout.bottomMargin: Widget.spacing / 2
      }

      StyledTextEntry {
        id: search
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        placeholderText: I18n.tr("Search settings")
        Component.onCompleted: input.text = SettingsManager.query
        onTextChanged: SettingsManager.query = text

        // Cleared from outside, e.g. by picking a category
        Connections {
          target: SettingsManager
          function onQueryChanged() {
            if (search.input.text !== SettingsManager.query)
              search.input.text = SettingsManager.query;
          }
        }
      }

      Repeater {
        model: root.categories

        delegate: StyledContainer {
          id: entry
          required property var modelData
          readonly property bool selected: SettingsManager.query === "" && root.selected === modelData.name
          readonly property bool changed: modelData.sections.some(section => SettingsManager.hasChangesUnder(section))

          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height + Widget.padding
          backgroundColor: selected ? Theme.accent : (entryArea.containsMouse ? Theme.backgroundHighlight : "transparent")
          borderWidth: 0

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Widget.padding
            anchors.rightMargin: Widget.padding
            spacing: Widget.spacing

            StyledIcon {
              text: root.icon(entry.modelData.name)
              textColor: entry.selected ? Theme.background : Theme.accent
              Layout.preferredWidth: Appearance.fontSize * 1.5
            }

            StyledText {
              // Category names come from the schema's x-category:
              // I18n.tr("Desktop") I18n.tr("Hyprland") I18n.tr("Look & Feel") I18n.tr("Bar & Popouts")
              // I18n.tr("Overlay & OSD") I18n.tr("Chat") I18n.tr("Notes") I18n.tr("Updates") I18n.tr("Backups")
              // I18n.tr("Dock")
              text: I18n.tr(entry.modelData.name)
              textColor: entry.selected ? Theme.background : Theme.foreground
              font.bold: entry.selected
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            // Unsaved edits in this category
            Rectangle {
              visible: entry.changed
              implicitWidth: 8
              implicitHeight: 8
              radius: 4
              color: entry.selected ? Theme.background : Theme.accent
            }
          }

          MouseArea {
            id: entryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              SettingsManager.query = "";
              SettingsManager.category = entry.modelData.name;
            }
          }
        }
      }

      Item {
        Layout.fillHeight: true
      }

      StyledText {
        visible: SettingsManager.changedCount > 0
        text: I18n.tr("{0} unsaved changes", SettingsManager.changedCount)
        textColor: Theme.accent
        textSize: Appearance.fontSize - 1
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      StyledText {
        visible: SettingsManager.changedCount === 0
        text: I18n.tr("Changes apply as you make them. Save keeps them.")
        opacity: 0.6
        textSize: Appearance.fontSize - 2
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }
}
