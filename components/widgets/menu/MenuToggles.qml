// in/your/path/MenuToggles.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable

/*
 * A panel containing several menu items for quick actions like
 * toggling dark mode, opening the power menu, and pinning the panel.
 */
StyledContainer {
  id: menuToggles
  width: parent.width
  height: buttonSize
  Layout.fillWidth: true
  property int buttonSize: 60

  RowLayout {
    id: layout
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    Layout.fillWidth: true
    anchors.fill: parent
    spacing: Widget.spacing

    // --- Dark Mode Toggle ---
    StyledTextButton {
      Layout.leftMargin: Widget.padding
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      Layout.preferredHeight: buttonSize
      Layout.fillWidth: true
      backgroundColor: Theme.cyan
      textColor: Theme.background
      text: Appearance.darkMode ? "" : ""
      onClicked: ThemeManager.toggleDarkMode()
    }

    // --- Power Menu ---
    StyledTextButton {
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      Layout.preferredHeight: buttonSize
      Layout.fillWidth: true
      backgroundColor: Theme.red
      textColor: Theme.background
      text: ""
      onClicked: ShellManager.openPowerMenu()
    }

    // --- Placeholder/Settings Button ---
    StyledTextButton {
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      Layout.preferredHeight: buttonSize
      Layout.fillWidth: true
      backgroundColor: Theme.yellow
      textColor: Theme.background
      text: ""
    }

    // --- Toggle Pinned Panel ---
    StyledTextButton {
      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
      Layout.preferredHeight: buttonSize
      Layout.rightMargin: Widget.padding
      Layout.fillWidth: true
      backgroundColor: Theme.green
      textColor: Theme.background
      text: ""
      onClicked: ShellManager.togglePinnedPanel("mainMenu")
    }
  }
}
