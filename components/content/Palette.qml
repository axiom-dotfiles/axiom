pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts

// The current theme's 16 base colors, each a tile with its key, hex value
// and the UI roles it plays (Theme.roles) beneath: the neutrals in the
// first row, the accents in the second where it's wide enough. Compact, a
// strip of the 16.
Card {
  id: root

  // Eight chips across where they have room, else four or two
  readonly property int columns: root.innerWidth >= Appearance.fontSize * 56 ? 8 : root.innerWidth >= Appearance.fontSize * 24 ? 4 : 2

  // Every chip keeps room for the most roles any color plays, so the
  // tiles line up
  readonly property int roleLines: Math.max(1, ...Object.keys(Theme.roles).map(key => Theme.roles[key].length))

  fullMinWidth: Appearance.fontSize * 14
  fullMinHeight: Appearance.fontSize * 12

  // One color: a tile of it, then its key, hex value and roles beneath in
  // the theme's own text colors, so they read whatever the color
  component Chip: ColumnLayout {
    id: chip
    required property string modelData
    readonly property color value: Theme.resolveColor(chip.modelData)
    readonly property var roles: Theme.roles[chip.modelData] ?? []

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 1
    spacing: 2

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: Appearance.fontSize * 1.5
      radius: Widget.radius
      color: chip.value
      border.width: Appearance.borderWidth
      border.color: Qt.alpha(Theme.border, 0.6)
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 2
      spacing: Widget.spacing / 2

      StyledText {
        text: chip.modelData
        textSize: Appearance.fontSize - 2
        font.bold: true
      }

      StyledText {
        Layout.fillWidth: true
        text: chip.value.toString().toUpperCase()
        textSize: Appearance.fontSize - 3
        opacity: 0.6
        elide: Text.ElideRight
      }
    }

    // Padded to roleLines; long role names break rather than hide
    StyledText {
      Layout.fillWidth: true
      text: chip.roles.concat(Array(Math.max(0, root.roleLines - chip.roles.length)).fill("")).join("\n")
      textColor: Theme.accent
      textSize: Appearance.fontSize - 3
      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
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
