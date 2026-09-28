pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable

// Theme integrations (other apps in axiom's colors), marked by whether the
// app is installed, then the lock screen, self-updates, the launcher's
// clipboard history and whether axiom runs hypridle (Idle.enabled: off by
// default, recommended on)
OnboardingPage {
  id: root

  title: I18n.tr("Integrations")
  intro: I18n.tr("axiom can color other apps to match its theme. Each one writes only its own axiom file: the setting's description in Settings says the line to add to that app's config. A tick marks the apps you have installed.")

  // The command that shows each integration's app is installed ("" for
  // ones every desktop has)
  readonly property var commands: ({
      "gtk": "",
      "qt": "qt6ct",
      "kitty": "kitty",
      "alacritty": "alacritty",
      "foot": "foot",
      "wezterm": "wezterm",
      "ghostty": "ghostty",
      "nvim": "nvim",
      "helix": "hx",
      "vscode": "code",
      "k9s": "k9s",
      "cava": "cava",
      "btop": "btop",
      "fzf": "fzf",
      "lazygit": "lazygit",
      "bat": "bat",
      "yazi": "yazi"
    })
  readonly property var schema: ConfigManager.configSchema?.properties?.ThemeIntegrations?.properties ?? ({})
  readonly property var keys: Object.keys(root.schema).filter(key => root.schema[key].type === "boolean")

  function installed(key) {
    const command = root.commands[key] ?? key;
    return command === "" || DependencyManager.found[command] === true;
  }

  Component.onCompleted: DependencyManager.check(Object.keys(commands).map(key => commands[key]).filter(command => command !== "").concat(["hypridle"]))

  StyledTextButton {
    text: I18n.tr("Turn on for installed apps")
    iconText: "done_all"
    onClicked: OnboardingManager.set(root.keys.filter(key => root.installed(key) && key !== "gtk" && key !== "qt").reduce((values, key) => {
      values["ThemeIntegrations." + key] = true;
      return values;
    }, {}))
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Widget.spacing * 3
    rowSpacing: Widget.spacing

    Repeater {
      model: root.keys

      delegate: RowLayout {
        id: integration
        required property string modelData
        readonly property bool present: root.installed(modelData)
        readonly property bool isOn: ConfigManager.config.ThemeIntegrations[modelData] === true
        Layout.fillWidth: true
        spacing: Widget.spacing

        StyledIcon {
          text: integration.present ? "check_circle" : "radio_button_unchecked"
          textColor: integration.present ? Theme.success : Theme.foregroundInactive
        }

        StyledText {
          Layout.fillWidth: true
          text: I18n.tr(root.schema[integration.modelData].title ?? integration.modelData)
          elide: Text.ElideRight
          textColor: integration.present ? Theme.foreground : Theme.foregroundInactive
        }

        StyledSwitch {
          checked: integration.isOn
          onToggled: {
            const values = {};
            values["ThemeIntegrations." + integration.modelData] = checked;
            OnboardingManager.set(values);
          }
        }
      }
    }
  }

  StyledText {
    Layout.topMargin: Widget.spacing
    text: I18n.tr("Lock screen and updates")
    font.bold: true
  }

  SettingRows {
    Layout.fillWidth: true
    paths: ["Lockscreen.mode", "SelfUpdate.mode"]
  }

  StyledText {
    Layout.topMargin: Widget.spacing
    text: I18n.tr("Clipboard history")
    font.bold: true
  }

  StyledText {
    Layout.fillWidth: true
    text: I18n.tr("Type : in the launcher to search what you've copied. axiom keeps it in memory only and skips what password managers mark as sensitive; turn it off if you copy passwords from apps that don't.")
    wrapMode: Text.WordWrap
  }

  SettingRows {
    Layout.fillWidth: true
    paths: ["Launcher.clipboard", "Launcher.clipboardSource"]
  }

  StyledText {
    Layout.topMargin: Widget.spacing
    text: I18n.tr("Idle")
    font.bold: true
  }

  Notice {
    Layout.fillWidth: true
    visible: DependencyManager.found.hypridle === false
    text: I18n.tr("hypridle isn't installed. Install it (pacman -S hypridle) to dim, lock and turn the screens off when you're away, then turn it on in Settings → Idle.")
  }

  RowLayout {
    Layout.fillWidth: true
    visible: DependencyManager.found.hypridle === true
    spacing: Widget.spacing

    OptionCard {
      // Equal halves, as tall as the taller one
      Layout.preferredWidth: 1
      Layout.fillHeight: true
      icon: "bedtime"
      title: I18n.tr("Let axiom manage hypridle")
      description: I18n.tr("Dims, locks and turns the screens off when you're away, set up from axiom's settings. Stops any hypridle you run yourself.")
      selected: Idle.enabled
      recommended: true
      onClicked: OnboardingManager.set({
        "Idle.enabled": true
      })
    }

    OptionCard {
      // Equal halves, as tall as the taller one
      Layout.preferredWidth: 1
      Layout.fillHeight: true
      icon: "tune"
      title: I18n.tr("Use my own")
      description: I18n.tr("Leaves hypridle, and your hypridle.conf, to you.")
      selected: !Idle.enabled
      onClicked: OnboardingManager.set({
        "Idle.enabled": false
      })
    }
  }

  SettingRows {
    Layout.fillWidth: true
    visible: DependencyManager.found.hypridle === true && Idle.enabled
    paths: ["Idle.dimTimeout", "Idle.lockTimeout", "Idle.screenOffTimeout", "Idle.suspendTimeout"]
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: DependencyManager.found.hypridle === true && !Idle.enabled && ConfigManager.config.Lockscreen.mode !== "none"
    spacing: Widget.spacing

    StyledText {
      Layout.fillWidth: true
      text: I18n.tr("To lock after some idle time with your own hypridle, point its general section in ~/.config/hypr/hypridle.conf at axiom:")
      wrapMode: Text.WordWrap
    }

    CodeLine {
      text: "lock_cmd = qs -c axiom ipc call lockscreen lock\nbefore_sleep_cmd = loginctl lock-session"
    }
  }
}
