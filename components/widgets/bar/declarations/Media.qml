import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import qs.config
import qs.components.widgets.reusable

IconTextWidget {
  id: root

  icon: Mpris.isPlaying ? "♪" : "⏸"
  text: formatTrack()

  maxTextLength: 30
  backgroundColor: Mpris.isPlaying ? Theme.accent : Theme.backgroundHighlight

  function formatTrack() {
    if (!Mpris.activePlayer)
      return "No player";
    const artist = Mpris.trackArtist;
    const title = Mpris.trackTitle;
    return artist + " - " + title;
  }

}
