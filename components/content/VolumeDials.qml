pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// Output and microphone volume as two dials: scroll to adjust, click to
// mute. Side by side in wide and square slots, stacked in tall ones;
// compact shows the output only.
Card {
  id: root

  component Dial: Item {
    id: dial
    property real level: 0
    property bool muted: false
    property string icon
    property string label
    signal toggled
    signal stepped(real delta)

    // The dial and its label, kept together and centred
    Column {
      anchors.centerIn: parent
      spacing: Widget.spacing
      PercentageCircle {
        readonly property real side: Math.max(0, Math.min(dial.width, dial.height - (dialLabel.visible ? dialLabel.height + Widget.spacing : 0)))
        anchors.horizontalCenter: parent.horizontalCenter
        width: side
        height: side
        percentage: dial.muted ? 0 : Math.round(dial.level * 100)
        iconText: dial.icon
        iconColor: dial.muted ? Theme.error : Theme.foreground
        fillColor: Theme.accent
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: dial.toggled()
          onWheel: wheel => dial.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
      }
      StyledText {
        id: dialLabel
        visible: !root.compact
        anchors.horizontalCenter: parent.horizontalCenter
        text: dial.muted ? I18n.tr("{0} · muted", dial.label) : `${dial.label} · ${Math.round(dial.level * 100)}%`
        textSize: Appearance.fontSize - 1
        opacity: 0.8
      }
    }
  }

  GridLayout {
    anchors.fill: parent
    anchors.margins: root.pad
    columns: root.shape === "vertical" ? 1 : 2
    columnSpacing: root.pad
    rowSpacing: root.pad

    Dial {
      Layout.fillWidth: true
      Layout.fillHeight: true
      level: AudioManager.volume
      muted: AudioManager.muted
      icon: AudioManager.muted ? "volume_off" : "volume_up"
      label: I18n.tr("Output")
      onToggled: AudioManager.toggleMute()
      onStepped: delta => AudioManager.stepNodeVolume(AudioManager.defaultSink, delta)
    }
    Dial {
      visible: !root.compact
      Layout.fillWidth: true
      Layout.fillHeight: true
      level: AudioManager.sourceVolume
      muted: AudioManager.sourceMuted
      icon: AudioManager.sourceMuted ? "mic_off" : "mic"
      label: I18n.tr("Input")
      onToggled: AudioManager.toggleSourceMute()
      onStepped: delta => AudioManager.stepNodeVolume(AudioManager.defaultSource, delta)
    }
  }
}
