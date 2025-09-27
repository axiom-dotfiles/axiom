// qs/services/MprisVolumeController.qml
pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

QtObject {
  id: root

  // --- Public API ---

  // Set this to a unique part of the player's D-Bus name, e.g., "spotify", "firefox", "vlc"
  property string targetApplication: ""

  readonly property bool playerFound: _targetPlayer !== null
  readonly property string playerName: _targetPlayer ? _targetPlayer.identity : "Not Found"
  readonly property real volume: _targetPlayer ? _targetPlayer.volume : 0.0

  // The main state property for the UI. True if player not found OR volume is effectively zero.
  readonly property bool isMuted: !playerFound || volume <= 0.001

  // --- Control Functions ---

  function setVolume(newVolume) {
    if (playerFound && _targetPlayer.canControl) {
      // Clamp volume between 0.0 and 1.0
      _targetPlayer.volume = Math.max(0.0, Math.min(1.0, newVolume));
    }
  }

  // --- Private Properties ---
  property var _targetPlayer: null

  // --- Connections & Initial Setup ---

  property Connections _mprisConnection: Connections {
    target: Mpris
    onPlayersChanged: root._updateTargetPlayer()
  }

  onTargetApplicationChanged: root._updateTargetPlayer()

  Component.onCompleted: {
    root._updateTargetPlayer();
  }

  // --- Private Functions ---

  function _updateTargetPlayer() {
    console.log("MprisVolumeController: Updating target player for application:", targetApplication);
    // If no target is specified, clear the current player and stop.
    if (targetApplication === "") {
      if (_targetPlayer !== null)
        _targetPlayer = null;
      return;
    }

    const players = Mpris.players.values;
    for (let i = 0; i < players.length; ++i) {
      const p = players[i];
      // Check if the target string is *included* in the D-Bus name.
      // This is more robust, e.g., "spotify" matches "org.mpris.MediaPlayer2.spotify"
      console.log("Dbus Name:", p.dbusName);
      console.log("identity:", p.identity);
      if (p.identity && p.identity.includes(targetApplication)) {
        console.log("MprisVolumeController: Found target player:", p.identity);
        if (_targetPlayer !== p)
          _targetPlayer = p; // Found it, we're done.
        return;
      }
    }

    // If the loop finishes without finding the player, ensure it's cleared.
    console.log("MprisVolumeController: Could not find player matching:", targetApplication);
    if (_targetPlayer !== null)
      _targetPlayer = null;
  }
}
