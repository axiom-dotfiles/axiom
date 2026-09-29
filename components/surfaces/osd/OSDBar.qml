pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services
import qs.components.reusable

// One OSD bar, by its entry's type (see OSD.bars in the schema):
//   master:     the default output's volume
//   other:      the first playing stream no App bar matches
//   app:        the streams its apps match by name
//   microphone: the default input's volume
//   brightness: this screen's brightness (left out without a controller)
Loader {
  id: root

  required property var entry
  required property string screenName
  // The OSD's own settings: bars run vertically, levels shown as numbers
  property bool vertical: true
  property bool showPercent: true

  // The bar's level changed through the user (not a device switch or a
  // stream appearing): the OSD opens if the entry's showOsd says so
  signal poked

  readonly property int orientation: root.vertical ? Qt.Vertical : Qt.Horizontal
  readonly property string type: entry.type
  readonly property bool isVolume: type === "master" || type === "other" || type === "app"

  active: type !== "brightness" || BrightnessManager.available(screenName)
  visible: active
  sourceComponent: isVolume ? volumeBar : (type === "microphone" ? micBar : brightnessBar)

  Component {
    id: volumeBar

    PipewireVolumeBar {
      readonly property bool isMaster: root.type === "master"

      orientation: root.orientation
      showPercent: root.showPercent
      scrollStep: OSDConfig.scrollStep
      targetApps: root.type === "app" ? root.entry.apps : []
      otherApps: root.type === "other"
      excludedApps: root.type === "other" ? OSDConfig.excludedApps : []
      useSystemVolume: isMaster
      iconSource: {
        if (!isMaster || root.entry.icon)
          return root.entry.icon;
        if (AudioManager.muted || AudioManager.volume === 0)
          return "volume_mute";
        return AudioManager.volume > 0.4 ? "volume_up" : "volume_down";
      }

      onVisibilityChanged: root.poked()
    }
  }

  Component {
    id: micBar

    StyledVolumeBar {
      id: mic
      // The first change after the input device switches (or binds) is it
      // appearing, not the user
      property var _source: null

      function _levelChanged() {
        if (AudioManager.defaultSource === _source)
          root.poked();
        _source = AudioManager.defaultSource;
      }

      orientation: root.orientation
      showPercent: root.showPercent
      scrollStep: OSDConfig.scrollStep
      volumeLevel: AudioManager.sourceVolume
      isMuted: AudioManager.sourceMuted
      enabled: AudioManager.defaultSource !== null
      iconSource: root.entry.icon || AudioManager.inputIcon(AudioManager.deviceKind(AudioManager.defaultSource), AudioManager.sourceMuted)
      onVolumeChanged: newVolume => AudioManager.setSourceVolume(newVolume)
      Component.onCompleted: _source = AudioManager.defaultSource

      Connections {
        target: AudioManager

        function onSourceVolumeChanged() {
          mic._levelChanged();
        }

        function onSourceMutedChanged() {
          mic._levelChanged();
        }
      }
    }
  }

  Component {
    id: brightnessBar

    StyledVolumeBar {
      readonly property real level: BrightnessManager.valueFor(root.screenName)

      orientation: root.orientation
      showPercent: root.showPercent
      scrollStep: OSDConfig.scrollStep
      volumeLevel: level
      iconSource: root.entry.icon || (level < 0.34 ? "brightness_low" : (level < 0.67 ? "brightness_medium" : "brightness_high"))
      onVolumeChanged: newVolume => BrightnessManager.set(root.screenName, newVolume)

      Connections {
        target: BrightnessManager

        function onBrightnessChanged(name) {
          if (name === root.screenName)
            root.poked();
        }
      }
    }
  }
}
