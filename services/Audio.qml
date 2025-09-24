pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire

QtObject {
  id: root

  // Track the default audio sink
  property PwObjectTracker tracker: PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  // Expose the audio sink for external access if needed
  readonly property var defaultSink: Pipewire.defaultAudioSink

  // These properties will automatically update when Pipewire values change
  // and emit onVolumeChanged, onMutedChanged signals automatically
  readonly property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
  readonly property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
  readonly property string name: Pipewire.defaultAudioSink?.name ?? ""
  readonly property string description: Pipewire.defaultAudioSink?.description ?? ""

  // Helper functions for volume control
  function increaseVolume(amount = 0.05) {
    if (defaultSink?.audio) {
      defaultSink.audio.volume = Math.min(1.0, defaultSink.audio.volume + amount);
    }
  }

  function decreaseVolume(amount = 0.05) {
    if (defaultSink?.audio) {
      defaultSink.audio.volume = Math.max(0.0, defaultSink.audio.volume - amount);
    }
  }

  function toggleMute() {
    if (defaultSink?.audio) {
      defaultSink.audio.muted = !defaultSink.audio.muted;
    }
  }

  function setVolume(value) {
    if (defaultSink?.audio) {
      defaultSink.audio.volume = Math.max(0.0, Math.min(1.0, value));
    }
  }
}
