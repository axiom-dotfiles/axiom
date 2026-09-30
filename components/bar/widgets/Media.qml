pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config
import qs.components.reusable
import qs.components.methods
import qs.components.hosts.popout

BarWidget {
  id: root

  // Sized to the track, shrinking (the label elides) down to just the icon
  // when the bar is crowded. The popout centres on the widget when it
  // opens and stays put while open, so a resize doesn't move it.
  // `layout.size` caps it.
  readonly property string sizePolicy: "elastic"
  readonly property real minimumSize: iconText.iconLength + iconText.padding * 2

  implicitWidth: iconText.implicitWidth
  implicitHeight: iconText.implicitHeight

  IconTextWidget {
    id: iconText
    anchors.fill: parent

    isVertical: root.isVertical
    crossSize: root.barConfig.widgetSize
    // Sized by the bar, as BarIconWidget does
    padding: root.barConfig.widgetPadding
    radius: root.barConfig.radius
    fontSize: root.barConfig.fontSize
    spacing: root.barConfig.widgetSpacing * 1.5

    // The artist icon goes with the state icon, before the label
    icon: (MediaManager.isPlaying ? "music_note" : "pause") + (root.artist ? (root.isVertical ? "\n" : " ") + "artist" : "")
    text: root.formatTrack()

    backgroundColor: Theme.resolveColor(MediaManager.isPlaying ? root.properties.playingColor : root.properties.pausedColor)
    foregroundColor: Theme.resolveColor(root.properties.foregroundColor)
  }

  // The artist shown before the title, or "" when there's none to show
  readonly property string artist: MediaManager.activePlayer && root.properties.showArtist ? Utils.truncate(MediaManager.trackArtist, root.properties.artistLength, "") : ""

  function formatTrack() {
    if (!MediaManager.activePlayer)
      return root.properties.idleText;
    if (!root.artist)
      return MediaManager.trackTitle;
    return root.artist + " - " + MediaManager.trackTitle;
  }

  PopoutAnchor {
    id: anchor
    popouts: root.popouts
    panel: root.panel
    popoutName: "NowPlaying"
    active: root.properties.showPopout
    openDelay: 150
    pinWhileOpen: true
  }
}
