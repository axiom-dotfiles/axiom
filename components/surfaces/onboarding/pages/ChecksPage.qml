pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable

// What's missing: the icon font, and the programs features use
// (DependencyManager.tools), with one command that installs them
OnboardingPage {
  id: root

  title: I18n.tr("Checks")
  intro: I18n.tr("axiom uses a few programs for some of its features. Everything else works without them.")

  readonly property var missing: DependencyManager.tools.filter(tool => DependencyManager.found[tool.command] === false)
  readonly property bool checked: DependencyManager.tools.every(tool => DependencyManager.found[tool.command] !== undefined)
  readonly property var packages: Array.from(new Set((DependencyManager.iconFontInstalled ? [] : ["ttf-material-symbols-variable"]).concat(root.missing.map(tool => tool.package))))

  Component.onCompleted: DependencyManager.check(DependencyManager.tools.map(tool => tool.command))

  Notice {
    visible: !DependencyManager.iconFontInstalled
    tone: "error"
    text: I18n.tr("The icon font ({0}) isn't installed, so icons show as words. Install {1}, then restart the shell.", Appearance.iconFamily, "ttf-material-symbols-variable")
  }

  Notice {
    visible: root.checked && root.packages.length === 0
    tone: "success"
    text: I18n.tr("Everything axiom uses is installed.")
  }

  Repeater {
    model: DependencyManager.tools

    delegate: RowLayout {
      id: tool
      required property var modelData
      readonly property var present: DependencyManager.found[modelData.command]
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledIcon {
        text: tool.present === undefined ? "hourglass_empty" : tool.present ? "check_circle" : "cancel"
        textColor: tool.present === undefined ? Theme.foregroundInactive : tool.present ? Theme.success : Theme.warning
      }

      StyledText {
        text: tool.modelData.command
        textFamily: "monospace"
      }

      StyledText {
        Layout.fillWidth: true
        // I18n.tr: purposes are declared in DependencyManager
        text: I18n.tr(tool.modelData.purpose)
        textColor: Theme.foregroundAlt
        elide: Text.ElideRight
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.packages.length > 0
    spacing: Widget.spacing

    StyledText {
      Layout.topMargin: Widget.spacing
      Layout.fillWidth: true
      text: I18n.tr("To install what's missing on Arch (a package that isn't in the official repositories, like the icon font, comes from the AUR: use your AUR helper instead of pacman for it):")
      wrapMode: Text.WordWrap
    }

    CodeLine {
      text: "sudo pacman -S --needed " + root.packages.join(" ")
    }
  }

  StyledTextButton {
    text: I18n.tr("Check again")
    iconText: "refresh"
    onClicked: DependencyManager.check(DependencyManager.tools.map(tool => tool.command))
  }
}
