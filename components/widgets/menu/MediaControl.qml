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

  Layout.preferredHeight: mediaControlLoader.item ? mediaControlLoader.item.implicitHeight + Widget.padding * 2 : 0
  Layout.fillWidth: true

  Behavior on Layout.preferredHeight {
    NumberAnimation {
      duration: 200
      easing.type: Easing.InOutQuad
    }
  }

  // Connections {
  //     target: MprisController
  //     function onArtReady() {
  //         console.log("MediaControl: Art ready, updating image source");
  //         albumArt.source = MprisController.artFilePath ? MprisController.artFilePath + "?time=" + Date.now() : "qrc:/images/default_album_art.png";
  //     }
  // }

  Loader {
    id: mediaControlLoader
    anchors.fill: parent
    anchors.margins: Widget.padding
    active: root.visible

    sourceComponent: RowLayout {
      spacing: 12

      StyledContainer {
        Layout.preferredWidth: 80
        Layout.preferredHeight: 80
        containerBorderColor: Theme.backgroundHighlight
        containerBorderWidth: 1
        radius: Appearance.borderRadius / 2

        Image {
          id: albumArt
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          source: MprisController.artFilePath ? MprisController.artFilePath + "?v=" + MprisController.artVersion : "qrc:/images/default_album_art.png"
          smooth: true
          cache: false
        }
      }

      // --- Track Info & Progress ---
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        StyledText {
          text: MprisController.trackTitle
          textSize: Appearance.fontSize - 2
          textColor: Theme.background
          elide: Text.ElideRight
        }

        StyledText {
          text: MprisController.trackArtist
          textSize: Appearance.fontSize - 4
          textColor: Theme.backgroundAlt
          elide: Text.ElideRight
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          StyledText {
            text: MprisController.formatTime(MprisController.position) /* ... */
          }

          StyledSlider {
            Layout.fillWidth: true
            enabled: MprisController.canSeek
            // BIND: Display the current progress
            value: MprisController.progress

            // ACTION: On release, tell the controller to seek
            onReleased: newValue => MprisController.setPositionByRatio(newValue)
          }

          StyledText {
            text: MprisController.formatTime(MprisController.length) /* ... */
          }
        }
      }

      // --- Playback & Volume Controls ---
      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 8

        StyledIconButton {
          iconText: "󰒮"
          onClicked: MprisController.previous()
          iconColor: Theme.foregroundAlt
          backgroundColor: Theme.backgroundHighlight
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: 25
          Layout.preferredHeight: 25
        }

        StyledIconButton {
          iconText: "󰏤"
          iconSize: Appearance.fontSize + 4
          onClicked: MprisController.togglePlay()
          iconColor: Theme.foreground
          backgroundColor: Theme.backgroundAlt
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
        }

        StyledIconButton {
          iconText: "󰒭"
          onClicked: MprisController.next()
          iconColor: Theme.foregroundAlt
          backgroundColor: Theme.backgroundHighlight
          Layout.fillWidth: false
          Layout.fillHeight: false
          Layout.preferredWidth: 25
          Layout.preferredHeight: 25
        }

        Item {
          Layout.preferredWidth: 10
        } // Spacer

        visible: MprisController.activePlayer?.volumeSupported ?? false

        // StyledText {
        //   text: "󰕾"
        //   textSize: Appearance.fontSize
        //   textColor: Theme.foregroundAlt
        // }

        // StyledSlider {
        //     Layout.preferredWidth: 80
        //
        //     value: MprisController.activePlayer ? MprisController.activePlayer.volume : 0
        //
        //     onMoved: (newValue) => {
        //         if (MprisController.activePlayer) {
        //             MprisController.activePlayer.volume = newValue;
        //         }
        //     }
        // }

        // Added volume percentage from your example
        // StyledText {
        //     // Use a ternary to avoid "NaN" if player disappears mid-render
        //     text: MprisController.activePlayer ? Math.round(MprisController.activePlayer.volume * 100) + "%" : "0%"
        //     textColor: Theme.foregroundAlt
        //     textSize: Appearance.fontSize - 4
        //     Layout.preferredWidth: 35 // Reserve space to prevent layout shifts
        //     horizontalAlignment: Text.AlignRight
        // }
      }
    }
  }
}
