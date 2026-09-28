pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import qs.services
import qs.config
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts

// Bluetooth menu for the Bluetooth widget: power switch, a Devices tab for
// paired devices (click to connect / disconnect, forget on hover) and a
// Discover tab that scans while it's open and pairs + connects on click.
// The popout keeps one size whatever the tab, the device count or the
// adapter state, and rows keep their order, so nothing moves under the
// pointer.
Panel {
  id: root

  property int currentTab: 0
  // Only stop a scan this popout started
  property bool _startedScan: false

  readonly property var shownDevices: currentTab === 0 ? BluetoothManager.pairedDevices : BluetoothManager.discoveredDevices
  readonly property string offMessage: I18n.tr(!BluetoothManager.available ? "No Bluetooth adapter found" : BluetoothManager.blocked ? "Bluetooth is blocked (rfkill)" : "Bluetooth is off")

  // A popout's list is a fixed five rows high
  readonly property real rowHeight: Math.max(titleMetrics.height + statusMetrics.height, 28) + Widget.spacing * 2
  readonly property real listHeight: rowHeight * 5 + list.spacing * 4

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
    icon: BluetoothManager.enabled ? "bluetooth" : "bluetooth_disabled"
    iconColor: BluetoothManager.connectedDevices.length > 0 ? Theme.accent : Theme.foregroundAlt
    value: BluetoothManager.enabled ? String(BluetoothManager.connectedDevices.length) : ""
    label: BluetoothManager.enabled ? I18n.tr("connected") : I18n.tr("off")
  }

  implicitWidth: 380

  function updateScan() {
    const want = currentTab === 1 && BluetoothManager.enabled;
    if (want && !BluetoothManager.discovering) {
      BluetoothManager.setDiscovering(true);
      _startedScan = true;
    } else if (!want && _startedScan) {
      BluetoothManager.setDiscovering(false);
      _startedScan = false;
    }
  }

  onCurrentTabChanged: {
    updateScan();
    fadeIn.restart();
  }
  Connections {
    target: BluetoothManager
    function onEnabledChanged() {
      root.updateScan();
    }
  }
  Component.onDestruction: {
    if (_startedScan)
      BluetoothManager.setDiscovering(false);
  }

  component DeviceRow: Rectangle {
    id: row
    required property int index
    readonly property var device: root.shownDevices[index] ?? null
    readonly property bool connected: device?.connected ?? false
    readonly property bool known: (device?.paired || device?.bonded) ?? false
    readonly property bool busy: device !== null && (device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting)
    // Forgetting takes a second click, within a few seconds
    property bool confirmForget: false

    Layout.fillWidth: true
    implicitHeight: root.rowHeight
    radius: Appearance.borderRadius
    color: connected ? Theme.backgroundHighlight : rowHover.hovered ? Qt.rgba(Theme.backgroundHighlight.r, Theme.backgroundHighlight.g, Theme.backgroundHighlight.b, 0.5) : "transparent"

    onDeviceChanged: confirmForget = false

    Behavior on color {
      ColorAnimation {
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
      anchors.fill: parent
      cursorShape: row.busy ? Qt.BusyCursor : Qt.PointingHandCursor
      onClicked: BluetoothManager.toggleDevice(row.device)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.spacing
      spacing: Widget.padding

      StyledIcon {
        Layout.preferredWidth: 26
        horizontalAlignment: Text.AlignHCenter
        text: BluetoothManager.deviceIcon(row.device)
        textSize: Appearance.fontSize * 1.4
        textColor: row.connected ? Theme.accent : Theme.foregroundAlt
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: BluetoothManager.deviceLabel(row.device)
          elide: Text.ElideRight
          textSize: Appearance.fontSize - 1
          textColor: row.connected ? Theme.foreground : Theme.foregroundAlt
        }
        StyledText {
          Layout.fillWidth: true
          text: row.confirmForget ? I18n.tr("Click again to forget") : BluetoothManager.deviceStatus(row.device)
          elide: Text.ElideRight
          textSize: Appearance.fontSize - 3
          textColor: row.confirmForget ? Theme.error : row.busy || row.connected ? Theme.accent : Theme.foregroundAlt
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
            BluetoothManager.forget(row.device);
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
        tooltipText: I18n.tr(row.connected ? "Disconnect" : (row.known ? "Connect" : "Pair and connect"))
        onClicked: BluetoothManager.toggleDevice(row.device)
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    spacing: Widget.spacing

    StyledText {
      Layout.fillWidth: true
      text: I18n.tr("Bluetooth")
      elide: Text.ElideRight
      font.bold: true
      textColor: Theme.accent
    }

    // Spins while scanning; always laid out, so the header never shifts
    StyledIcon {
      text: "refresh"
      textColor: Theme.foregroundAlt
      opacity: BluetoothManager.discovering ? 1 : 0

      RotationAnimation on rotation {
        running: BluetoothManager.discovering && Appearance.animations
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
      enabled: BluetoothManager.available && !BluetoothManager.blocked
      checked: BluetoothManager.enabled
      onToggled: BluetoothManager.setEnabled(checked)
    }
  }

  StyledSeparator {
    Layout.fillWidth: true
    separatorColor: Theme.backgroundHighlight
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredHeight: 32
    spacing: Widget.spacing
    uniformCellSizes: true
    enabled: BluetoothManager.enabled
    opacity: enabled ? 1 : 0.5

    Repeater {
      model: [I18n.tr("Devices ({0})", BluetoothManager.pairedDevices.length), I18n.tr("Discover")]

      StyledTabButton {
        required property int index
        required property string modelData
        text: modelData
        checked: root.currentTab === index
        onClicked: root.currentTab = index
      }
    }
  }

  // Off: the message fills the list's place, keeping the popout's size
  Item {
    visible: !BluetoothManager.enabled
    Layout.fillWidth: true
    Layout.preferredHeight: root.embedded ? -1 : root.listHeight
    Layout.fillHeight: root.embedded

    EmptyState {
      anchors.centerIn: parent
      maxWidth: parent.width
      icon: "bluetooth_disabled"
      text: root.offMessage
    }
  }

  StyledScrollView {
    id: scroll
    visible: BluetoothManager.enabled
    Layout.fillWidth: true
    Layout.preferredHeight: root.embedded ? -1 : root.listHeight
    Layout.fillHeight: root.embedded
    contentPadding: 0
    showScrollBar: list.implicitHeight > scroll.height

    ColumnLayout {
      id: list
      width: scroll.availableWidth
      spacing: 2

      NumberAnimation on opacity {
        id: fadeIn
        from: 0
        to: 1
        duration: Appearance.animNormal
      }

      // Modelled by count, so rows survive device changes (a connect
      // re-evaluates the list) instead of being rebuilt under the pointer
      Repeater {
        model: root.shownDevices.length

        DeviceRow {}
      }

      StyledText {
        Layout.fillWidth: true
        Layout.preferredHeight: scroll.availableHeight
        visible: root.shownDevices.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: I18n.tr(root.currentTab === 0 ? "No paired devices" : "Looking for devices…")
        textColor: Theme.foregroundAlt
      }
    }
  }
}
