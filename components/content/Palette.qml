pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts

// The current theme's 16 base colors, each with its key, its hex value and
// the UI roles it plays (Theme.roles): the neutrals in the first row, the
// accents in the second where it's wide enough. Compact, a strip of the 16.
Card {
  id: root

  // Eight chips across where they have room, else four or two
  readonly property int columns: root.innerWidth >= Appearance.fontSize * 56 ? 8 : root.innerWidth >= Appearance.fontSize * 24 ? 4 : 2

  fullMinWidth: Appearance.fontSize * 14
  fullMinHeight: Appearance.fontSize * 12

  // One color, its name and value in whichever of the theme's background
  // and foreground reads on it
  component Chip: Rectangle {
    id: chip
    required property string modelData
    readonly property color ink: Utils.inkOn(chip.color, Theme.background, Theme.foreground)

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 1
    radius: Widget.radius
    color: Theme.resolveColor(chip.modelData)
    border.width: Appearance.borderWidth
    border.color: Qt.alpha(Theme.border, 0.6)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Widget.padding / 2 + 2
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: chip.modelData
        textColor: chip.ink
        textSize: Appearance.fontSize - 2
        font.bold: true
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        text: chip.color.toString().toUpperCase()
        textColor: chip.ink
        textSize: Appearance.fontSize - 3
        opacity: 0.75
        elide: Text.ElideRight
      }

      Item {
        Layout.fillHeight: true
      }

      StyledText {
        Layout.fillWidth: true
        text: (Theme.roles[chip.modelData] ?? []).join("\n")
        textColor: chip.ink
        textSize: Appearance.fontSize - 3
        opacity: 0.9
        elide: Text.ElideRight
        maximumLineCount: Math.max(1, Math.floor(chip.height / Appearance.fontSize / 2) - 1)
      }
    }
  }

  compactContent: Row {
    Repeater {
      model: Theme.baseColorNames

      delegate: Rectangle {
        required property string modelData
        width: parent.width / 16
        height: parent.height
        color: Theme.resolveColor(modelData)
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: Widget.spacing

    ModuleHeader {
      icon: "palette"
      title: I18n.tr("Palette")

      StyledText {
        text: Theme.name
        opacity: 0.6
        elide: Text.ElideRight
      }
    }

    GridLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      columns: root.columns
      columnSpacing: Widget.spacing / 2
      rowSpacing: Widget.spacing / 2

      Repeater {
        model: Theme.baseColorNames
        delegate: Chip {}
      }
    }
  }
}
