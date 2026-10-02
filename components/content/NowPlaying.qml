pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.parts
import qs.components.content.base

// The active media player over a blurred copy of its cover: art, track
// info, a seek bar and controls. As the Media widget's popout: art beside
// the track info, the controls beneath, at a fixed size so track changes
// never resize it. As an overlay card: art beside everything when wide,
// stacked when square or tall; a short slot drops the player name, album
// and times; a tall wide one has larger text and controls, centred beside
// the art; a strip is one row (art, title, artist and the buttons); a
// compact card is just the art and play/pause.
Panel {
  id: root

  readonly property bool hasPlayer: MediaManager.hasActivePlayer
  readonly property string artSource: MediaManager.artDownloaded && MediaManager.artVersion >= 0 ? "file://" + MediaManager.artFilePath : ""
  // Card only: the art beside the info and controls
  readonly property bool sideBySide: root.embedded && root.shape === "horizontal"
  // A short wide slot: title, artist and a slim transport only
  readonly property bool short: root.sideBySide && root.height < Appearance.fontSize * 13
  // A tall wide slot (a big lock screen or page card): larger text and
  // controls, centred beside the art
  readonly property bool large: root.sideBySide && root.innerHeight >= Appearance.fontSize * 20
  // A strip: one row of small art, the track and the buttons
  readonly property bool mini: root.embedded && !root.compact && root.height < Appearance.fontSize * 7
  readonly property real artSize: 96
  // A seek bar is being dragged, so the popout mustn't dismiss
  property bool seeking: false

  hovered: pointerInside || root.seeking

  fullMinWidth: Appearance.fontSize * 10
  fullMinHeight: Appearance.fontSize * 3.5

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
    color: button.primary ? (buttonArea.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : buttonArea.containsMouse ? Theme.backgroundHighlight : Qt.alpha(Theme.backgroundHighlight, 0)
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
    property real radius: Widget.radius
    ClippingRectangle {
      anchors.fill: parent
      radius: art.radius
      color: Theme.backgroundAlt
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
          Layout.maximumWidth: Math.ceil(implicitWidth)
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
      textSize: root.large ? Appearance.fontSize * 2 : root.short ? Appearance.fontSize : Appearance.fontSize + 3
      font.bold: true
    }
    StyledText {
      Layout.fillWidth: true
      elide: Text.ElideRight
      // Kept as a line when empty, so the popout's height never changes
      text: MediaManager.trackArtist || " "
      textSize: root.large ? Appearance.fontSize + 4 : root.short ? Appearance.fontSize - 2 : Appearance.fontSize
    }
    StyledText {
      visible: !root.short
      Layout.fillWidth: true
      elide: Text.ElideRight
      // MediaManager doesn't surface the album, but the Mpris player does
      text: (MediaManager.activePlayer?.trackAlbum ?? "") || " "
      textSize: root.large ? Appearance.fontSize : Appearance.fontSize - 2
      opacity: 0.6
    }
  }

  // Seek bar with times, then previous / play-pause / next
  component Transport: ColumnLayout {
    spacing: Widget.spacing / 2
    StyledSlider {
      id: seek
      Layout.fillWidth: true
      Layout.preferredHeight: root.short ? 10 : root.large ? 20 : 16
      enabled: MediaManager.canSeek
      troughHeight: root.short ? 4 : root.large ? 8 : 6
      handleWidth: root.short ? 10 : root.large ? 18 : 14
      handleHeight: root.short ? 10 : root.large ? 18 : 14
      handleRadius: root.short ? 5 : root.large ? 9 : 7
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
        textSize: root.large ? Appearance.fontSize - 1 : Appearance.fontSize - 3
        opacity: 0.6
      }
      Item {
        Layout.fillWidth: true
      }
      StyledText {
        text: MediaManager.formatTime(MediaManager.length)
        textSize: root.large ? Appearance.fontSize - 1 : Appearance.fontSize - 3
        opacity: 0.6
      }
    }
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: root.short ? Widget.spacing : Widget.spacing * 1.5
      MediaButton {
        size: Widget.height * (root.large ? 1.4 : 1)
        icon: "skip_previous"
        enabled: MediaManager.canGoPrevious
        onClicked: MediaManager.previous()
      }
      MediaButton {
        primary: true
        size: Widget.height * (root.short ? 1.2 : root.large ? 2 : 1.4)
        icon: MediaManager.isPlaying ? "pause" : "play_arrow"
        enabled: MediaManager.canTogglePlaying
        onClicked: MediaManager.togglePlayPause()
      }
      MediaButton {
        size: Widget.height * (root.large ? 1.4 : 1)
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
    ClippingRectangle {
      anchors.fill: parent
      anchors.margins: root.embedded ? Appearance.borderWidth : 0
      radius: Math.max(0, root.boxRadius - (root.embedded ? Appearance.borderWidth : 0))
      color: "transparent"
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
  }

  // Compact: the art with play/pause over it
  compactContent: Item {
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
      maxWidth: parent.width
      availableHeight: root.embedded ? parent.height : -1
      icon: "music_note"
      text: I18n.tr("Nothing playing")
    }
  }

  // --- A strip: art, track and buttons in a row ---
  RowLayout {
    visible: root.hasPlayer && root.mini
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Widget.spacing
    // Room for previous and next beside play/pause
    readonly property bool wide: root.width >= Appearance.fontSize * 22

    Art {
      readonly property real side: root.innerHeight
      visible: side >= 24
      Layout.preferredWidth: side
      Layout.preferredHeight: side
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 0
      StyledText {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: MediaManager.trackTitle || I18n.tr("Unknown track")
        textColor: Theme.accent
        font.bold: true
      }
      StyledText {
        visible: root.innerHeight >= Appearance.fontSize * 2.6
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: MediaManager.trackArtist
        textSize: Appearance.fontSize - 2
        opacity: 0.8
      }
    }
    MediaButton {
      visible: parent.wide
      size: Math.min(Widget.height, root.innerHeight)
      icon: "skip_previous"
      enabled: MediaManager.canGoPrevious
      onClicked: MediaManager.previous()
    }
    MediaButton {
      primary: true
      size: Math.min(Widget.height * 1.2, root.innerHeight)
      icon: MediaManager.isPlaying ? "pause" : "play_arrow"
      enabled: MediaManager.canTogglePlaying
      onClicked: MediaManager.togglePlayPause()
    }
    MediaButton {
      visible: parent.wide
      size: Math.min(Widget.height, root.innerHeight)
      icon: "skip_next"
      enabled: MediaManager.canGoNext
      onClicked: MediaManager.next()
    }
  }

  // --- Art and info (and, wide, the controls) ---
  GridLayout {
    visible: root.hasPlayer && !root.mini
    Layout.fillWidth: true
    Layout.fillHeight: root.embedded
    columns: root.embedded && !root.sideBySide ? 1 : 2
    columnSpacing: root.embedded ? root.pad : Widget.spacing * 1.5
    rowSpacing: Widget.spacing

    Art {
      // From the card's size, not the grid's: that depends on this
      // Beside the info, never over 40% of the width, so the text keeps room;
      // stacked, whatever height the info and controls leave (a small card
      // would otherwise push them out of the box)
      readonly property real side: !root.embedded ? root.artSize : root.sideBySide ? Math.min(root.innerHeight, root.innerWidth * 0.4) : Math.max(0, Math.min(root.innerWidth, root.innerHeight * 0.5, root.innerHeight - details.implicitHeight - Widget.spacing))
      visible: side >= 32
      Layout.preferredWidth: side
      Layout.preferredHeight: side
      Layout.alignment: root.embedded && !root.sideBySide ? Qt.AlignHCenter : root.sideBySide ? Qt.AlignVCenter : Qt.AlignTop
    }

    ColumnLayout {
      id: details
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumWidth: 0
      spacing: root.short ? 2 : Widget.spacing
      // Large: the track and controls centred, not spread down the side
      Item {
        visible: root.large
        Layout.fillHeight: true
      }
      TrackInfo {
        Layout.fillWidth: true
        Layout.fillHeight: !root.large
      }
      Transport {
        visible: root.embedded
        Layout.fillWidth: true
        Layout.topMargin: root.large ? Widget.spacing : 0
      }
      Item {
        visible: root.large
        Layout.fillHeight: true
      }
    }
  }

  // --- Popout: the controls beneath ---
  Transport {
    visible: root.hasPlayer && !root.embedded
    Layout.fillWidth: true
  }
}
