pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.services
import qs.config
import qs.components.hosts.popout

// Default input. The icon follows mute and the device type (headset,
// webcam); the background shows when an app is recording from the mic.
// Scroll changes the volume, click mutes, middle click runs a command;
// hovering opens the mixer on its input side.
BarIconWidget {
  id: root

  readonly property real maxVolume: properties.maxVolume / 100
  readonly property bool hidden: properties.hideWhenIdle && !AudioManager.micInUse && !AudioManager.sourceMuted

  icon: AudioManager.inputIcon(AudioManager.deviceKind(AudioManager.defaultSource), AudioManager.sourceMuted)
  text: `${Math.round(AudioManager.sourceVolume * 100)}%`
  showIcon: !hidden
  showText: properties.showPercentage && !hidden
  padding: hidden ? 0 : root.barConfig.widgetPadding

  backgroundColor: Theme.resolveColor(AudioManager.sourceMuted ? properties.mutedColor : AudioManager.micInUse ? properties.activeColor : properties.backgroundColor)
  opacity: mouseArea.pressed ? 0.8 : 1

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    enabled: !root.hidden
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) {
        if (root.properties.middleCommand)
          Quickshell.execDetached(["sh", "-c", root.properties.middleCommand]);
      } else {
        AudioManager.toggleSourceMute();
      }
    }
    onWheel: wheel => {
      const step = root.properties.scrollStep / 100;
      AudioManager.stepNodeVolume(AudioManager.defaultSource, wheel.angleDelta.y > 0 ? step : -step, root.maxVolume);
    }
  }

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "AudioMixer"
    active: root.properties.showPopout && !root.hidden
    extraData: ({
        "mode": "input",
        "maxVolume": root.maxVolume
      })
  }
}
