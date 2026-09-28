pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The General section's first card (the section's `x-card`): the
// first-time setup (OnboardingManager), to run again
StyledContainer {
  id: root

  implicitHeight: row.implicitHeight + Widget.padding * 2
  backgroundColor: Theme.backgroundAlt

  RowLayout {
    id: row
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 2

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      StyledText {
        text: I18n.tr("First-time setup")
        textColor: Theme.accent
        textSize: Appearance.fontSize + 1
        font.bold: true
      }

      StyledText {
        Layout.fillWidth: true
        text: I18n.tr("Walks through Hyprland, monitors, apps and keys, workspaces, the look and integrations again.")
        wrapMode: Text.WordWrap
        opacity: 0.7
      }
    }

    StyledTextButton {
      text: I18n.tr("Run setup")
      iconText: "waving_hand"
      onClicked: {
        ShellManager.closeOverlay();
        OnboardingManager.open();
      }
    }
  }
}
