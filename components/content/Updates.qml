pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts

// Pending updates, repo and AUR listed separately (from UpdatesManager). As
// the Updates widget's popout (the widget acquires the manager), or an
// overlay card, which acquires it with its own settings.
// properties (card): { intervalMinutes, includeAur, aurHelper }
Panel {
  id: root

  // [{ name, from, to }]
  property var repoPackages: UpdatesManager.repoPackages
  property var aurPackages: UpdatesManager.aurPackages
  readonly property int total: repoPackages.length + aurPackages.length

  spacing: Widget.padding
  // A card fits rows of roughly one text line each into its height
  property int maxRows: root.embedded ? Math.max(3, Math.floor(root.height / (Appearance.fontSize * 2)) - 4) : 15

  function register() {
    if (!root.embedded)
      return;
    UpdatesManager.acquire(root, {
      "intervalMinutes": root.properties.intervalMinutes ?? 60,
      "aurHelper": root.properties.includeAur ? (root.properties.aurHelper ?? "paru") : ""
    });
  }
  onPropertiesChanged: register()
  onEmbeddedChanged: register()
  Component.onCompleted: register()
  Component.onDestruction: UpdatesManager.release(root)

  compactContent: CompactFigure {
    icon: "update"
    iconColor: root.total > 0 ? Theme.accent : Theme.foregroundAlt
    value: UpdatesManager.checking && root.total === 0 ? "…" : String(root.total)
    label: I18n.tr("updates")
  }
  // Narrow cards show only the new version
  readonly property bool narrow: root.embedded && root.width < 360

  implicitWidth: Math.max(320, body.implicitWidth + margins * 2)

  component Section: ColumnLayout {
    id: section
    required property string title
    required property var packages

    visible: packages.length > 0
    spacing: 2
    Layout.fillWidth: true

    StyledText {
      text: `${section.title} (${section.packages.length})`
      font.bold: true
      textColor: Theme.accent
    }

    Repeater {
      model: section.packages.slice(0, root.maxRows)

      RowLayout {
        id: row
        required property var modelData
        Layout.fillWidth: true
        spacing: Widget.padding

        StyledText {
          text: row.modelData.name
          Layout.fillWidth: true
          Layout.minimumWidth: Appearance.fontSize * 4
          elide: Text.ElideRight
        }
        StyledText {
          Layout.maximumWidth: root.width * 0.45
          elide: Text.ElideLeft
          text: root.narrow ? row.modelData.to : `${row.modelData.from} → ${row.modelData.to}`
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
        }
      }
    }

    StyledText {
      visible: section.packages.length > root.maxRows
      text: I18n.tr("+{0} more", section.packages.length - root.maxRows)
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
    }
  }

  ModuleHeader {
    visible: root.embedded
    icon: "update"
    title: root.total > 0 ? I18n.tr("{0} updates", root.total) : I18n.tr("Up to date")
    StyledText {
      visible: UpdatesManager.checking
      text: I18n.tr("checking…")
      textSize: Appearance.fontSize - 2
      opacity: 0.6
    }
  }

  Section {
    title: I18n.tr("Repositories")
    packages: root.repoPackages
  }

  Section {
    title: I18n.tr("AUR")
    packages: root.aurPackages
  }

  StyledText {
    visible: !root.embedded && root.total === 0
    text: I18n.tr("System is up to date")
    textColor: Theme.foregroundAlt
  }

  // A card: the empty state centred, and the lists kept at the top
  Item {
    visible: root.embedded
    Layout.fillWidth: true
    Layout.fillHeight: true
    EmptyState {
      visible: root.total === 0
      anchors.centerIn: parent
      icon: "check"
      text: UpdatesManager.checking ? I18n.tr("checking…") : I18n.tr("System is up to date")
    }
  }
}
