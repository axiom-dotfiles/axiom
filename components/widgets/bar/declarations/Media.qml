pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components.reusable
import qs.components.methods

IconTextWidget {
  id: root

  icon: MprisController.isPlaying ? "♪" : "⏸"
  text: formatTrack()

  maxTextLength: 40
  backgroundColor: MprisController.isPlaying ? Theme.yellow : Theme.bg2

  function formatTrack() {
    if (!MprisController.activePlayer)
      return "No player";
    const artist = Utils.truncate(MprisController.trackArtist, 20, "");
    const title = Utils.truncate(MprisController.trackTitle, 20, "");
    return "󰠃 " + artist + " - " + title;
  }
}
