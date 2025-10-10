pragma ComponentBehavior: Bound

import qs.config
import qs.components.reusable

IconTextWidget {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  property string iface: ""
  property string kind: ""

  isVertical: barConfig.vertical

  // Configure the widget
  backgroundColor: Theme.base09
  icon: getIcon()
  text: iface

  function getIcon() {
    switch (kind) {
    case "wifi":
      return "";
    case "ethernet":
      return "󰈀";
    default:
      return "󰤭";
    }
  }

  PollingProcess {
    interval: 2000
    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$3==\"connected\"{print $1\":\"$2; exit}'"]

    onDataReceived: data => {
      const parts = data.split(":");
      // root.iface = parts[0] || "";
      root.kind = parts[1] || "";
    }
  }
}
