pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

/**
 * Settings page, Maintenance (the category's `page`): save the whole config
 * under a name, and restore or delete saved ones. Only the active one (last
 * saved or restored) can be overwritten from its row; it's marked Current,
 * with an unsaved dot once the running config differs. Overwrite, restore,
 * delete and reverting to the defaults ask for a second click to confirm.
 */
FieldGroup {
  id: root

  title: I18n.tr("Saved configurations")
  description: I18n.tr("Snapshots of the entire configuration, stored in {0}. Restoring replaces the current configuration.", SavedConfigsManager.savedDir)

  // Row awaiting a confirming click: { name, action }. The defaults row uses
  // an empty name, which no saved file can have.
  property var pending: null

  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    StyledTextEntry {
      id: nameEntry
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
      placeholderText: I18n.tr("Configuration name")
      onAccepted: root.save()
    }

    StyledTextButton {
      Layout.preferredHeight: Widget.height
      text: I18n.tr(SavedConfigsManager.exists(nameEntry.text) ? "Overwrite" : "Save")
      onClicked: root.save()
    }
  }

  StyledText {
    visible: SavedConfigsManager.status !== ""
    text: SavedConfigsManager.status
    opacity: 0.7
    textSize: Appearance.fontSize - 1
    Layout.fillWidth: true
  }

  StyledText {
    visible: SavedConfigsManager.model.count === 0
    text: I18n.tr("No saved configurations yet.")
    opacity: 0.5
    Layout.fillWidth: true
  }

  Repeater {
    model: SavedConfigsManager.model

    delegate: StyledContainer {
      id: row
      required property string fileBaseName
      required property date fileModified
      readonly property bool active: SavedConfigsManager.active === fileBaseName
      readonly property string pendingAction: root.pending?.name === fileBaseName ? root.pending.action : ""

      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height + Widget.padding * 2

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Widget.padding
        anchors.rightMargin: Widget.padding
        spacing: Widget.spacing

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          // The name at its full width while it fits, then elided, with
          // the badges right after it
          Item {
            id: nameLine
            Layout.fillWidth: true
            implicitWidth: nameText.implicitWidth + (badges.visible ? Widget.spacing + badges.implicitWidth : 0)
            implicitHeight: Math.max(nameText.implicitHeight, badges.implicitHeight)

            StyledText {
              id: nameText
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, nameLine.width - (badges.visible ? Widget.spacing + badges.implicitWidth : 0))
              text: row.fileBaseName
              font.bold: true
              elide: Text.ElideRight
            }

            Row {
              id: badges
              visible: row.active
              x: nameText.width + Widget.spacing
              anchors.verticalCenter: parent.verticalCenter
              spacing: Widget.spacing

              StatusChip {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accent
                text: I18n.tr("Current")
              }

              UnsavedDot {
                anchors.verticalCenter: parent.verticalCenter
                shown: SavedConfigsManager.modified
              }
            }
          }

          StyledText {
            text: I18n.formatDate(row.fileModified, I18n.dateFormat("dateTime"))
            opacity: 0.6
            textSize: Appearance.fontSize - 2
            Layout.fillWidth: true
          }
        }

        StyledTextButton {
          visible: row.active
          Layout.preferredHeight: Widget.height
          text: I18n.tr(row.pendingAction === "overwrite" ? "Confirm" : "Overwrite")
          onClicked: root.confirm(row.fileBaseName, "overwrite")
        }

        StyledTextButton {
          Layout.preferredHeight: Widget.height
          text: I18n.tr(row.pendingAction === "restore" ? "Confirm" : "Restore")
          onClicked: root.confirm(row.fileBaseName, "restore")
        }

        StyledTextButton {
          Layout.preferredHeight: Widget.height
          text: I18n.tr(row.pendingAction === "delete" ? "Confirm" : "Delete")
          hoverColor: Theme.error
          onClicked: root.confirm(row.fileBaseName, "delete")
        }
      }
    }
  }

  StyledContainer {
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height + Widget.padding * 2

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.padding
      spacing: Widget.spacing

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          text: I18n.tr("Defaults")
          font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        StyledText {
          text: I18n.tr("The configuration a first run starts with")
          opacity: 0.6
          textSize: Appearance.fontSize - 2
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      StyledTextButton {
        readonly property bool armed: root.pending?.name === "" && root.pending?.action === "restore"
        Layout.preferredHeight: Widget.height
        text: I18n.tr(armed ? "Confirm" : "Restore")
        hoverColor: Theme.error
        onClicked: root.confirm("", "restore")
      }
    }
  }

  function save() {
    SavedConfigsManager.save(nameEntry.text);
    nameEntry.text = "";
    root.pending = null;
  }

  // First click arms the action, a second click on the same button runs it
  function confirm(name, action) {
    if (root.pending?.name !== name || root.pending?.action !== action) {
      root.pending = {
        name: name,
        action: action
      };
      return;
    }
    root.pending = null;
    if (action === "restore" && name === "")
      SavedConfigsManager.restoreDefaults();
    else if (action === "restore")
      SavedConfigsManager.restore(name);
    else if (action === "overwrite")
      SavedConfigsManager.save(name);
    else
      SavedConfigsManager.remove(name);
  }
}
