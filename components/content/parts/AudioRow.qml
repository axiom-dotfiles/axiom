pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import qs.config
import qs.components.reusable

// One mixer line: icon, title (+ dim subtitle), volume slider, percentage
// and a mute button.
Item {
  id: root

  signal volumeMoved(real volume)
  signal muteToggled

  // Material Symbols icon shown when there's no image (or it fails to load)
  property string icon: ""
  property string iconSource: ""
  property string title: ""
  property string subtitle: ""
  property real volume: 0
  property bool muted: false
  property real maxVolume: 1.0
  property string mutedGlyph: "volume_off"
  property string unmutedGlyph: "volume_up"

  implicitHeight: layout.implicitHeight + Widget.spacing * 2
  Layout.fillWidth: true

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Widget.spacing
    anchors.leftMargin: Widget.padding
    anchors.rightMargin: Widget.padding
    spacing: Widget.padding

    Item {
      Layout.preferredWidth: 26
      Layout.preferredHeight: 26

      IconImage {
        id: image
        anchors.fill: parent
        source: root.iconSource
        visible: root.iconSource !== "" && status === Image.Ready
        opacity: root.muted ? 0.5 : 1
      }

      StyledIcon {
        anchors.centerIn: parent
        visible: !image.visible
        text: root.icon
        textColor: root.muted ? Theme.foregroundAlt : Theme.foreground
        textSize: Appearance.fontSize * 1.4
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      // Not the title's width, so every row's slider is the same length
      Layout.preferredWidth: 0
      spacing: 2

      RowLayout {
        Layout.fillWidth: true
        spacing: Widget.spacing

        StyledText {
          Layout.fillWidth: !subtitleText.visible
          Layout.maximumWidth: subtitleText.visible ? implicitWidth : -1
          text: root.title
          elide: Text.ElideRight
          textSize: Appearance.fontSize - 1
          textColor: root.muted ? Theme.foregroundAlt : Theme.foreground
        }

        StyledText {
          id: subtitleText
          Layout.fillWidth: true
          visible: root.subtitle !== "" && root.subtitle !== root.title
          text: root.subtitle
          elide: Text.ElideRight
          textSize: Appearance.fontSize - 3
          textColor: Theme.foregroundAlt
        }
      }

      StyledSlider {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        troughHeight: 6
        handleWidth: 14
        handleHeight: 14
        handleRadius: 7
        handleColor: root.muted ? Theme.foregroundAlt : Theme.foreground
        fillColor: root.muted ? Theme.foregroundAlt : Theme.accent
        // Not `value`: dragging assigns that, which would drop the binding
        targetValue: Math.min(1, root.volume / root.maxVolume)
        onMoved: value => root.volumeMoved(value * root.maxVolume)
        onReleased: value => root.volumeMoved(value * root.maxVolume)
      }
    }

    StyledText {
      Layout.preferredWidth: percentMetrics.width
      horizontalAlignment: Text.AlignRight
      text: `${Math.round(root.volume * 100)}%`
      textSize: Appearance.fontSize - 2
      textColor: Theme.foregroundAlt

      TextMetrics {
        id: percentMetrics
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize - 2
        text: "150%"
      }
    }

    StyledRectButton {
      size: 28
      iconText: root.muted ? root.mutedGlyph : root.unmutedGlyph
      iconColor: root.muted ? Theme.error : Theme.foreground
      backgroundColor: "transparent"
      borderHoverColor: Theme.accent
      tooltipText: I18n.tr(root.muted ? "Unmute" : "Mute")
      onClicked: root.muteToggled()
    }
  }
}
