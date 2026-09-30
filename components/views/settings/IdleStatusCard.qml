pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The Idle section's first card (its `x-card`): whether axiom's hypridle
// is running, where its config is, and Restart
StyledContainer {
  id: root

  readonly property string status: HypridleManager.status

  readonly property color statusColor: {
    switch (root.status) {
    case "running":
      return Theme.success;
    case "stopped":
      return Theme.warning;
    case "missing":
      return Theme.error;
    }
    return Theme.foregroundAlt;
  }

  readonly property string statusLabel: {
    switch (root.status) {
    case "running":
      return I18n.tr("Running");
    case "stopped":
      return I18n.tr("Not running");
    case "missing":
      return I18n.tr("Not installed");
    }
    return I18n.tr("Off");
  }

  readonly property string detail: {
    if (HypridleManager.installed === false)
      return I18n.tr("hypridle isn't installed. Install it (pacman -S hypridle) to dim, lock and turn the screens off when you're away.");
    switch (root.status) {
    case "off":
      return I18n.tr("axiom leaves hypridle to you: your own ~/.config/hypr/hypridle.conf is used, if you run it.");
    case "stopped":
      return I18n.tr("axiom's hypridle isn't running. Restart it, or check that hypridle starts from a terminal.");
    }
    return I18n.tr("hypridle runs with the config axiom writes from these settings.");
  }

  implicitHeight: column.implicitHeight + Widget.padding * 2

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledText {
        text: I18n.tr("hypridle")
        textColor: Theme.accent
        textSize: Appearance.fontSize + 1
        font.bold: true
        Layout.fillWidth: true
      }

      Rectangle {
        implicitWidth: chip.implicitWidth + Widget.padding * 2
        implicitHeight: chip.implicitHeight + 4
        radius: height / 2
        color: root.statusColor

        StyledText {
          id: chip
          anchors.centerIn: parent
          text: root.statusLabel
          textColor: Theme.background
          textSize: Appearance.fontSize - 2
          font.bold: true
        }
      }
    }

    StyledText {
      text: root.detail
      textColor: HypridleManager.installed === false ? Theme.error : Theme.foreground
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    GridLayout {
      visible: Idle.enabled
      Layout.fillWidth: true
      columns: 2
      columnSpacing: Widget.spacing * 2
      rowSpacing: Widget.spacing / 2

      StyledText {
        text: I18n.tr("Config")
        opacity: 0.7
      }
      StyledText {
        text: HypridleManager.configPath
        textFamily: "monospace"
        elide: Text.ElideMiddle
        Layout.fillWidth: true
      }
    }

    StyledText {
      visible: Idle.enabled && HypridleManager.replacedOther
      text: I18n.tr("axiom stopped another hypridle, likely started by your own Hyprland config. Remove its autostart line so the two don't fight at login.")
      textColor: Theme.warning
      textSize: Appearance.fontSize - 1
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    RowLayout {
      visible: Idle.enabled && HypridleManager.installed === true
      Layout.fillWidth: true
      spacing: Widget.spacing

      Item {
        Layout.fillWidth: true
      }

      StyledTextButton {
        implicitHeight: Widget.height - 4
        text: I18n.tr("Restart")
        onClicked: HypridleManager.restart()
      }
    }
  }
}
