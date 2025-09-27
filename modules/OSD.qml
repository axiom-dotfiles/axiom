pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components.widgets.popouts
import qs.components.reusable
import qs.config
import qs.services

Item {
  id: osdRoot
  anchors.fill: parent

  property bool shouldShowOsd: false
  property real hideTimeout: 1000

  Connections {
    target: Audio

    function onVolumeChanged() {
      osdRoot.shouldShowOsd = true;
      hideTimer.restart();
    }

    function onMutedChanged() {
      osdRoot.shouldShowOsd = true;
      hideTimer.restart();
    }
  }

  function onVisibilityChanged() {
    osdRoot.shouldShowOsd = true;
    hideTimer.restart();
  }

  Timer {
    id: hideTimer
    interval: osdRoot.hideTimeout
    repeat: false
    onTriggered: osdRoot.shouldShowOsd = false
  }

  EdgePopup {
    id: root
    panelId: "volumeOSD"

    edge: EdgePopup.Edge.Bottom
    position: 0.5
    active: false
    enableTrigger: true
    property bool shouldShowOsd: osdRoot.shouldShowOsd
    triggerWidth: 5
    closeOnMouseExit: false
    closeOnClickOutside: true
    focusable: false
    aboveWindows: true
    edgeMargin: Config.containerOffset + Appearance.borderWidth * 2 + 3

    animationDuration: 200
    easingType: Easing.OutQuad

    onActiveChanged: {
      if (active) {
        osdRoot.shouldShowOsd = true;
        hideTimer.restart();
      }
    }

    onShouldShowOsdChanged: {
      if (shouldShowOsd) {
        root.active = true;
        hideTimer.restart();
      } else {
        root.active = false;
        hideTimer.stop();
      }
    }

    StyledContainer {
      containerColor: Theme.backgroundAlt
      containerBorderColor: Theme.accent
      containerBorderWidth: Appearance.borderWidth
      containerRadius: Appearance.borderRadius

      property bool hovered: false

      implicitWidth: 350
      implicitHeight: 220
      MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
          parent.hovered = true;
          osdRoot.shouldShowOsd = true;
          hideTimer.stop();
        }
        onExited: {
          parent.hovered = false;
          hideTimer.restart();
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 20

        PipewireVolumeBar {
          targetApplication: "zen-bin"
          orientation: Qt.Vertical
          iconSource: ""
          onVisibilityChanged: {
            osdRoot.shouldShowOsd = true;
            hideTimer.restart();
          }
        }

        PipewireVolumeBar {
          targetApplication: "electron"
          orientation: Qt.Vertical
          iconSource: ""
          onVisibilityChanged: {
            osdRoot.shouldShowOsd = true;
            hideTimer.restart();
          }
        }

        PipewireVolumeBar {
          targetApplication: "master"
          orientation: Qt.Vertical
          iconSource: ""
          onVisibilityChanged: {
            osdRoot.shouldShowOsd = true;
            hideTimer.restart();
          }
        }

        PipewireVolumeBar {
          targetApplication: "youtube-music"
          orientation: Qt.Vertical
          iconSource: ""
          onVisibilityChanged: {
            osdRoot.shouldShowOsd = true;
            hideTimer.restart();
          }
        }

        PipewireVolumeBar {
          orientation: Qt.Vertical
          volume: Audio.volume
          isMuted: Audio.muted
          iconSource: {
            if (Audio.muted || Audio.volume === 0)
              return "";
            if (Audio.volume > 0.4)
              return "";
            return "";
          }
        }
      }
    }
  }
}
