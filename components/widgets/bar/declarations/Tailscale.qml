pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config
import qs.components.reusable

IconTextWidget {
  id: root

  property bool isConnected: false
  property string tailnetName: ""
  property bool showText: true

  icon: isConnected ? "󰳌" : "󰌙"
  // text: isConnected ? tailnetName : ""
  text: isConnected ? "k8s" : ""

  backgroundColor: isConnected ? Theme.warning : Theme.backgroundHighlight

  maxTextLength: 15

  iconScale: 1.1
  textScale: 0.9

  PollingProcess {
    id: statusChecker
    interval: 250
    command: ["sh", "-c", "tailscale status &>/dev/null"]
    treatExitCodeAsStatus: true

    onStatusChanged: (exitCode, stdout, stderr) => {
      root.isConnected = (exitCode === 0);

      // If connected, get the tailnet name
      if (root.isConnected) {
        tailnetChecker.refresh();
      } else {
        root.tailnetName = "";
      }
    }
  }

  PollingProcess {
    id: tailnetChecker
    interval: 5000
    command: ["sh", "-c", "tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.Name // empty' 2>/dev/null"]
    autoStart: false

    onDataReceived: data => {
      let name = data.trim().replace(/^["']|["']$/g, '');
      root.tailnetName = name || "";
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      Notify.send("Tailscale", root.isConnected ? "Connected to: " + root.tailnetName : "Disconnected");
    }
  }
}
