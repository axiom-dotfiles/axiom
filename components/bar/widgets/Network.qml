pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout

// The primary connection's kind and device. Hovering opens the Wi-Fi
// menu, middle click runs a command.
BarIconWidget {
  id: root

  readonly property string iface: NetworkingManager.netInfo.device
  readonly property string kind: NetworkingManager.primaryKind
  readonly property bool connected: kind !== ""

  backgroundColor: Theme.resolveColor(connected ? properties.backgroundColor : properties.disconnectedColor)
  icon: getIcon()
  text: iface
  showText: properties.showName && iface !== ""

  function getIcon() {
    switch (kind) {
    case "wifi":
      return "wifi";
    case "ethernet":
      return "lan";
    default:
      return NetworkingManager.available && !NetworkingManager.wifiEnabled ? "signal_wifi_0_bar" : "signal_wifi_off";
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.properties.middleCommand !== ""
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.MiddleButton
    onClicked: Quickshell.execDetached(["sh", "-c", root.properties.middleCommand])
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "WifiNetworks"
    active: root.properties.showPopout
  }
}
