pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.config
import qs.services
import qs.components.reusable
import qs.components.content
import qs.components.forms

// The look: the wallpaper folder, bar style and screen border here, with the Themes
// page's wallpaper picker and theme list beside it
OnboardingPage {
  id: root

  property var screen

  cardWidth: root.grid ? root.grid.unit * 1.5 : 0
  title: I18n.tr("Look")
  intro: I18n.tr("Pick a wallpaper and a theme. Themes can also be generated from a wallpaper: pick one, and a matching light and dark theme appear in the list.")

  // --- Wallpaper folder ---

  readonly property string folder: Appearance.wallpaperFolder
  readonly property string folderPath: root.folder.replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
  // Images in the folder: -1 while checking, -2 when it doesn't exist
  property int imageCount: -1
  readonly property string hyprlandWallpapers: "/usr/share/hypr"
  property bool hasHyprlandWallpapers: false

  function checkFolder() {
    folderCheck.running = false;
    folderCheck.running = true;
  }
  onFolderChanged: checkFolder()
  Component.onCompleted: checkFolder()

  Process {
    id: folderCheck
    command: ["sh", "-c", '[ -d "$1" ] || { echo -2; exit; }; find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \\) | wc -l; ls "$2"/wall*.png >/dev/null 2>&1 && echo hypr', "sh", root.folderPath, root.hyprlandWallpapers]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n").filter(line => line !== "");
        root.imageCount = parseInt(lines[0] ?? "-1");
        root.hasHyprlandWallpapers = lines.includes("hypr");
      }
    }
  }

  SettingRows {
    Layout.fillWidth: true
    paths: ["Appearance.wallpaperFolder"]
  }

  Notice {
    visible: root.imageCount === -2 || root.imageCount === 0
    tone: "warning"
    text: root.imageCount === -2 ? I18n.tr("That folder doesn't exist yet. Create it and put some images in it, or use Hyprland's wallpapers for now.") : I18n.tr("That folder has no images (jpg, png or bmp) yet.")
  }

  RowLayout {
    visible: root.imageCount === -2 || root.imageCount === 0
    spacing: Widget.spacing

    StyledTextButton {
      visible: root.imageCount === -2
      text: I18n.tr("Create it")
      iconText: "create_new_folder"
      onClicked: {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", root.folderPath]);
        recheck.restart();
      }
    }

    StyledTextButton {
      visible: root.imageCount === 0
      text: I18n.tr("Open it")
      iconText: "folder_open"
      onClicked: Quickshell.execDetached(["xdg-open", root.folderPath])
    }

    StyledTextButton {
      visible: root.hasHyprlandWallpapers
      text: I18n.tr("Use Hyprland's wallpapers")
      iconText: "wallpaper"
      onClicked: OnboardingManager.set({
        "Appearance.wallpaperFolder": root.hyprlandWallpapers
      })
    }

    StyledTextButton {
      text: I18n.tr("Check again")
      iconText: "refresh"
      onClicked: root.checkFolder()
    }
  }

  Timer {
    id: recheck
    interval: 1000
    onTriggered: root.checkFolder()
  }

  // --- Bar ---

  // As saved (Bar.bars turns `location` into an edge enum)
  readonly property var bar: Bar.savedBars?.[0] ?? null

  function setBar(key, value) {
    const values = {};
    values["Bars.0." + key] = value;
    OnboardingManager.set(values);
  }

  StyledText {
    Layout.topMargin: Widget.spacing
    visible: root.bar !== null
    text: I18n.tr("Bar")
    font.bold: true
  }

  GridLayout {
    Layout.fillWidth: true
    visible: root.bar !== null
    columns: 1
    columnSpacing: Widget.spacing
    rowSpacing: Widget.spacing

    Repeater {
      model: [
        {
          "value": "pills",
          "icon": "view_agenda",
          "title": I18n.tr("Pills"),
          "description": I18n.tr("A pill per group of widgets")
        },
        {
          "value": "solid",
          "icon": "crop_16_9",
          "title": I18n.tr("Solid"),
          "description": I18n.tr("One bar along the edge")
        },
        {
          "value": "transparent",
          "icon": "blur_on",
          "title": I18n.tr("Transparent"),
          "description": I18n.tr("Widgets on the wallpaper")
        }
      ]

      delegate: OptionCard {
        required property var modelData
        icon: modelData.icon
        title: modelData.title
        description: modelData.description
        selected: root.bar?.background === modelData.value
        onClicked: root.setBar("background", modelData.value)
      }
    }
  }

  RowLayout {
    visible: root.bar !== null
    spacing: Widget.spacing

    StyledText {
      text: I18n.tr("Edge")
    }

    Repeater {
      // I18n.tr("Top") I18n.tr("Bottom") I18n.tr("Left") I18n.tr("Right")
      model: ["Top", "Bottom", "Left", "Right"]

      delegate: StyledTextButton {
        required property string modelData
        text: I18n.tr(modelData)
        backgroundColor: root.bar?.location === modelData ? Theme.accent : Theme.backgroundHighlight
        textColor: root.bar?.location === modelData ? Theme.background : Theme.foreground
        onClicked: root.setBar("location", modelData)
      }
    }
  }

  SettingRows {
    Layout.fillWidth: true
    paths: ["Appearance.shape.screenBorder"]
  }

  StyledText {
    Layout.fillWidth: true
    text: I18n.tr("Widgets are arranged in the overlay's Bar editor.")
    wrapMode: Text.WordWrap
    textColor: Theme.foregroundAlt
  }

  extras: [
    Item {
      implicitWidth: root.grid.span(2)
      implicitHeight: root.grid.span(4)

      WallpaperPicker {
        slotRect: [0, 0, 2, 4]
      }
    },
    Item {
      implicitWidth: root.grid.span(2)
      implicitHeight: root.grid.span(4)

      ThemeEditor {
        slotRect: [0, 0, 2, 4]
      }
    }
  ]
}
