pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.config

// Default output volume. The icon follows mute, level and the device type
// (headphones, headset, Bluetooth, HDMI). See AudioLevelWidget.
AudioLevelWidget {
  node: AudioManager.defaultSink
  mode: "output"
  icon: AudioManager.outputIcon(AudioManager.deviceKind(node), muted, level)
  backgroundColor: Theme.resolveColor(muted ? properties.mutedColor : properties.backgroundColor)
}
