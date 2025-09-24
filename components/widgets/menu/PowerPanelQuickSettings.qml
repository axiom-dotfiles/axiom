pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods

Rectangle {
  id: root

  color: Colors.surfaceAlt
  radius: Settings.borderRadius

  // Top separator
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Settings.borderWidth
    color: Colors.border
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: Settings.widgetPadding
    spacing: Settings.widgetSpacing

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
    Layout.preferredWidth: Settings.widgetHeight
    Layout.preferredHeight: Settings.widgetHeight

    contentItem: Text {
      text: parent.iconText
      font.family: Settings.fontFamily
      font.pixelSize: Settings.fontSize + 2
      color: Colors.textPrimary
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
      color: parent.hovered ? Colors.surfaceAlt2 : "transparent"
      radius: Settings.borderRadius

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
      font.family: Settings.fontFamily
      font.pixelSize: Settings.fontSize - 4
      background: Rectangle {
        color: Colors.surface
        border.color: Colors.border
        border.width: 1
        radius: Settings.borderRadius
      }
      contentItem: Text {
        text: parent.text
        font: parent.font
        color: Colors.textPrimary
      }
    }
  }
}
