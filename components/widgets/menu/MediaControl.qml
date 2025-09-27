pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
// Your project's imports
import qs.services
import qs.config
import qs.components.reusable
import qs.components.widgets.menu

StyledContainer {
  id: root
  visible: true
  clip: true

  property int widgetPadding: Widget.padding
  property int animationDuration: 200
  property int albumArtSize: 80
  property int itemSpacing: 12
  property int innerSpacing: 4
  property int volumeSpacing: 8

  property int skipButtonSize: 25
  property int playButtonSize: 40
  property int spacerWidth: 10

  property int titleFontSize: Appearance.fontSize - 2
  property int artistFontSize: Appearance.fontSize - 4
  property int timeFontSize: Appearance.fontSize - 4
  property int playIconFontSize: Appearance.fontSize + 4

  property color titleColor: Theme.background
  property color artistColor: Theme.backgroundAlt
  property color timeColor: Theme.backgroundAlt
  property color buttonIconColor: Theme.foregroundAlt
  property color buttonBackgroundColor: Theme.backgroundHighlight
  property color playIconColor: Theme.foreground
  property color playBackgroundColor: Theme.backgroundAlt
  property color albumBorderColor: Theme.backgroundHighlight
  property int albumBorderWidth: 1
  property real albumRadius: Appearance.borderRadius / 2

  Layout.preferredHeight: mediaControlLoader.item ? mediaControlLoader.item.implicitHeight + widgetPadding * 2 : 0
  Layout.fillWidth: true

  Behavior on Layout.preferredHeight {
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  Loader {
    id: mediaControlLoader
    anchors.fill: parent
    anchors.margins: root.widgetPadding
    active: root.visible

    sourceComponent: RowLayout {
      spacing: root.itemSpacing

      // Album Art
      StyledContainer {
        Layout.preferredWidth: root.albumArtSize
        Layout.preferredHeight: root.albumArtSize
        Layout.alignment: Qt.AlignVCenter
        containerBorderColor: root.albumBorderColor
        containerBorderWidth: root.albumBorderWidth
        radius: root.albumRadius

        Image {
          id: albumArt
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          source: MprisController.artFilePath ? MprisController.artFilePath + "?v=" + MprisController.artVersion : "qrc:/images/default_album_art.png"
          smooth: true
          cache: false
        }
      }

      // Track Info & Progress (expandable middle section)
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: root.innerSpacing

        // Track title
        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackTitle
          textSize: root.titleFontSize
          textColor: root.titleColor
          elide: Text.ElideRight
        }

        // Artist
        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackArtist
          textSize: root.artistFontSize
          textColor: root.artistColor
          elide: Text.ElideRight
        }

        // Progress bar with time
        RowLayout {
          Layout.fillWidth: true
          spacing: root.volumeSpacing

          StyledText {
            text: MprisController.formatTime(MprisController.position)
            textSize: root.timeFontSize
            textColor: root.timeColor
          }

          StyledSlider {
            Layout.fillWidth: true
            enabled: MprisController.canSeek
            value: MprisController.progress
            onReleased: newValue => MprisController.setPositionByRatio(newValue)
          }

          StyledText {
            text: MprisController.formatTime(MprisController.length)
            textSize: root.timeFontSize
            textColor: root.timeColor
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: childrenRect.width
        spacing: root.volumeSpacing

        StyledIconButton {
          iconText: "󰒮"
          onClicked: MprisController.previous()
          iconColor: root.buttonIconColor
          backgroundColor: root.buttonBackgroundColor
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: root.skipButtonSize
          Layout.preferredHeight: root.skipButtonSize
        }

        StyledIconButton {
          iconText: MprisController.isPlaying ? "󰏤" : "󰐊"
          iconSize: root.playIconFontSize
          onClicked: MprisController.togglePlayPause()
          iconColor: root.playIconColor
          backgroundColor: root.playBackgroundColor
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: root.playButtonSize
          Layout.preferredHeight: root.playButtonSize
        }

        StyledIconButton {
          iconText: "󰒭"
          onClicked: MprisController.next()
          iconColor: root.buttonIconColor
          backgroundColor: root.buttonBackgroundColor
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: root.skipButtonSize
          Layout.preferredHeight: root.skipButtonSize
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: childrenRect.width
        spacing: root.volumeSpacing
        visible: MprisController.activePlayer?.volumeSupported ?? false

        Item {
          Layout.preferredWidth: root.spacerWidth
        }

        // Add volume controls here if needed
        // StyledIconButton for volume, StyledSlider for volume control, etc.
      }
    }
  }
}
