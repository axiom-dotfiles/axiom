pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.parts
import qs.components.content.base

// The primary connection (name, IP, wifi signal), live throughput with a
// graph, and Tailscale's state when it's installed.
Card {
  id: root

  readonly property var info: NetworkingManager.netInfo
  readonly property string kindIcon: root.info.kind === "wifi" ? "signal_wifi_4_bar" : root.info.kind === "ethernet" ? "lan" : "dns"
  // "Running 100.x.y.z", or "" when Tailscale isn't installed
  readonly property string tailscale: TailscaleManager.available ? (TailscaleManager.backendState + " " + TailscaleManager.ip).trim() : ""

  function rate(bytes) {
    const units = ["B/s", "KB/s", "MB/s", "GB/s"];
    let i = 0;
    while (bytes >= 1024 && i < units.length - 1) {
      bytes /= 1024;
      i++;
    }
    return `${bytes < 10 && i > 0 ? bytes.toFixed(1) : Math.round(bytes)} ${units[i]}`;
  }

  Component.onCompleted: {
    NetworkingManager.refreshIp();
    SystemManager.acquire(root, {
      "metrics": ["net"],
      "history": true,
      "interval": 1000
    });
    TailscaleManager.acquire(root, {
      "interval": 30000
    });
  }
  Component.onDestruction: {
    SystemManager.release(root);
    TailscaleManager.release(root);
  }

  // Compact: the connection type, name and download rate
  CompactFigure {
    visible: root.compact
    anchors.centerIn: parent
    maxWidth: root.width - root.pad * 2
    icon: root.kindIcon
    value: ""
    label: root.info.name || I18n.tr("Disconnected")
  }

  Row {
    visible: root.compact
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.pad
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 2
    opacity: 0.8
    StyledIcon {
      anchors.verticalCenter: parent.verticalCenter
      text: "arrow_downward"
      textSize: Appearance.fontSize - 2
    }
    StyledText {
      anchors.verticalCenter: parent.verticalCenter
      text: root.rate(SystemManager.netRx)
      textSize: Appearance.fontSize - 2
    }
  }

  ColumnLayout {
    visible: !root.compact
    anchors.fill: parent
    anchors.margins: root.pad
    spacing: Widget.spacing / 2

    ModuleHeader {
      icon: root.kindIcon
      title: root.info.name || I18n.tr("Disconnected")
      StyledText {
        visible: root.info.kind === "wifi"
        text: `${root.info.signal}%`
        textSize: Appearance.fontSize - 2
        opacity: 0.7
      }
    }
    // Address and Tailscale on one line where there's room
    Flow {
      Layout.fillWidth: true
      spacing: Widget.spacing * 1.5
      StyledText {
        visible: root.info.ip !== ""
        text: root.info.ip
        textSize: Appearance.fontSize - 2
        opacity: 0.7
      }
      StyledText {
        visible: root.tailscale !== ""
        width: Math.min(implicitWidth, parent.width)
        elide: Text.ElideRight
        text: I18n.tr("Tailscale · {0}", root.tailscale)
        textSize: Appearance.fontSize - 2
        textColor: root.tailscale.startsWith("Running") ? Theme.success : Theme.foreground
        opacity: 0.8
      }
    }

    // Download and upload, one graph over the other
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: Widget.spacing / 2
      Sparkline {
        anchors.fill: parent
        values: SystemManager.netRxHistory
        maxValue: 0
        lineColor: Theme.accentAlt
        capacity: SystemManager.historyLength
      }
      Sparkline {
        anchors.fill: parent
        values: SystemManager.netTxHistory
        maxValue: 0
        lineColor: Theme.accent
        fillOpacity: 0.08
        lineWidth: 1.5
        showBaseline: false
        capacity: SystemManager.historyLength
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Row {
        spacing: 2
        StyledIcon {
          anchors.verticalCenter: parent.verticalCenter
          text: "arrow_downward"
          textColor: Theme.accentAlt
          textSize: Appearance.fontSize - 1
        }
        StyledText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rate(SystemManager.netRx)
          textColor: Theme.accentAlt
          textSize: Appearance.fontSize - 1
        }
      }
      Item {
        Layout.fillWidth: true
      }
      Row {
        spacing: 2
        StyledIcon {
          anchors.verticalCenter: parent.verticalCenter
          text: "arrow_upward"
          textColor: Theme.accent
          textSize: Appearance.fontSize - 1
        }
        StyledText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rate(SystemManager.netTx)
          textColor: Theme.accent
          textSize: Appearance.fontSize - 1
        }
      }
    }
  }
}
