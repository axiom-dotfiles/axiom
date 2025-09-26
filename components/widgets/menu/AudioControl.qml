// qs/components/reusable/AudioControl.qml
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire // Using the Pipewire library directly

import qs.config
import qs.components.reusable

StyledContainer {
  id: root

  // --- Configurable Look & Feel Properties ---
  property int controlHeight: 60
  property int layoutSpacing: Widget.spacing
  property int columnSpacing: 2

  // Action Button
  property int actionButtonWidth: 10
  property int actionButtonHeight: 10
  property int actionButtonRadius: Appearance.borderRadius
  property int iconPixelSize: Appearance.fontSize
  property string iconMuted: "\u{f026}"    // FontAwesome: volume-off
  property string iconUnmuted: "\u{f028}"  // FontAwesome: volume-up

  // Slider
  property int sliderHeight: 16
  property int sliderGrooveHeight: 6

  // Colors
  property color defaultDeviceColor: Theme.accent
  property color nonDefaultDeviceColor: "transparent"
  property color defaultDeviceIconColor: Theme.background
  property color mutedIconColor: Theme.error
  property color normalIconColor: Theme.foreground
  property color textColor: Theme.foregroundAlt
  property color backgroundColor: Theme.backgroundHighlight

  // Text
  property real fontPixelSize: Appearance.fontSize * 0.9

  // --- Component Properties ---

  property var node: null

  // This tracker ensures that the node's properties (like volume and mute)
  // are fully available and writable, fixing the "unbound" error.
  PwObjectTracker {
    objects: [root.node]
  }

  // --- Logic Properties ---

  readonly property bool isReady: node ? node.ready : false
  readonly property bool isDevice: node ? !node.isStream : false
  readonly property bool isDefaultDevice: isDevice && Pipewire.defaultAudioSink === node

  // Determine the most appropriate name to display for the node.
  readonly property string displayName: {
    if (!node) {
      return "Invalid Node";
    }
    if (isReady) {
      return node.properties["application.name"] || node.nickname || node.description || node.name || "Unknown";
    }
    // Fallback for when the node is not yet fully bound
    return node.description || node.name || "Loading...";
  }

  border.color: Theme.foregroundAlt
  border.width: Appearance.borderWidth
  containerColor: backgroundColor

  // --- UI Structure ---
  Layout.preferredHeight: controlHeight
  Layout.fillWidth: true

  RowLayout {
    id: mainLayout
    anchors.fill: parent
    spacing: layoutSpacing

    // Button for muting streams or setting default devices.
    StyledRectButton {
      id: actionButton
      Layout.preferredWidth: actionButtonWidth
      Layout.preferredHeight: actionButtonHeight
      Layout.alignment: Qt.AlignVCenter
      borderRadius: actionButtonRadius

      enabled: isReady

      // Visual indicator for default device status.
      backgroundColor: isDefaultDevice ? defaultDeviceColor : nonDefaultDeviceColor
      iconColor: isDefaultDevice ? defaultDeviceIconColor : (node?.audio.muted ? mutedIconColor : normalIconColor)

      // Icon indicates mute state.
      iconText: node?.audio.muted ? iconMuted : iconUnmuted
      iconSize: iconPixelSize

      tooltipText: isDevice ? (isDefaultDevice ? "Default Output Device" : "Click to set as default") : (node?.audio.muted ? "Unmute" : "Mute")

      onClicked: {
        if (!isReady)
          return; // Guard clause

        if (isDevice) {
          // Set this device as the preferred default sink directly via the Pipewire singleton
          Pipewire.preferredDefaultAudioSink = node;
        } else {
          if (node.audio) {
            node.audio.muted = !node.audio.muted;
          }
        }
      }
    }

    // Name and Volume Slider section.
    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: columnSpacing

      StyledText {
        text: displayName
        elide: Text.ElideRight
        font.pixelSize: root.fontPixelSize
        textColor: root.textColor
      }

      StyledSlider {
        id: volumeSlider
        Layout.fillWidth: true
        Layout.preferredHeight: sliderHeight
        Layout.rightMargin: Widget.padding
        grooveHeight: sliderGrooveHeight

        enabled: isReady && node?.audio !== null

        value: enabled ? node.audio.volume : 0

        onMoved: if (enabled)
          node.audio.volume = value
        onReleased: if (enabled)
          node.audio.volume = value
      }
    }
  }
}
