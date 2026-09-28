pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services
import qs.config
import qs.components.reusable
import qs.components.content.parts
import qs.components.content.base

// Volume mixer: the default device on top, then an Applications tab
// (per-app volume, one row per app however many streams it has) and a
// Devices tab (pick the default, adjust each device). As the Volume
// ("output") and Microphone ("input") widgets' popout, or an overlay card
// with its own output/input switch. properties: { mode: "output" | "input" }
Panel {
  id: root

  // A card's configured mode; a popout sets it from its anchor's payload
  property string mode: root.properties.mode ?? "output"
  property real maxVolume: 1.0

  property int currentTab: 0

  readonly property bool isInput: mode === "input"
  readonly property var defaultDevice: isInput ? AudioManager.defaultSource : AudioManager.defaultSink
  readonly property var apps: isInput ? AudioManager.recordingApps : AudioManager.playbackApps
  readonly property var devices: isInput ? AudioManager.sources : AudioManager.sinks
  readonly property string mutedGlyph: isInput ? "mic_off" : "volume_off"
  readonly property string unmutedGlyph: isInput ? "mic" : "volume_up"

  // A popout's list is a fixed four app rows high, so switching tabs or
  // apps coming and going never resizes (and moves) the popout
  readonly property real listHeight: defaultRow.implicitHeight * 4 + list.spacing * 3

  implicitWidth: 380

  function deviceName(node) {
    return node?.description || node?.nickname || node?.name || I18n.tr("No device");
  }
  function deviceIcon(node, muted, level) {
    const kind = AudioManager.deviceKind(node);
    return isInput ? AudioManager.inputIcon(kind, muted) : AudioManager.outputIcon(kind, muted, level);
  }

  onCurrentTabChanged: fadeIn.restart()

  // Quarter card: the default device's volume; click to mute
  compactContent: Item {
    implicitWidth: figure.implicitWidth
    implicitHeight: figure.implicitHeight
    readonly property var node: root.defaultDevice
    readonly property bool muted: node?.audio?.muted ?? false
    CompactFigure {
      id: figure
      anchors.centerIn: parent
      icon: parent.muted ? root.mutedGlyph : root.unmutedGlyph
      iconColor: parent.muted ? Theme.foregroundAlt : Theme.accent
      value: String(Math.round((parent.node?.audio?.volume ?? 0) * 100))
      unit: "%"
      label: I18n.tr(root.isInput ? "Input" : "Output")
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: AudioManager.toggleNodeMute(parent.node)
    }
  }

  StyledText {
    visible: !root.embedded
    text: I18n.tr(root.isInput ? "Input" : "Output")
    font.bold: true
    textColor: Theme.accent
  }

  // A card switches between output and input itself, from its header
  ModuleHeader {
    visible: root.embedded
    icon: root.unmutedGlyph
    title: I18n.tr(root.isInput ? "Input" : "Output")
    Repeater {
      model: [["output", "volume_up", I18n.tr("Output")], ["input", "mic", I18n.tr("Input")]]
      StyledRectButton {
        required property var modelData
        readonly property bool selected: root.mode === modelData[0]
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: Widget.height
        Layout.preferredHeight: Widget.height
        iconText: modelData[1]
        iconColor: selected ? Theme.accent : Theme.foregroundAlt
        backgroundColor: selected ? Theme.backgroundHighlight : "transparent"
        borderHoverColor: Theme.accent
        tooltipText: modelData[2]
        onClicked: root.mode = modelData[0]
      }
    }
  }

  // Default device, visible on both tabs
  AudioRow {
    id: defaultRow
    readonly property var node: root.defaultDevice
    icon: root.deviceIcon(node, muted, volume)
    title: root.deviceName(node)
    volume: node?.audio?.volume ?? 0
    muted: node?.audio?.muted ?? false
    maxVolume: root.maxVolume
    mutedGlyph: root.mutedGlyph
    unmutedGlyph: root.unmutedGlyph
    onVolumeMoved: value => AudioManager.setNodeVolume(node, value, root.maxVolume)
    onMuteToggled: AudioManager.toggleNodeMute(node)
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

    Repeater {
      model: [I18n.tr("Applications ({0})", root.apps.length), I18n.tr("Devices")]

      StyledTabButton {
        required property int index
        required property string modelData
        text: modelData
        checked: root.currentTab === index
        onClicked: root.currentTab = index
      }
    }
  }

  StyledScrollView {
    id: scroll
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

      // Applications. Modelled by count, so a row survives its app's
      // streams changing (a new track renames it) instead of being rebuilt
      // under the pointer, mid-drag
      Repeater {
        model: root.currentTab === 0 ? root.apps.length : 0

        AudioRow {
          id: appRow
          required property int index
          readonly property var app: root.apps[index] ?? null
          readonly property var node: app?.nodes[0] ?? null
          icon: root.unmutedGlyph
          iconSource: app?.icon ? Quickshell.iconPath(app.icon, true) : ""
          title: app?.name ?? ""
          subtitle: app?.subtitle ?? ""
          volume: node?.audio?.volume ?? 0
          muted: node?.audio?.muted ?? false
          maxVolume: root.maxVolume
          mutedGlyph: root.mutedGlyph
          unmutedGlyph: root.unmutedGlyph
          onVolumeMoved: value => (appRow.app?.nodes ?? []).forEach(n => AudioManager.setNodeVolume(n, value, root.maxVolume))
          onMuteToggled: {
            const mute = !appRow.muted;
            (appRow.app?.nodes ?? []).forEach(n => {
              if (n.audio)
                n.audio.muted = mute;
            });
          }
        }
      }

      // An empty list says so in the middle of the (fixed-height) view
      StyledText {
        Layout.fillWidth: true
        Layout.preferredHeight: scroll.availableHeight
        visible: root.currentTab === 0 ? root.apps.length === 0 : root.devices.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: root.currentTab === 1 ? I18n.tr("No devices found") : I18n.tr(root.isInput ? "No apps recording" : "No apps playing audio")
        textColor: Theme.foregroundAlt
      }

      // Devices: click one to make it the default (whose volume is above)
      Repeater {
        model: root.currentTab === 1 ? root.devices.length : 0

        Rectangle {
          id: deviceRow
          required property int index
          readonly property var node: root.devices[index] ?? null
          readonly property bool selected: node !== null && node === root.defaultDevice

          Layout.fillWidth: true
          implicitHeight: deviceLayout.implicitHeight + Widget.spacing * 2
          radius: Appearance.borderRadius
          color: selected ? Theme.backgroundHighlight : deviceMouse.containsMouse ? Qt.rgba(Theme.backgroundHighlight.r, Theme.backgroundHighlight.g, Theme.backgroundHighlight.b, 0.5) : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Appearance.animFast
            }
          }

          MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: deviceRow.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: AudioManager.setDefault(deviceRow.node)
          }

          RowLayout {
            id: deviceLayout
            anchors.fill: parent
            anchors.margins: Widget.spacing
            anchors.leftMargin: Widget.padding
            anchors.rightMargin: Widget.padding
            spacing: Widget.padding

            StyledIcon {
              Layout.preferredWidth: 26
              horizontalAlignment: Text.AlignHCenter
              text: root.deviceIcon(deviceRow.node, false, 1)
              textSize: Appearance.fontSize * 1.2
              textColor: deviceRow.selected ? Theme.accent : Theme.foregroundAlt
            }

            StyledText {
              Layout.fillWidth: true
              text: root.deviceName(deviceRow.node)
              elide: Text.ElideRight
              textSize: Appearance.fontSize - 1
              textColor: deviceRow.selected ? Theme.foreground : Theme.foregroundAlt
            }

            // Always laid out, so selecting a row doesn't reflow it
            StyledIcon {
              opacity: deviceRow.selected ? 1 : 0
              text: "check"
              textColor: Theme.accent
            }
          }
        }
      }
    }
  }
}
