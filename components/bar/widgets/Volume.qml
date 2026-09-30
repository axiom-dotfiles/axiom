pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config
import qs.components.hosts.popout

// Default output volume. The icon follows mute, level and the device type
// (headphones, headset, Bluetooth, HDMI). Scroll changes the volume, click
// mutes, middle click runs a command; hovering opens the mixer.
BarIconWidget {
  id: root

  readonly property real maxVolume: properties.maxVolume / 100

  icon: AudioManager.outputIcon(AudioManager.deviceKind(AudioManager.defaultSink), AudioManager.muted, AudioManager.volume)
  text: `${Math.round(AudioManager.volume * 100)}%`
  showText: properties.showPercentage

  backgroundColor: Theme.resolveColor(AudioManager.muted ? properties.mutedColor : properties.backgroundColor)
  opacity: mouseArea.pressed ? 0.8 : 1

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) {
        CommandManager.runDetached(root.properties.middleCommand);
      } else {
        AudioManager.toggleMute();
      }
    }
    onWheel: wheel => {
      const step = root.properties.scrollStep / 100;
      AudioManager.stepNodeVolume(AudioManager.defaultSink, wheel.angleDelta.y > 0 ? step : -step, root.maxVolume);
    }
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "AudioMixer"
    active: root.properties.showPopout
    extraData: ({
        "mode": "output",
        "maxVolume": root.maxVolume
      })
  }
}
