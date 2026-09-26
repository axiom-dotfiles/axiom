pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.parts
import qs.components.content.base

// The active media player over a blurred copy of its cover: art, track
// info, a seek bar and controls. As the Media widget's popout: art beside
// the track info, the controls beneath, at a fixed size so track changes
// never resize it. As an overlay card: art beside everything when wide,
// stacked when square; a half-card-high strip drops the player name, album
// and times; a quarter slot is just the art and play/pause.
Panel {
  id: root

  readonly property bool hasPlayer: MediaManager.hasActivePlayer
  readonly property string artSource: MediaManager.artDownloaded && MediaManager.artVersion >= 0 ? "file://" + MediaManager.artFilePath : ""
  // Card only: the art beside the info and controls
  readonly property bool sideBySide: root.embedded && root.shape === "horizontal"
  // A half-card-high strip: title, artist and a slim transport only
  readonly property bool short: root.sideBySide && root.rows <= 1
  readonly property real artSize: 96
  // A seek bar is being dragged, so the popout mustn't dismiss
  property bool seeking: false

  hovered: pointerInside || root.seeking

  margins: 16
  spacing: Widget.spacing
  implicitWidth: 380

  component MediaButton: Rectangle {
    id: button
    property string icon
    property real size: Widget.height
    property bool primary: false
    signal clicked
    implicitWidth: button.size
    implicitHeight: button.size
    Layout.preferredWidth: button.size
    Layout.preferredHeight: button.size
    radius: button.size / 2
    opacity: button.enabled ? 1 : 0.4
    color: button.primary ? (buttonArea.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : buttonArea.containsMouse ? Theme.backgroundHighlight : "transparent"
    scale: buttonArea.pressed ? 0.92 : 1
    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Appearance.animFast
      }
    }
    StyledIcon {
      anchors.centerIn: parent
      text: button.icon
      textColor: button.primary ? Theme.background : Theme.foreground
      textSize: button.size * 0.5
    }
    MouseArea {
      id: buttonArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // The cover, rounded; a note when there's none
  component Art: Item {
    id: art
    property real radius: Appearance.borderRadius
    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: artMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }
      Rectangle {
        anchors.fill: parent
        color: Theme.backgroundAlt
      }
      Image {
        anchors.fill: parent
        source: root.artSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
      }
      StyledIcon {
        anchors.centerIn: parent
        visible: root.artSource === ""
        text: "music_note"
        textSize: Math.min(art.width, art.height) * 0.4
        opacity: 0.4
      }
    }
    Rectangle {
      id: artMask
      anchors.fill: parent
      radius: art.radius
      visible: false
      layer.enabled: true
    }
  }

  // Title, artist and album; the player's name above, click to cycle
  // players when there are several
  component TrackInfo: ColumnLayout {
    spacing: 2
    Item {
      visible: !root.short
      Layout.fillWidth: true
      implicitHeight: playerRow.implicitHeight
      opacity: 0.6
      RowLayout {
        id: playerRow
        anchors.fill: parent
        spacing: 4
        StyledText {
          Layout.fillWidth: true
          Layout.maximumWidth: implicitWidth
          elide: Text.ElideRight
          text: MediaManager.identity
          textSize: Appearance.fontSize - 2
        }
        StyledIcon {
          visible: MediaManager.players.length > 1
          text: "refresh"
          textSize: Appearance.fontSize - 2
        }
        Item {
          Layout.fillWidth: true
        }
      }
      MouseArea {
        anchors.fill: parent
        enabled: MediaManager.players.length > 1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          const players = MediaManager.players;
          MediaManager.selectPlayer(players[(players.indexOf(MediaManager.activePlayer) + 1) % players.length]);
        }
      }
    }
    Item {
      Layout.fillHeight: true
    }
    StyledText {
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: MediaManager.trackTitle || I18n.tr("Unknown track")
      textColor: Theme.accent
      textSize: root.short ? Appearance.fontSize : Appearance.fontSize + 3
      font.bold: true
    }
    StyledText {
      Layout.fillWidth: true
      elide: Text.ElideRight
      // Kept as a line when empty, so the popout's height never changes
      text: MediaManager.trackArtist || " "
      textSize: root.short ? Appearance.fontSize - 2 : Appearance.fontSize
    }
    StyledText {
      visible: !root.short
      Layout.fillWidth: true
      elide: Text.ElideRight
      // MediaManager doesn't surface the album, but the Mpris player does
      text: (MediaManager.activePlayer?.trackAlbum ?? "") || " "
      textSize: Appearance.fontSize - 2
      opacity: 0.6
    }
  }

  // Seek bar with times, then previous / play-pause / next
  component Transport: ColumnLayout {
    spacing: Widget.spacing / 2
    StyledSlider {
      id: seek
      Layout.fillWidth: true
      Layout.preferredHeight: root.short ? 10 : 16
      enabled: MediaManager.canSeek
      troughHeight: root.short ? 4 : 6
      handleWidth: root.short ? 10 : 14
      handleHeight: root.short ? 10 : 14
      handleRadius: root.short ? 5 : 7
      handleColor: Theme.foreground
      fillColor: Theme.accent
      // Not `value`: dragging assigns that, which would drop the binding
      targetValue: Math.min(1, Math.max(0, MediaManager.progress))
      onPressedChanged: root.seeking = pressed
      onReleased: value => MediaManager.setPositionByRatio(value)
    }
    RowLayout {
      visible: !root.short
      Layout.fillWidth: true
      StyledText {
        text: MediaManager.formatTime(seek.pressed ? seek.value * MediaManager.length : MediaManager.position)
        textSize: Appearance.fontSize - 3
        opacity: 0.6
      }
      Item {
        Layout.fillWidth: true
      }
      StyledText {
        text: MediaManager.formatTime(MediaManager.length)
        textSize: Appearance.fontSize - 3
        opacity: 0.6
      }
    }
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: root.short ? Widget.spacing : Widget.spacing * 1.5
      MediaButton {
        size: Widget.height
        icon: "skip_previous"
        enabled: MediaManager.canGoPrevious
        onClicked: MediaManager.previous()
      }
      MediaButton {
        primary: true
        size: Widget.height * (root.short ? 1.2 : 1.4)
        icon: MediaManager.isPlaying ? "pause" : "play_arrow"
        enabled: MediaManager.canTogglePlaying
        onClicked: MediaManager.togglePlayPause()
      }
      MediaButton {
        size: Widget.height
        icon: "skip_next"
        enabled: MediaManager.canGoNext
        onClicked: MediaManager.next()
      }
    }
  }

  // The cover blurred, rounded to the box and tinted with the theme's
  // background, so text reads on it in light and dark themes alike
  background: Item {
    visible: root.hasPlayer && root.artSource !== ""
    Item {
      anchors.fill: parent
      anchors.margins: root.embedded ? Appearance.borderWidth : 0
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: backdropMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }
      // Larger than the box, so the blur doesn't fade out at its edges
      Image {
        anchors.fill: parent
        anchors.margins: -48
        source: root.artSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1
          blurMax: 48
          saturation: 0.2
        }
      }
      Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.6
      }
    }
    Rectangle {
      id: backdropMask
      anchors.fill: parent
      anchors.margins: root.embedded ? Appearance.borderWidth : 0
      radius: Math.max(0, root.boxRadius - (root.embedded ? Appearance.borderWidth : 0))
      visible: false
      layer.enabled: true
    }
  }

  // Quarter card: the art with play/pause over it
  compactContent: Item {
    implicitWidth: root.width - root.pad * 2
    implicitHeight: root.height - root.pad * 2
    Art {
      anchors.fill: parent
    }
    MediaButton {
      anchors.centerIn: parent
      visible: root.hasPlayer
      primary: true
      size: Math.min(parent.width, parent.height) * 0.4
      icon: MediaManager.isPlaying ? "pause" : "play_arrow"
      onClicked: MediaManager.togglePlayPause()
    }
  }

  // --- No player ---
  Item {
    visible: !root.hasPlayer
    Layout.fillWidth: true
    Layout.fillHeight: root.embedded
    Layout.preferredHeight: root.embedded ? -1 : root.artSize
    EmptyState {
      anchors.centerIn: parent
      icon: "music_note"
      text: I18n.tr("Nothing playing")
    }
  }

  // --- Art and info (and, wide, the controls) ---
  GridLayout {
    visible: root.hasPlayer
    Layout.fillWidth: true
    Layout.fillHeight: root.embedded
    columns: root.embedded && !root.sideBySide ? 1 : 2
    columnSpacing: root.embedded ? root.pad : Widget.spacing * 1.5
    rowSpacing: Widget.spacing

    Art {
      // From the card's size, not the grid's: that depends on this
      readonly property real innerWidth: root.width - root.pad * 2
      readonly property real innerHeight: root.height - root.pad * 2
      // Beside the info, never over 40% of the width, so the text keeps room
      readonly property real side: !root.embedded ? root.artSize : root.sideBySide ? Math.min(innerHeight, innerWidth * 0.4) : Math.min(innerWidth, innerHeight * 0.5)
      Layout.preferredWidth: side
      Layout.preferredHeight: side
      Layout.alignment: root.embedded && !root.sideBySide ? Qt.AlignHCenter : root.sideBySide ? Qt.AlignVCenter : Qt.AlignTop
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumWidth: 0
      spacing: root.short ? 2 : Widget.spacing
      TrackInfo {
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
      Transport {
        visible: root.embedded
        Layout.fillWidth: true
      }
    }
  }

  // --- Popout: the controls beneath ---
  Transport {
    visible: root.hasPlayer && !root.embedded
    Layout.fillWidth: true
  }
}
