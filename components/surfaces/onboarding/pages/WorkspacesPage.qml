pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.forms

// How workspaces are laid out (the Workspaces section), with a small
// picture of two monitors in the chosen layout
OnboardingPage {
  id: root

  readonly property string layout: WorkspacesConfig.layout

  title: I18n.tr("Workspaces")
  intro: I18n.tr("Workspaces are the desktops you switch between with Super + a number. The bar, the overview and the keybinds all follow the layout you pick here.")

  Repeater {
    model: [
      {
        "layout": "perMonitor",
        "icon": "view_week",
        "title": I18n.tr("Per monitor"),
        "description": I18n.tr("Each monitor has its own workspaces 1 to N. Super + 3 goes to workspace 3 of the monitor you're on.")
      },
      {
        "layout": "standard",
        "icon": "view_column",
        "title": I18n.tr("Standard"),
        "description": I18n.tr("One set of workspaces, 1 to N, shared by every monitor, as Hyprland does by default.")
      },
      {
        "layout": "grid",
        "icon": "grid_view",
        "title": I18n.tr("Grid"),
        "description": I18n.tr("Each monitor has a grid of workspaces, and you move up, down, left and right between them.")
      }
    ]

    delegate: OptionCard {
      required property var modelData
      icon: modelData.icon
      title: modelData.title
      description: modelData.description
      selected: root.layout === modelData.layout
      recommended: modelData.layout === "perMonitor"
      onClicked: SettingsManager.commitValues({
        "Workspaces.layout": modelData.layout
      })
    }
  }

  // Two monitors in the chosen layout
  Row {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Widget.spacing
    spacing: Widget.spacing * 2

    Repeater {
      model: 2

      delegate: Rectangle {
        id: monitor
        required property int index
        readonly property int columns: root.layout === "grid" ? WorkspacesConfig.columns : Math.min(WorkspacesConfig.count, 5)
        readonly property int rows: root.layout === "grid" ? WorkspacesConfig.rows : 1
        width: root.cardWidth * 0.36
        height: width * 0.6
        radius: Widget.radius / 2
        color: Theme.backgroundAlt
        border.color: Theme.border
        border.width: Appearance.borderWidth

        Grid {
          anchors.centerIn: parent
          columns: monitor.columns
          spacing: 3

          Repeater {
            model: monitor.columns * monitor.rows

            delegate: Rectangle {
              required property int index
              // Shared ids: each monitor shows a different one of them
              readonly property bool active: index === (root.layout === "standard" ? monitor.index : 0)
              width: Math.min((monitor.width - 16) / monitor.columns - 3, (monitor.height - 16) / monitor.rows - 3)
              height: width
              radius: 3
              color: active ? Theme.accent : Theme.backgroundHighlight

              StyledText {
                anchors.centerIn: parent
                visible: root.layout !== "grid" && parent.width > Appearance.fontSize
                text: String(parent.index + 1)
                textSize: Math.max(8, parent.width * 0.45)
                textColor: parent.active ? Theme.background : Theme.foreground
              }
            }
          }
        }
      }
    }
  }

  SettingRows {
    Layout.fillWidth: true
    paths: ["Workspaces.count", "Workspaces.columns", "Workspaces.rows", "Workspaces.wrap"]
  }
}
