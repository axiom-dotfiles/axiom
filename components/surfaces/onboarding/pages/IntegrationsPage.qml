pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms

// Theme integrations (other apps in axiom's colors), marked by whether the
// app is installed, and the switched-on ones' hookups (IntegrationHookup),
// then the lock screen, self-updates, the launcher's
// clipboard history and whether axiom runs hypridle (Idle.enabled: off by
// default, recommended on)
OnboardingPage {
  id: root

  title: I18n.tr("Integrations")
  intro: I18n.tr("axiom can color other apps to match its theme. Each one writes only its own axiom file; once it's on, below shows the line that loads it from the app's config, to copy or to apply for you. A tick marks the apps you have installed.")

  // The switched-on integrations with something to hook up
  readonly property var hookups: ThemeManager.integrations.filter(key => ThemeIntegrations[key] === true && IntegrationHookupManager.targets(key).length > 0)

  function installed(key) {
    const commands = ThemeManager.integrationCommands(key);
    return commands.length === 0 || commands.some(command => DependencyManager.found[command] === true);
  }

  Component.onCompleted: DependencyManager.check([].concat(...ThemeManager.integrations.map(key => ThemeManager.integrationCommands(key))).concat(["hypridle"]))

  StyledTextButton {
    text: I18n.tr("Turn on for installed apps")
    iconText: "done_all"
    onClicked: SettingsManager.commitValues(ThemeManager.integrations.filter(key => root.installed(key) && key !== "gtk" && key !== "qt").reduce((values, key) => {
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
      model: ThemeManager.integrations

      delegate: RowLayout {
        id: integration
        required property string modelData
        readonly property bool present: root.installed(modelData)
        readonly property bool isOn: ThemeIntegrations[modelData] === true
        Layout.fillWidth: true
        spacing: Widget.spacing

        StyledIcon {
          text: integration.present ? "check_circle" : "radio_button_unchecked"
          textColor: integration.present ? Theme.success : Theme.foregroundInactive
        }

        StyledText {
          Layout.fillWidth: true
          text: I18n.tr(ThemeManager.integrationTitle(integration.modelData))
          elide: Text.ElideRight
          textColor: integration.present ? Theme.foreground : Theme.foregroundInactive
        }

        StyledSwitch {
          checked: integration.isOn
          onToggled: {
            const values = {};
            values["ThemeIntegrations." + integration.modelData] = checked;
            SettingsManager.commitValues(values);
          }
        }
      }
    }
  }

  // The switched-on integrations' hookups: the line to add, and Apply
  // (i18n: keys from the schema: integration titles)
  StyledText {
    Layout.topMargin: Widget.spacing
    visible: root.hookups.length > 0
    text: root.hookups.every(key => IntegrationHookupManager.isDone(key)) ? I18n.tr("Every app you turned on is set up") : I18n.tr("Finish setting up")
    font.bold: true
  }

  Repeater {
    model: root.hookups

    // Set up ones drop out once checked (Settings still shows them)
    delegate: ColumnLayout {
      id: hookup
      required property string modelData
      Layout.fillWidth: true
      visible: !IntegrationHookupManager.isDone(hookup.modelData)
      spacing: Widget.spacing / 2

      StyledText {
        text: I18n.tr(ThemeManager.integrationTitle(hookup.modelData))
        textColor: Theme.accent
        font.bold: true
      }

      IntegrationHookup {
        Layout.fillWidth: true
        integration: hookup.modelData
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
    paths: ["Lockscreen.mode", "SelfUpdate.mode", "SelfUpdate.channel"]
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
      onClicked: SettingsManager.commitValues({
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
      onClicked: SettingsManager.commitValues({
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
    visible: DependencyManager.found.hypridle === true && !Idle.enabled && LockscreenConfig.mode !== "none"
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
