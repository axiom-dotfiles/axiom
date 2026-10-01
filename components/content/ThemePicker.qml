pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content.parts
import qs.components.content.base

// The theme list: one tile per theme (a dark/light pair is one theme),
// stock and generated, each painted in its own colors, plus the Dark/Light
// switch that picks the variant and Auto, which switches it by time of day
// (WallpaperManager). Themes apply immediately, so there's nothing to save.
// Compact, the current theme's name; a click switches Dark/Light.
TitledCard {
  id: root

  readonly property var family: ThemeManager.currentFamily
  readonly property bool hasDark: !!root.family?.dark
  readonly property bool hasLight: !!root.family?.light
  // Rebuilt only when the theme folders are rescanned
  readonly property var stockFamilies: ThemeManager.themeFamilies.filter(family => !family.generated)
  readonly property var generatedFamilies: ThemeManager.themeFamilies.filter(family => family.generated)
  // As many tiles across as fit
  readonly property int tileColumns: Math.max(1, Math.floor((root.width - Widget.padding * 2) / (Appearance.fontSize * 13)))

  fullMinWidth: Appearance.fontSize * 14
  fullMinHeight: Appearance.fontSize * 14

  compactContent: Item {
    CompactFigure {
      anchors.fill: parent
      icon: Appearance.darkMode ? "dark_mode" : "light_mode"
      label: root.family?.label ?? I18n.tr("Theme")
    }
    MouseArea {
      anchors.fill: parent
      enabled: root.hasDark && root.hasLight
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: ThemeManager.setLightMode(Appearance.darkMode)
    }
  }

  title: I18n.tr("Theme")
  showActions: false

  headerExtras: [
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Widget.spacing
      spacing: Widget.spacing / 2

      SegmentButton {
        text: I18n.tr("Dark")
        active: Appearance.darkMode
        available: root.hasDark
        onClicked: ThemeManager.setLightMode(false)
      }

      SegmentButton {
        text: I18n.tr("Light")
        active: !Appearance.darkMode
        available: root.hasLight
        onClicked: ThemeManager.setLightMode(true)
      }

      // A switch of its own: picking Dark or Light by hand lasts until the
      // schedule's next change
      SegmentButton {
        Layout.fillWidth: false
        iconText: "schedule"
        text: I18n.tr("Auto")
        active: Appearance.themeScheduled
        onClicked: SettingsManager.commitValues({
          "Appearance.themeSchedule.enabled": !Appearance.themeScheduled
        })
      }
    },
    RowLayout {
      visible: Appearance.themeScheduled
      Layout.fillWidth: true
      spacing: Widget.spacing

      SettingRows {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        paths: ["Appearance.themeSchedule.lightAt"]
      }

      SettingRows {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        paths: ["Appearance.themeSchedule.darkAt"]
      }
    },
    StyledText {
      visible: root.family !== null && !(root.hasDark && root.hasLight)
      Layout.fillWidth: true
      text: root.hasDark ? I18n.tr("This theme has no light variant.") : I18n.tr("This theme has no dark variant.")
      opacity: 0.6
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
    }
  ]

  // A theme painted in the variant the current mode would apply: its
  // background, name in its foreground, and a strip of its accent colors
  component ThemeTile: Rectangle {
    id: tile
    required property var modelData
    readonly property var preview: (Appearance.darkMode ? (modelData.darkPreview ?? modelData.lightPreview) : (modelData.lightPreview ?? modelData.darkPreview)) ?? ({})
    readonly property bool current: root.family !== null && (root.family.dark || root.family.light) === (modelData.dark || modelData.light)

    Layout.fillWidth: true
    Layout.preferredHeight: tileColumn.implicitHeight + Widget.padding * 2
    radius: Widget.radius
    color: preview.background ?? Theme.backgroundAlt
    border.width: current ? Appearance.borderWidth * 2 + 1 : Appearance.borderWidth + 1
    border.color: current ? Theme.accent : tileArea.containsMouse ? Qt.alpha(Theme.foreground, 0.5) : Qt.alpha(Theme.border, 0.6)

    Behavior on border.color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }

    ColumnLayout {
      id: tileColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      RowLayout {
        Layout.fillWidth: true
        spacing: Widget.spacing / 2

        StyledText {
          Layout.fillWidth: true
          text: tile.modelData.label
          textColor: tile.preview.foreground ?? Theme.foreground
          font.bold: true
          elide: Text.ElideRight
        }

        // Has both variants
        StyledIcon {
          visible: !!tile.modelData.dark && !!tile.modelData.light
          text: "contrast"
          textColor: tile.preview.foreground ?? Theme.foreground
          opacity: 0.6
        }

        StyledIcon {
          visible: tile.current
          text: "check"
          textColor: tile.preview.accent ?? Theme.accent
          font.bold: true
        }
      }

      Row {
        spacing: 4

        Repeater {
          model: tile.preview.colors ?? []

          delegate: Rectangle {
            required property string modelData
            width: 12
            height: 12
            radius: 6
            color: modelData
          }
        }
      }
    }

    MouseArea {
      id: tileArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ThemeManager.applyFamily(tile.modelData)
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    SectionHeading {
      title: I18n.tr("Themes")
    }

    GridLayout {
      Layout.fillWidth: true
      columns: root.tileColumns
      columnSpacing: Widget.spacing
      rowSpacing: Widget.spacing

      Repeater {
        model: root.stockFamilies
        delegate: ThemeTile {}
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    SectionHeading {
      title: I18n.tr("Generated Themes")
      description: ThemeManager.isGenerating ? I18n.tr("Generating from the wallpaper...") : I18n.tr("Made from your wallpaper when you pick one.")
    }

    GridLayout {
      Layout.fillWidth: true
      columns: root.tileColumns
      columnSpacing: Widget.spacing
      rowSpacing: Widget.spacing

      Repeater {
        model: root.generatedFamilies
        delegate: ThemeTile {}
      }
    }

    StyledText {
      visible: root.generatedFamilies.length === 0
      text: I18n.tr("None yet")
      opacity: 0.6
    }
  }
}
