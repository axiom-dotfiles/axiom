pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

// Default input. The icon follows mute and the device type (headset,
// webcam); the background shows when an app is recording from the mic.
// See AudioLevelWidget.
AudioLevelWidget {
  node: AudioManager.defaultSource
  mode: "input"
  hidden: properties.hideWhenIdle && !AudioManager.micInUse && !muted
  icon: AudioManager.inputIcon(AudioManager.deviceKind(node), muted)
  backgroundColor: Theme.resolveColor(muted ? properties.mutedColor : AudioManager.micInUse ? properties.activeColor : properties.backgroundColor)
}
