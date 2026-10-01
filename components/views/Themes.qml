pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms
import qs.components.content
import qs.components.content.base

// The Themes page, in the editors' shape: the theme list on the left; the
// wallpapers beside the current palette and a few look settings. The
// pieces are the ordinary ThemePicker, WallpaperPicker and Palette
// modules, so they can go on any page too. A view type with nothing to
// configure.
BaseView {
  id: root

  // The wallpapers are one card wide, as tall as the page
  readonly property real wallpaperWidth: root.grid.unit * 0.9
  readonly property real columnWidth: root.editorWidth - root.wallpaperWidth - OverlayConfig.cardSpacing

  Item {
    implicitWidth: root.sideWidth
    implicitHeight: root.pageHeight

    ThemePicker {
      slotRect: [0, 0, 4, 8]
    }
  }

  Item {
    implicitWidth: root.wallpaperWidth
    implicitHeight: root.pageHeight

    WallpaperPicker {
      slotRect: [0, 0, 4, 8]
    }
  }

  ColumnLayout {
    Layout.preferredWidth: root.columnWidth
    Layout.preferredHeight: root.pageHeight
    spacing: OverlayConfig.cardSpacing

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.grid.span(4)

      Palette {
        slotRect: [0, 0, 8, 4]
      }
    }

    // Settings that change the look as much as the theme does; the rest
    // are in Settings
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      TitledCard {
        title: I18n.tr("Look")
        showActions: false

        SettingRows {
          Layout.fillWidth: true
          paths: ["Appearance.font.family", "Appearance.font.size", "Appearance.shape.radius", "Appearance.motion.enabled"]
        }

        StyledTextButton {
          Layout.alignment: Qt.AlignRight
          text: I18n.tr("More in Look & Feel")
          iconText: "chevron_right"
          iconAfter: true
          onClicked: SettingsManager.openSection("Appearance")
        }
      }
    }
  }
}
