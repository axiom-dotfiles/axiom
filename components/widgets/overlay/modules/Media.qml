pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.reusable
import qs.components.widgets.common

StyledContainer {
  id: root
  anchors.fill: parent
  backgroundColor: Theme.background
  borderColor: Theme.foreground
  borderWidth: Menu.cardBorderWidth
  visible: true
  clip: true

  Loader {
    id: mediaControlLoader
    anchors.fill: parent
    anchors.margins: Widget.padding
    active: root.visible && MprisController.hasActivePlayer

    sourceComponent: Item {
      implicitWidth: parent.width
      implicitHeight: parent.height

      // Title and Artist - Top Left
      ColumnLayout {
        id: textInfo
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 4

        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackTitle
          textSize: Appearance.fontSize - 2
          textColor: Theme.foreground
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: MprisController.trackArtist
          textSize: Appearance.fontSize - 4
          textColor: Theme.foregroundAlt
          elide: Text.ElideRight
        }
      }

      StyledContainer {
        id: albumArtContainer
        anchors.right: parent.right
        anchors.top: parent.top
        width: parent.width * 0.15
        height: width
        borderColor: Theme.backgroundHighlight
        borderWidth: 1
        borderRadius: Appearance.borderRadius / 2

        Image {
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          source: MprisController.artUrl ? MprisController.artUrl : ""
          smooth: true
          asynchronous: true
          cache: true

          onStatusChanged: {
            if (status === Image.Error) {
              source = "qrc:/images/default_album_art.png"
            }
          }
        }
      }

      // Circular Progress - Center
      Item {
        id: circleContainer
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.55
        height: width

        PercentageCircle {
          anchors.fill: parent
          percentage: MprisController.progress * 100
          iconText: MprisController.isPlaying ? "󰏤" : "󰐊"
          fillColor: Theme.cyan

          MouseArea {
            anchors.fill: parent
            onClicked: MprisController.togglePlayPause()
          }

          Timer {
            interval: 1000
            running: MprisController.isPlaying && MprisController.hasActivePlayer
            repeat: true
            onTriggered: {
              MprisController.updatePosition()
            }
          }

          Connections {
            target: MprisController
            function onMetadataUpdated() {
              MprisController.updatePosition()
            }
          }
        }
      }

      // Control Buttons - Bottom
      RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        StyledIconButton {
          iconText: "󰒮"
          onClicked: MprisController.previous()
          iconColor: Theme.foregroundAlt
          backgroundColor: Theme.backgroundHighlight
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
        }

        StyledIconButton {
          iconText: MprisController.isPlaying ? "󰏤" : "󰐊"
          onClicked: MprisController.togglePlayPause()
          iconColor: MprisController.isPlaying ? Theme.background : Theme.foreground
          backgroundColor: MprisController.isPlaying ? Theme.cyan : Theme.background
          Layout.preferredWidth: 48
          Layout.preferredHeight: 48
        }

        StyledIconButton {
          iconText: "󰒭"
          onClicked: MprisController.next()
          iconColor: Theme.foregroundAlt
          backgroundColor: Theme.backgroundHighlight
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
        }
      }
    }
  }
}
