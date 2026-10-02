pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable

// The last page: what Finish does to Hyprland, whether axiom starts with
// the session, and where to go from here
OnboardingPage {
  id: root

  readonly property string mode: OnboardingManager.chosenMode
  readonly property bool changesMode: OnboardingManager.hyprlandSupported && OnboardingManager.modeAllowed && root.mode !== HyprlandConfig.mode

  title: I18n.tr("All set")
  intro: I18n.tr("That's the essentials. Press Finish to apply the Hyprland setup and start using axiom.")

  Notice {
    visible: root.changesMode && root.mode === "managed"
    tone: "info"
    text: OnboardingManager.configState === "stock" ? I18n.tr("Finish replaces Hyprland's example hyprland.lua with axiom's (a dated backup stays beside it) and reloads Hyprland. axiom starts with every session from then on.") : OnboardingManager.configState === "custom" ? I18n.tr("Finish moves your hyprland.lua to user/00-previous.lua (a dated backup stays too), writes axiom's in its place and reloads Hyprland. axiom starts with every session from then on.") : I18n.tr("Finish writes hyprland.lua and reloads Hyprland. axiom starts with every session from then on.")
  }

  Notice {
    visible: root.mode === "included"
    tone: OnboardingManager.includeDone && OnboardingManager.autostartDone ? "info" : "warning"
    text: !OnboardingManager.includeDone ? I18n.tr("Finish writes axiom's Hyprland module, but your hyprland.lua doesn't load it yet: Apply the lines on the Hyprland step. Until then, axiom adds its keybinds while it runs.") : !OnboardingManager.autostartDone ? I18n.tr("Finish writes axiom's Hyprland module, which your hyprland.lua loads. It doesn't start axiom yet: Apply the autostart line on the Hyprland step.") : I18n.tr("Finish writes axiom's Hyprland module, which your hyprland.lua loads.")
  }

  Notice {
    visible: root.mode === "detached" && !OnboardingManager.autostartDone
    tone: "warning"
    text: I18n.tr("Hyprland won't start axiom by itself: Apply the autostart line on the Hyprland step, or add it to your hyprland.lua yourself.")
  }

  StyledText {
    Layout.topMargin: Widget.spacing
    text: I18n.tr("Where things are")
    font.bold: true
  }

  BindsTable {
    Layout.fillWidth: true
    entries: [
      {
        "action": "launcher",
        "label": I18n.tr("Launch apps, and type / for commands")
      },
      {
        "action": "overlay",
        "label": I18n.tr("Overlay: cards, Settings, Keybinds, Monitors")
      },
      {
        "action": "terminal",
        "label": I18n.tr("Terminal")
      },
      {
        "action": "workspaceOverview",
        "label": I18n.tr("Workspace overview")
      },
      {
        "action": "powerMenu",
        "label": I18n.tr("Power menu")
      },
      {
        "action": "restartShell",
        "label": I18n.tr("Restart axiom if it gets stuck")
      },
      {
        "action": "exitHyprland",
        "label": I18n.tr("Leave Hyprland")
      }
    ]
  }

  StyledText {
    Layout.fillWidth: true
    Layout.topMargin: Widget.spacing
    text: I18n.tr("In the launcher, / lists commands: /config sets any setting, /monitors opens the monitor layout, and /welcome brings this setup back. The overlay's pages hold Settings, the Keybinds editor, the Bar and overlay editors, and themes.")
    wrapMode: Text.WordWrap
  }
}
