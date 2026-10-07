pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The Hyprland category's first card (the section's `x-card`): whether
// the mode is in effect and what it needs, and, while a new mode waits for
// Save (`x-applyOnSave`), what saving will do
FieldGroup {
  id: root

  readonly property string mode: HyprlandConfigManager.mode
  readonly property string status: HyprlandConfigManager.status
  // The mode picked in the settings draft
  readonly property string pendingMode: SettingsManager.localConfig?.Hyprland?.mode ?? root.mode
  readonly property bool pending: root.pendingMode !== root.mode

  function _checkPending() {
    if (root.pendingMode === "managed")
      HyprlandConfigManager.checkManaged();
  }
  onPendingModeChanged: root._checkPending()
  Component.onCompleted: root._checkPending()

  // I18n.tr("Detached") I18n.tr("Included") I18n.tr("Managed")
  function _modeLabel(mode) {
    return I18n.tr(mode.charAt(0).toUpperCase() + mode.slice(1));
  }

  readonly property color statusColor: {
    switch (root.status) {
    case "loaded":
    case "runtime":
      return Theme.success;
    case "fallback":
      return Theme.warning;
    }
    return Theme.foregroundAlt;
  }

  readonly property string statusLabel: {
    switch (root.status) {
    case "runtime":
      return I18n.tr("Applied at runtime");
    case "loaded":
      return I18n.tr("Loaded");
    case "fallback":
      return I18n.tr("Not loaded");
    }
    return I18n.tr("Checking…");
  }

  // What saving the pending mode does, step by step
  readonly property var saveSteps: {
    const steps = [];
    const hypr = Paths.shortenHome(HyprlandConfigManager.managedPath);
    const user = Paths.shortenHome(HyprlandConfigManager.userDir);
    const module = Paths.shortenHome(HyprlandConfigManager.includePath);
    // Leaving a mode gives back what it took (HyprlandConfigManager._leave)
    if (root.mode === "managed")
      steps.push(I18n.tr("Gives {0} back: your previous one returns ({1}/00-previous.lua, or the example config's backup), else a new one that starts axiom and loads {1}/*.lua", hypr, user));
    if (root.mode === "included")
      steps.push(I18n.tr("Empties {0}, so a hyprland.lua that still loads it gets nothing", module));
    if (root.pendingMode === "managed") {
      switch (HyprlandConfigManager.managedCheck) {
      case "adopt":
        steps.push(I18n.tr("Moves your {0} to {1}/00-previous.lua, with a dated backup beside it", hypr, user));
        break;
      case "stock":
        steps.push(I18n.tr("Replaces Hyprland's example {0}, keeping a dated backup beside it: its binds and monitor rule would fight axiom's", hypr));
        break;
      case "released":
        steps.push(I18n.tr("Replaces {0}, which axiom wrote when it last left managed mode", hypr));
        break;
      case "ours":
        steps.push(I18n.tr("Takes back {0}, which axiom already wrote", hypr));
        break;
      case "":
        steps.push(I18n.tr("Checking {0}…", Paths.shortenHome(Paths.hyprlandPath)));
        break;
      }
      steps.push(I18n.tr("Writes {0} from the cards below, loading {1}/*.lua after it", hypr, user));
      steps.push(I18n.tr("Reloads Hyprland"));
    } else if (root.pendingMode === "included") {
      steps.push(I18n.tr("Writes {0}", module));
      steps.push(I18n.tr("Shows the lines to add to your hyprland.lua. Until you do, axiom applies its layer at runtime"));
    } else {
      steps.push(I18n.tr("Applies axiom's layer with hyprctl"));
    }
    if (root.mode === "managed")
      steps.push(I18n.tr("Reloads Hyprland"));
    return steps;
  }

  readonly property bool blocked: root.pendingMode === "managed" && HyprlandConfigManager.managedCheck === "blocked"

  title: I18n.tr("Status")
  headerExtras: [
    StyledText {
      text: root._modeLabel(root.mode)
      opacity: 0.7
    },
    StatusChip {
      text: root.statusLabel
      color: root.statusColor
    }
  ]

  // --- A mode change waiting for Save ---

  StyledContainer {
    visible: root.pending
    Layout.fillWidth: true
    implicitHeight: pendingColumn.implicitHeight + Widget.padding * 2
    backgroundColor: Theme.background
    borderColor: root.blocked ? Theme.error : Theme.accent

    ColumnLayout {
      id: pendingColumn
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Widget.padding
      spacing: Widget.spacing / 2

      StyledText {
        text: root.blocked ? I18n.tr("Can't switch to Managed") : I18n.tr("Save switches to {0}:", root._modeLabel(root.pendingMode))
        textColor: root.blocked ? Theme.error : Theme.accent
        font.bold: true
        Layout.fillWidth: true
      }

      StyledText {
        visible: root.blocked
        text: HyprlandConfigManager.managedBlockedBy === "git" ? I18n.tr("{0} is inside the git repository at {1}, so axiom won't take it over. Use Included instead.", Paths.shortenHome(Paths.hyprlandPath), Paths.shortenHome(HyprlandConfigManager.managedBlockedRepo)) : I18n.tr("{0} is a symlink or in a git repository, so axiom won't take it over. Use Included instead.", Paths.shortenHome(Paths.hyprlandPath))
        textSize: Appearance.fontSize - 1
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      Repeater {
        model: root.blocked ? [] : root.saveSteps

        delegate: StyledText {
          required property string modelData
          text: "•  " + modelData
          textSize: Appearance.fontSize - 1
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }
  }

  // --- The mode in effect ---

  StyledText {
    visible: root.status === "fallback"
    text: HyprlandConfigManager.problem + "\n" + I18n.tr("Until then, axiom applies its layer at runtime.")
    textColor: Theme.warning
    textSize: Appearance.fontSize - 1
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  StyledText {
    visible: root.mode === "detached"
    text: I18n.tr("Nothing to set up. Binds on keys your config uses are skipped.")
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  ColumnLayout {
    visible: root.mode === "included"
    Layout.fillWidth: true
    spacing: Widget.spacing

    StyledText {
      text: I18n.tr("Add near the top of your hyprland.lua (anything after overrides axiom):")
      opacity: 0.7
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    StyledContainer {
      Layout.fillWidth: true
      implicitHeight: lines.implicitHeight + Widget.padding * 2
      backgroundColor: Theme.background

      StyledText {
        id: lines
        anchors.fill: parent
        anchors.margins: Widget.padding
        text: HyprlandConfigManager.includeLines
        textFamily: "monospace"
        textSize: Appearance.fontSize - 2
        wrapMode: Text.WrapAnywhere
      }
    }

    StyledTextButton {
      implicitHeight: Widget.height - 4
      text: I18n.tr("Copy")
      onClicked: HyprlandConfigManager.copyIncludeLines()
    }
  }

  RowLayout {
    visible: root.mode === "managed"
    Layout.fillWidth: true
    spacing: Widget.spacing

    StyledText {
      text: I18n.tr("Your own settings go in {0}/*.lua.", Paths.shortenHome(HyprlandConfigManager.userDir))
      opacity: 0.7
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    StyledTextButton {
      implicitHeight: Widget.height - 4
      text: I18n.tr("Open folder")
      onClicked: HyprlandConfigManager.openConfigDir()
    }
  }

  StyledText {
    visible: root.pendingMode !== "managed"
    text: I18n.tr("Managed mode adds layout, decoration, keyboard and mouse settings.")
    opacity: 0.6
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
}
