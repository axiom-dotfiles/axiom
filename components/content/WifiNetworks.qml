pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts

// Wi-Fi menu for the Network widget: radio switch, the current connection
// (address and throughput), and the networks in range (scanning while
// shown). Click a network to connect or disconnect; a secured new one asks
// for its password inline, and saved ones can be forgotten on hover. The
// popout keeps one size and rows keep their order, as in BluetoothDevices.
Panel {
  id: root

  readonly property var info: NetworkingManager.netInfo
  readonly property var networks: NetworkingManager.networks
  readonly property bool radioOn: NetworkingManager.wifiEnabled && NetworkingManager.available
  readonly property string offMessage: I18n.tr(!NetworkingManager.available ? "No Wi-Fi adapter found" : NetworkingManager.hardwareBlocked ? "Wi-Fi is blocked (rfkill)" : "Wi-Fi is off")
  readonly property string kindIcon: info.kind === "wifi" ? NetworkingManager.signalIcon(info.signal / 100) : info.kind === "ethernet" ? "lan" : "signal_wifi_0_bar"

  // A password field is up: keep the keyboard, and the popout open
  wantsKeyboardFocus: NetworkingManager.passwordFor !== null
  hovered: pointerInside || wantsKeyboardFocus
  onFocusLost: NetworkingManager.cancelPassword()

  margins: 16
  implicitWidth: 380
  // A popout's list is a fixed six rows high
  readonly property real rowHeight: Math.max(titleMetrics.height + statusMetrics.height, 28) + Widget.spacing * 2
  readonly property real listHeight: rowHeight * 6 + list.spacing * 5

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
    NetworkingManager.acquireScan(root);
    NetworkingManager.refreshIp();
    SystemManager.acquire(root, {
      "metrics": ["net"],
      "interval": 2000
    });
  }
  Component.onDestruction: {
    NetworkingManager.releaseScan(root);
    NetworkingManager.cancelPassword();
    SystemManager.release(root);
  }

  FontMetrics {
    id: titleMetrics
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 1
  }
  FontMetrics {
    id: statusMetrics
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize - 3
  }

  compactContent: CompactFigure {
    icon: root.radioOn ? root.kindIcon : "signal_wifi_0_bar"
    iconColor: root.info.kind !== "" ? Theme.accent : Theme.foregroundAlt
    value: ""
    label: root.info.name || I18n.tr(root.radioOn ? "Disconnected" : "off")
  }

  component NetworkRow: Rectangle {
    id: row
    required property int index
    readonly property var network: root.networks[index] ?? null
    readonly property bool connected: network?.connected ?? false
    readonly property bool known: network?.known ?? false
    readonly property bool busy: network?.stateChanging ?? false
    readonly property bool asking: network !== null && NetworkingManager.passwordFor === network
    readonly property bool failed: NetworkingManager.failed(network)
    // Forgetting takes a second click, within a few seconds
    property bool confirmForget: false

    Layout.fillWidth: true
    implicitHeight: root.rowHeight + (asking ? passwordRow.implicitHeight + Widget.spacing : 0)
    radius: Appearance.borderRadius
    color: connected || asking ? Theme.backgroundHighlight : rowHover.hovered ? Qt.rgba(Theme.backgroundHighlight.r, Theme.backgroundHighlight.g, Theme.backgroundHighlight.b, 0.5) : "transparent"
    clip: true

    onNetworkChanged: confirmForget = false
    onAskingChanged: {
      passwordField.text = "";
      if (asking)
        Qt.callLater(() => passwordField.input.forceActiveFocus());
    }

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
    Behavior on implicitHeight {
      NumberAnimation {
        duration: Appearance.animFast
      }
    }

    HoverHandler {
      id: rowHover
      onHoveredChanged: if (!hovered)
        row.confirmForget = false
    }

    Timer {
      running: row.confirmForget
      interval: 3000
      onTriggered: row.confirmForget = false
    }

    MouseArea {
      width: parent.width
      height: root.rowHeight
      cursorShape: row.busy ? Qt.BusyCursor : Qt.PointingHandCursor
      onClicked: {
        if (row.asking)
          NetworkingManager.cancelPassword();
        else
          NetworkingManager.toggleNetwork(row.network);
      }
    }

    RowLayout {
      height: root.rowHeight
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.spacing
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Widget.padding

      StyledIcon {
        Layout.preferredWidth: 26
        horizontalAlignment: Text.AlignHCenter
        text: NetworkingManager.signalIcon(row.network?.signalStrength ?? 0)
        textSize: Appearance.fontSize * 1.4
        textColor: row.connected ? Theme.accent : Theme.foregroundAlt
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing / 2

          StyledText {
            Layout.fillWidth: true
            text: row.network?.name ?? ""
            elide: Text.ElideRight
            textSize: Appearance.fontSize - 1
            textColor: row.connected ? Theme.foreground : Theme.foregroundAlt
          }
          StyledIcon {
            visible: NetworkingManager.isSecure(row.network)
            text: "lock"
            textSize: Appearance.fontSize - 3
            textColor: Theme.foregroundAlt
          }
        }
        StyledText {
          Layout.fillWidth: true
          text: row.confirmForget ? I18n.tr("Click again to forget") : NetworkingManager.networkStatus(row.network)
          elide: Text.ElideRight
          textSize: Appearance.fontSize - 3
          textColor: row.confirmForget || row.failed ? Theme.error : row.busy || row.connected ? Theme.accent : Theme.foregroundAlt
        }
      }

      // Only on hover, but always laid out so showing it moves nothing
      StyledRectButton {
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        visible: row.known
        enabled: rowHover.hovered && !row.busy
        opacity: rowHover.hovered || row.confirmForget ? 1 : 0
        iconText: "delete"
        iconColor: Theme.error
        backgroundColor: row.confirmForget ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
        borderHoverColor: Theme.error
        tooltipText: I18n.tr("Forget")
        onClicked: {
          if (row.confirmForget)
            NetworkingManager.forget(row.network);
          row.confirmForget = !row.confirmForget;
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Appearance.animFast
          }
        }
      }

      StyledRectButton {
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        enabled: !row.busy
        opacity: enabled ? 1 : 0.5
        iconText: row.connected ? "link_off" : "link"
        iconColor: row.connected ? Theme.accent : Theme.foreground
        backgroundColor: "transparent"
        borderHoverColor: Theme.accent
        tooltipText: I18n.tr(row.connected ? "Disconnect" : "Connect")
        onClicked: NetworkingManager.toggleNetwork(row.network)
      }
    }

    // The password, for a secured network not saved yet
    RowLayout {
      id: passwordRow
      visible: row.asking
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: root.rowHeight
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.spacing
      spacing: Widget.spacing

      StyledTextEntry {
        id: passwordField
        Layout.fillWidth: true
        placeholderText: I18n.tr("Password")
        input.echoMode: TextInput.Password
        input.wrapMode: Text.NoWrap
        onAccepted: NetworkingManager.connectWithPsk(row.network, passwordField.text)
        // The field leaves Escape to its parents
        Keys.onEscapePressed: NetworkingManager.cancelPassword()
      }

      StyledRectButton {
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        enabled: passwordField.text !== ""
        opacity: enabled ? 1 : 0.5
        iconText: "link"
        iconColor: Theme.accent
        backgroundColor: "transparent"
        borderHoverColor: Theme.accent
        tooltipText: I18n.tr("Connect")
        onClicked: NetworkingManager.connectWithPsk(row.network, passwordField.text)
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    spacing: Widget.spacing

    StyledText {
      Layout.fillWidth: true
      text: I18n.tr("Wi-Fi")
      elide: Text.ElideRight
      font.bold: true
      textColor: Theme.accent
    }

    // Spins while scanning; always laid out, so the header never shifts
    StyledIcon {
      text: "refresh"
      textColor: Theme.foregroundAlt
      opacity: NetworkingManager.scanning ? 1 : 0

      RotationAnimation on rotation {
        running: NetworkingManager.scanning && Appearance.animations
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: Appearance.animSlow * 4
      }

      Behavior on opacity {
        NumberAnimation {
          duration: Appearance.animFast
        }
      }
    }

    StyledSwitch {
      enabled: NetworkingManager.available && !NetworkingManager.hardwareBlocked
      checked: NetworkingManager.wifiEnabled
      onToggled: NetworkingManager.setWifiEnabled(checked)
    }
  }

  // The primary connection (wired or wireless): address and throughput
  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    spacing: Widget.padding

    StyledIcon {
      Layout.preferredWidth: 26
      horizontalAlignment: Text.AlignHCenter
      text: root.kindIcon
      textSize: Appearance.fontSize * 1.4
      textColor: root.info.kind !== "" ? Theme.accent : Theme.foregroundAlt
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: root.info.name || I18n.tr("Disconnected")
        elide: Text.ElideRight
        textSize: Appearance.fontSize - 1
      }
      StyledText {
        Layout.fillWidth: true
        visible: root.info.kind !== ""
        text: root.info.ip !== "" ? `${root.info.ip} · ${root.info.device}` : root.info.device
        elide: Text.ElideRight
        textSize: Appearance.fontSize - 3
        textColor: Theme.foregroundAlt
      }
    }

    ColumnLayout {
      visible: root.info.kind !== ""
      spacing: 0

      Row {
        Layout.alignment: Qt.AlignRight
        spacing: 2
        StyledIcon {
          anchors.verticalCenter: parent.verticalCenter
          text: "arrow_downward"
          textSize: Appearance.fontSize - 3
          textColor: Theme.accentAlt
        }
        StyledText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rate(SystemManager.netRx)
          textSize: Appearance.fontSize - 3
          textColor: Theme.accentAlt
        }
      }
      Row {
        Layout.alignment: Qt.AlignRight
        spacing: 2
        StyledIcon {
          anchors.verticalCenter: parent.verticalCenter
          text: "arrow_upward"
          textSize: Appearance.fontSize - 3
          textColor: Theme.accent
        }
        StyledText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rate(SystemManager.netTx)
          textSize: Appearance.fontSize - 3
          textColor: Theme.accent
        }
      }
    }
  }

  StyledSeparator {
    Layout.fillWidth: true
    separatorColor: Theme.backgroundHighlight
  }

  // Off: the message fills the list's place, keeping the popout's size
  Item {
    visible: !root.radioOn
    Layout.fillWidth: true
    Layout.preferredHeight: root.embedded ? -1 : root.listHeight
    Layout.fillHeight: root.embedded

    EmptyState {
      anchors.centerIn: parent
      maxWidth: parent.width
      icon: "signal_wifi_0_bar"
      text: root.offMessage
    }
  }

  StyledScrollView {
    id: scroll
    visible: root.radioOn
    Layout.fillWidth: true
    Layout.preferredHeight: root.embedded ? -1 : root.listHeight
    Layout.fillHeight: root.embedded
    contentPadding: 0
    showScrollBar: list.implicitHeight > scroll.height

    ColumnLayout {
      id: list
      width: scroll.availableWidth
      spacing: 2

      // Modelled by count, so rows survive network changes (a scan or a
      // connect re-evaluates the list) instead of being rebuilt
      Repeater {
        model: root.networks.length

        NetworkRow {}
      }

      StyledText {
        Layout.fillWidth: true
        Layout.preferredHeight: scroll.availableHeight
        visible: root.networks.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: I18n.tr("Looking for networks…")
        textColor: Theme.foregroundAlt
      }
    }
  }
}
