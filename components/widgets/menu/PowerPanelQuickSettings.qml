pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods

Rectangle {
  id: root

  color: Theme.backgroundAlt
  radius: Appearance.borderRadius

  // Top separator
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Appearance.borderWidth
    color: Theme.border
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: Widget.spacing

    // Application launchers with Nerd Font icons
    QuickLaunchButton {
      iconText: "󰖩"  // WiFi/Network icon
      tooltip: "Network Manager"
      onClicked: Utils.launch("nm-connection-editor")
    }

    QuickLaunchButton {
      iconText: "󰂯"  // Bluetooth icon
      tooltip: "Bluetooth Manager"
      onClicked: Utils.launch("blueberry")
    }

    QuickLaunchButton {
      iconText: "󰃣"  // Theme/Appearance icon
      tooltip: "Appearance Settings"
      onClicked: Utils.launch("nwg-look")
    }

    QuickLaunchButton {
      iconText: "󰕾"  // Volume/Audio icon
      tooltip: "Audio Control"
      onClicked: Utils.launch("pavucontrol")
    }

    // Spacer
    Item {
      Layout.fillWidth: true
    }

    // Additional system toggles can be added here
  }

  // Component for quick launch buttons using text icons
  component QuickLaunchButton: ToolButton {
    id: btn
    property string tooltip: ""
    property string iconText: ""
    Layout.preferredWidth: Widget.height
    Layout.preferredHeight: Widget.height

    contentItem: Text {
      text: parent.iconText
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize + 2
      color: Theme.foreground
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
      color: parent.hovered ? Theme.backgroundHighlight : "transparent"
      radius: Appearance.borderRadius

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
    }

    ToolTip {
      visible: parent.hovered && parent.tooltip !== ""
      text: parent.tooltip
      delay: 500
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize - 4
      background: Rectangle {
        color: Theme.backgroundAlt
        border.color: Theme.border
        border.width: 1
        radius: Appearance.borderRadius
      }
      // contentItem: Text {
      //   text: parent.text
      //   font: parent.font
      //   color: Theme.foreground
      // }
    }
  }
}
