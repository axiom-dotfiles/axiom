// qs/components/widgets/menu/AudioControl.qml
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

import qs.config
import qs.components.reusable

StyledContainer {
  id: root

  property int controlHeight: 60
  property int layoutSpacing: Widget.spacing
  property int columnSpacing: 2

  property int actionButtonWidth: 10
  property int actionButtonHeight: 10
  property int actionButtonRadius: Appearance.borderRadius
  property int iconPixelSize: Appearance.fontSize
  property string iconMuted: "\u{f026}"    // FontAwesome: volume-off
  property string iconUnmuted: "\u{f028}"  // FontAwesome: volume-up

  property int sliderHeight: 16
  property int sliderGrooveHeight: 6

  // Colors
  property color defaultDeviceColor: Theme.accent
  property color nonDefaultDeviceColor: "transparent"
  property color defaultDeviceIconColor: Theme.background
  property color mutedIconColor: Theme.error
  property color normalIconColor: Theme.foreground
  property color textColor: Theme.foregroundAlt
  property color backgroundColor: Theme.backgroundAlt

  // Text
  property real fontPixelSize: Appearance.fontSize * 0.9

  // --- Component Properties ---

  property var node: null

  PwObjectTracker {
    objects: [root.node]
  }

  readonly property bool isReady: node ? node.ready : false
  readonly property bool isDevice: node ? !node.isStream : false
  readonly property bool isDefaultDevice: isDevice && Pipewire.defaultAudioSink === node

  readonly property string displayName: {
    if (!node) {
      return "Invalid Node";
    }
    if (isReady) {
      return node.properties["application.process.binary"] || node.properties["application.name"] || node.nickname || node.description || node.name || "Unknown";
    }
    return node.description || node.name || "Loading...";
  }

  // backgroundColor: backgroundColor

  Layout.preferredHeight: controlHeight
  Layout.fillWidth: true

  // Component.onCompleted: {
  //   console.log("Logging sink information------");
  //   console.log("Node:", node);
  //   if (node) {
  //     console.log("Node ID:", node.id);
  //     console.log("Node Name:", node.name);
  //     console.log("Node Description:", node.description);
  //     console.log("Node Properties:", node.properties);
  //     console.log("Is Stream:", node.isStream);
  //     console.log("Is Sink:", node.isSink);
  //     console.log("Is Source:", node.isSource);
  //     console.log("Is Ready:", node.ready);
  //     if (node.properties) {
  //       console.log("Node Properties:", node.properties);
  //       console.log("Application Name:", node.properties["application.process.binary"]);
  //       console.log("Media Name:", node.properties["media.name"]);
  //     }
  //     if (node.audio) {
  //       console.log("Audio Volume:", node.audio.volume);
  //       console.log("Audio Muted:", node.audio.muted);
  //     } else {
  //       console.log("No audio interface available.");
  //     }
  //   }
  // }

  RowLayout {
    id: mainLayout
    anchors.fill: parent
    spacing: layoutSpacing

    StyledRectButton {
      id: actionButton
      Layout.preferredWidth: root.actionButtonWidth
      Layout.preferredHeight: root.actionButtonHeight
      Layout.alignment: Qt.AlignVCenter
      borderRadius: root.actionButtonRadius

      enabled: root.isReady

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
        Layout.preferredHeight: root.sliderHeight
        Layout.rightMargin: actionButton.width
        troughHeight: root.sliderGrooveHeight
        troughColor: Theme.backgroundHighlight

        enabled: root.isReady && root.node?.audio !== null

        value: enabled ? root.node.audio.volume : 0

        onMoved: if (enabled)
          root.node.audio.volume = value
        onReleased: if (enabled)
          root.node.audio.volume = value
      }
    }
  }
}
