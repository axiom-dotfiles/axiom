pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms

// How axiom and Hyprland's config fit together: what's in ~/.config/hypr
// (OnboardingManager.configState), the three modes with one recommended,
// and, for a managed config, the keyboard and touchpad. The mode is only
// applied on Finish.
OnboardingPage {
  id: root

  readonly property string configState: OnboardingManager.configState
  readonly property string hypr: "~/.config/hypr"

  title: I18n.tr("Hyprland")
  intro: {
    switch (root.configState) {
    case "stock":
    case "none":
      return I18n.tr("Looks like you're running Hyprland's example config. It has its own keys and apps that clash with axiom's (Super+M quits Hyprland, for one). Let axiom manage Hyprland instead: you get a complete setup with sane keybinds, and your own tweaks go in {0}/user/.", root.hypr);
    case "custom":
      return I18n.tr("We noticed you have your own Hyprland config. How should axiom fit in with it?");
    case "blocked":
      return I18n.tr("Your Hyprland config is a symlink or lives in a git repository (dotfiles), so axiom will never take it over. Load axiom's part from it instead.");
    case "legacy":
      return I18n.tr("You have a hyprland.conf in the older format. axiom works with Hyprland's Lua config: letting it manage Hyprland writes a hyprland.lua, and your hyprland.conf is left as it is.");
    case "ours":
      return I18n.tr("axiom already manages your Hyprland config. Nothing to set up here.");
    }
    return I18n.tr("Looking at your Hyprland config…");
  }

  Notice {
    visible: OnboardingManager.hyprlandVersion !== "" && !OnboardingManager.hyprlandSupported
    tone: "error"
    text: I18n.tr("Hyprland {0} is too old: axiom needs 0.55 or newer, with the Lua config. Update Hyprland, then run this again with /welcome.", OnboardingManager.hyprlandVersion)
  }

  Repeater {
    model: [
      {
        "mode": "managed",
        "icon": "auto_awesome",
        "title": I18n.tr("Let axiom manage Hyprland"),
        "description": root.configState === "stock" ? I18n.tr("Replaces the example hyprland.lua (a dated backup stays beside it) with one axiom writes from its settings, then loads your files in {0}/user/ after it.", root.hypr) : root.configState === "custom" ? I18n.tr("Moves your hyprland.lua to {0}/user/00-previous.lua, where it keeps working, loaded after axiom's (a dated backup stays too). Its own binds win over axiom's.", root.hypr) : I18n.tr("axiom writes hyprland.lua from its settings, and loads your own files in {0}/user/ after it.", root.hypr)
      },
      {
        "mode": "included",
        "icon": "input",
        "title": I18n.tr("Load axiom from my config"),
        "description": I18n.tr("Your hyprland.lua stays yours: add two lines to it and axiom's keybinds, borders and monitors load from there.")
      },
      {
        "mode": "detached",
        "icon": "link_off",
        "title": I18n.tr("Keep them apart"),
        "description": I18n.tr("Nothing is written: axiom adds its keybinds while it runs, skipping keys your config already uses. You start axiom yourself.")
      }
    ]

    delegate: OptionCard {
      required property var modelData
      visible: root.configState !== "ours"
      icon: modelData.icon
      title: modelData.title
      description: modelData.description
      selected: OnboardingManager.chosenMode === modelData.mode
      recommended: OnboardingManager.recommendedMode === modelData.mode
      available: !(modelData.mode === "managed" && root.configState === "blocked")
      onClicked: OnboardingManager.chooseMode(modelData.mode)
    }
  }

  // What the chosen mode needs from the user
  ColumnLayout {
    Layout.fillWidth: true
    visible: OnboardingManager.chosenMode === "included"
    spacing: Widget.spacing

    StyledText {
      Layout.fillWidth: true
      text: I18n.tr("Add these lines near the top of your hyprland.lua (after Finish, axiom writes the file they load):")
      wrapMode: Text.WordWrap
    }

    CodeLine {
      text: HyprlandConfigManager.includeLines
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: OnboardingManager.chosenMode === "detached"
    spacing: Widget.spacing

    Notice {
      tone: "warning"
      text: I18n.tr("Hyprland won't start axiom by itself in this mode. Add this to your hyprland.lua so it starts with every session:")
    }

    CodeLine {
      text: HyprlandConfigManager.autostartLines
    }
  }

  Notice {
    visible: HyprlandConfigManager.skippedKeys.length > 0 && OnboardingManager.chosenMode !== "managed"
    tone: "warning"
    text: I18n.tr("Your config already binds {0}, so axiom's binds on those keys are skipped. Free them in your config, or pick other keys on the Keybinds page.", HyprlandConfigManager.skippedKeys.join(", "))
  }

  // Input settings live in the managed config
  ColumnLayout {
    Layout.fillWidth: true
    visible: OnboardingManager.chosenMode === "managed"
    spacing: Widget.spacing

    StyledText {
      Layout.topMargin: Widget.spacing
      text: I18n.tr("Keyboard")
      font.bold: true
    }

    SettingRows {
      Layout.fillWidth: true
      paths: ["Hyprland.managed.kbLayout", "Hyprland.managed.kbVariant"]
    }

    StyledText {
      Layout.topMargin: Widget.spacing
      visible: BatteryManager.isAvailable
      text: I18n.tr("Touchpad")
      font.bold: true
    }

    SettingRows {
      Layout.fillWidth: true
      visible: BatteryManager.isAvailable
      paths: ["Hyprland.managed.naturalScroll", "Hyprland.managed.tapToClick"]
    }
  }

  StyledText {
    Layout.fillWidth: true
    text: I18n.tr("Nothing changes until you press Finish. You can switch modes later in Settings → Hyprland.")
    wrapMode: Text.WordWrap
    textColor: Theme.foregroundAlt
  }
}
