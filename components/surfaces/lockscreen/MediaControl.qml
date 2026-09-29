pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable

StyledContainer {
  id: root
  visible: true
  clip: true

  property int widgetPadding: Widget.padding
  property int animationDuration: Appearance.animNormal
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
  property real albumRadius: Widget.radius / 2

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
    active: root.visible && MediaManager.hasActivePlayer

    sourceComponent: RowLayout {
      id: mainLayout
      spacing: root.itemSpacing

      StyledContainer {
        Layout.preferredWidth: root.albumArtSize
        Layout.preferredHeight: root.albumArtSize
        Layout.alignment: Qt.AlignVCenter
        borderColor: root.albumBorderColor
        borderWidth: root.albumBorderWidth
        borderRadius: root.albumRadius

        Image {
          id: albumArt
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          // The downloaded copy (see MediaManager): the remote URL can
          // fail to load, and artVersion changes whenever a new file lands
          source: MediaManager.artDownloaded && MediaManager.artVersion >= 0 ? "file://" + MediaManager.artFilePath : ""
          smooth: true
          asynchronous: true
          cache: true
          // Never assign `source` here: that would break the binding and
          // freeze the art on the failed track
          visible: status === Image.Ready
        }
      }

      // Track Info & Progress
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: root.innerSpacing

        StyledText {
          Layout.fillWidth: true
          text: MediaManager.trackTitle
          textSize: root.titleFontSize
          textColor: root.titleColor
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: MediaManager.trackArtist
          textSize: root.artistFontSize
          textColor: root.artistColor
          elide: Text.ElideRight
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.volumeSpacing

          StyledText {
            id: positionDisplay
            text: MediaManager.formatTime(MediaManager.position)
            textSize: root.timeFontSize
            textColor: root.timeColor
          }

          StyledIconButton {
            iconText: "skip_previous"
            onClicked: MediaManager.previous()
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
            troughHeight: root.sliderGrooveHeight
            Layout.leftMargin: root.spacerWidth
            Layout.rightMargin: root.spacerWidth

            enabled: root.showProgressBar && MediaManager.hasActivePlayer && MediaManager.length > 0
            visible: root.showProgressBar && MediaManager.hasActivePlayer && MediaManager.length > 0

            handleColor: Theme.backgroundAlt

            property bool userInteracting: false
            property string currentTrackTitle: MediaManager.trackTitle || ""

            value: userInteracting ? value : MediaManager.progress

            onMoved: newValue => {
              userInteracting = true;
            }

            onReleased: newValue => {
              MediaManager.setPositionByRatio(newValue);
              resetTimer.restart();
            }

            Timer {
              id: resetTimer
              interval: 200
              repeat: false
              onTriggered: progressSlider.userInteracting = false
            }

            Timer {
              interval: 1000
              running: MediaManager.isPlaying && MediaManager.hasActivePlayer
              repeat: true
              onTriggered: {
                MediaManager.updatePosition();
              }
            }

            onCurrentTrackTitleChanged: {
              userInteracting = false;
              MediaManager.updatePosition();
            }

            Connections {
              target: MediaManager

              function onPositionChanged() {
                if (!progressSlider.userInteracting) {
                  progressSlider.value = MediaManager.progress;
                }
              }

              function onMetadataUpdated() {
                if (!progressSlider.userInteracting && MediaManager.position < 1000) {
                  progressSlider.value = MediaManager.progress;
                }
              }
            }
          }

          StyledIconButton {
            iconText: "skip_next"
            onClicked: MediaManager.next()
            iconColor: root.buttonIconColor
            backgroundColor: root.buttonBackgroundColor
            Layout.fillWidth: false
            Layout.fillHeight: false
            Layout.preferredWidth: root.skipButtonSize
            Layout.preferredHeight: root.skipButtonSize
          }

          StyledText {
            text: MediaManager.formatTime(MediaManager.length)
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
          iconText: MediaManager.isPlaying ? "pause" : "play_arrow"
          iconSize: root.playIconFontSize
          onClicked: MediaManager.togglePlayPause()
          iconColor: MediaManager.isPlaying ? root.playIconColor : root.pauseIconColor
          backgroundColor: MediaManager.isPlaying ? root.playBackgroundColor : root.pauseBackgroundColor
          width: root.playButtonSize
          height: root.playButtonSize
        }
      }
    }
  }
}
