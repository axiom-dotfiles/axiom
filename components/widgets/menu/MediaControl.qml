pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

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
  property int playButtonSize: 60
  property int spacerWidth: 10

  property bool showProgressBar: true

  property int controlButtonsLeftMargin: Widget.padding
  property int controlButtonsRightMargin: Widget.padding

  property int titleFontSize: Appearance.fontSize - 2
  property int artistFontSize: Appearance.fontSize - 4
  property int timeFontSize: Appearance.fontSize - 4
  property int playIconFontSize: Appearance.fontSize + 4

  property color titleColor: Theme.background
  property color artistColor: Theme.backgroundAlt
  property color timeColor: Theme.backgroundAlt
  property color buttonIconColor: Theme.foregroundAlt
  property color buttonBackgroundColor: Theme.backgroundHighlight
  property color playIconColor: Theme.background
  property color pauseIconColor: Theme.foreground
  property color pauseButtonColor: Theme.background
  property color pauseBackgroundColor: Theme.background
  property color playBackgroundColor: Theme.cyan
  property color albumBorderColor: Theme.backgroundHighlight
  property int albumBorderWidth: 1
  property real albumRadius: Appearance.borderRadius / 2

  property int sliderHeight: 12
  property int sliderGrooveHeight: 8

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
      id: mainLayout
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
          source: {
            if (MprisController.artUrl.startsWith("file://")) {
              return MprisController.artUrl;
            }
            return MprisController.artUrl;
          }
          smooth: true
          asynchronous: true
          cache: true

          onStatusChanged: {
            if (status === Image.Error) {
              console.warn("Failed to load album art from:", source);
              source = "qrc:/images/default_album_art.png";
            } else if (status === Image.Ready) {
              console.log("Successfully loaded album art");
            }
          }
        }
      }

      // Track Info & Progress
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: root.innerSpacing

        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackTitle
          textSize: root.titleFontSize
          textColor: root.titleColor
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackArtist
          textSize: root.artistFontSize
          textColor: root.artistColor
          elide: Text.ElideRight
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.volumeSpacing

          StyledText {
            text: MprisController.formatTime(MprisController.position)
            textSize: root.timeFontSize
            textColor: root.timeColor
          }

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

          StyledSlider {
            id: progressSlider
            Layout.fillWidth: true
            Layout.preferredHeight: root.sliderHeight
            grooveHeight: root.sliderGrooveHeight
            enabled: root.showProgressBar && MprisController.hasActivePlayer && MprisController.length > 0
            visible: root.showProgressBar && MprisController.hasActivePlayer && MprisController.length > 0
            value: MprisController.progress
            handleColor: Theme.backgroundAlt
            Layout.leftMargin: root.spacerWidth
            Layout.rightMargin: root.spacerWidth
            onMoved: newValue => MprisController.setPositionByRatio(newValue)
            onReleased: newValue => MprisController.setPositionByRatio(newValue)
            Connections {
              target: MprisController
              onPositionChanged: {
                if (!progressSlider.pressed) {
                  progressSlider.value = MprisController.progress;
                }
              }
            }
            onValueChanged: {
              if (value === 1 && MprisController.position < MprisController.length - 1) {
                value = MprisController.progress;
              }
            }
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

          StyledText {
            text: MprisController.formatTime(MprisController.length)
            textSize: root.timeFontSize
            textColor: root.timeColor
          }
        }
      }

      Item {
        id: controlButtonsContainer
        Layout.preferredWidth: mainLayout.width / 6
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter

        StyledIconButton {
          anchors.centerIn: parent
          anchors.leftMargin: root.controlButtonsLeftMargin
          anchors.rightMargin: root.controlButtonsRightMargin
          iconText: MprisController.isPlaying ? "󰏤" : "󰐊"
          iconSize: root.playIconFontSize
          onClicked: MprisController.togglePlayPause()
          iconColor: MprisController.isPlaying ? root.playIconColor : root.pauseIconColor
          backgroundColor: MprisController.isPlaying ? root.playBackgroundColor : root.pauseBackgroundColor
          width: root.playButtonSize
          height: root.playButtonSize
        }
      }
    }
  }
}
