pragma Singleton
import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Io

QtObject {
  id: root

  // --- Signals ---
  signal artReady
  signal metadataUpdated

  property var activePlayer: null

  readonly property bool hasActivePlayer: activePlayer !== null
  readonly property string identity: activePlayer ? activePlayer.identity : ""
  readonly property int playbackState: activePlayer ? activePlayer.playbackState : MprisPlaybackState.Stopped
  readonly property bool isPlaying: playbackState === MprisPlaybackState.Playing
  readonly property string trackTitle: activePlayer ? activePlayer.trackTitle : "No Track Playing"
  readonly property string trackId: activePlayer ? activePlayer.trackId : ""
  readonly property string trackArtist: activePlayer ? activePlayer.trackArtist : "Unknown Artist"
  readonly property real position: activePlayer ? activePlayer.position : 0
  readonly property real length: activePlayer ? activePlayer.length : 0
  readonly property real progress: length > 0 ? (position / length) : 0
  readonly property string artUrl: activePlayer ? activePlayer.trackArtUrl : ""
  readonly property string artFileName: artUrl ? Qt.md5(artUrl) + ".jpg" : ""
  readonly property string artFilePath: artFileName ? `/tmp/quickshell-media-art/${artFileName}` : ""
  property bool artDownloaded: false
  property int artVersion: 0
  readonly property bool canPlay: activePlayer ? activePlayer.canPlay : false
  readonly property bool canPause: activePlayer ? activePlayer.canPause : false
  readonly property bool canTogglePlaying: activePlayer ? activePlayer.canTogglePlaying : false
  readonly property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
  readonly property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false
  readonly property bool canSeek: activePlayer ? activePlayer.canSeek : false
  readonly property bool isInitialized: Mpris.players !== null && Mpris.players.values.length > 0

  // --- Public ---

  function updatePosition() {
    if (hasActivePlayer && isPlaying) {
      activePlayer.positionChanged();
    }
  }

  function togglePlayPause() {
    if (hasActivePlayer && activePlayer.canTogglePlaying) {
      activePlayer.togglePlaying();
    }
  }

  function next() {
    if (hasActivePlayer && activePlayer.canGoNext) {
      activePlayer.next();
    }
  }

  function previous() {
    if (hasActivePlayer && activePlayer.canGoPrevious) {
      activePlayer.previous();
    }
  }

  function setPositionByRatio(ratio) {
    if (canSeek && length > 0) {
      ratio = Math.max(0, Math.min(1, ratio));
      const seekPosition = ratio * length;
      activePlayer.position = seekPosition;
    }
  }

  // --- Helper Functions ---

  function formatTime(seconds) {
    if (!seconds || seconds < 0)
      return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins + ":" + (secs < 10 ? "0" : "") + secs;
  }

  // --- Private Logic, Timers, and Workers ---

  // Album art downloader
  property Process _artDownloader: Process {
    running: false
    command: ["bash", "-c", `mkdir -p /tmp/quickshell-media-art && [ -f '${root.artFilePath}' ] || curl --fail -sSL '${root.artUrl}' -o '${root.artFilePath}'`]
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        console.log("Successfully downloaded album art to:", root.artFilePath);
        root.artDownloaded = true;
        root.artVersion++;
        root.artReady();
      } else {
        console.warn("Failed to download album art from:", root.artUrl, "Exit code:", exitCode);
        root.artDownloaded = false;
      }
    }
  }

  property Timer _positionTimer: Timer {
    running: root.isPlaying && root.hasActivePlayer
    interval: 500
    repeat: true
    onTriggered: {
      if (root.activePlayer)
        root.activePlayer.positionChanged();
    }
  }

  property Timer _startupPoller: Timer {
    running: true
    interval: 100
    repeat: true
    triggeredOnStart: true
    property int attempts: 0
    property int maxAttempts: 50
    property int lastPlayerCount: 0
    onTriggered: {
      attempts++;
      if (Mpris.players && Mpris.players.values.length > 0) {
        console.log("MPRIS players detected after", attempts, "attempts.");
        _updateActivePlayer();
        running = false;
      } else if (attempts >= maxAttempts) {
        console.warn("No MPRIS players detected after", attempts, "attempts. Stopping poller.");
        running = false;
      }
    }
  }

  Component.onCompleted: {
    _updateActivePlayer();
  }

  function _pickActivePlayer() {
    const playersArray = Mpris.players.values;
    console.log("Picking active MPRIS player from", playersArray.length, "available players.");
    if (!playersArray || playersArray.length === 0)
      return null;

    const playerCount = playersArray.length;

    for (let i = 0; i < playerCount; ++i) {
      const p = playersArray[i];
      if (p.dbusName && p.dbusName.indexOf("org.mpris.MediaPlayer2.spotify") !== -1) {
        return p;
      }
    }
    for (let i = 0; i < playerCount; ++i) {
      const p = playersArray[i];
      if (p.playbackState === MprisPlaybackState.Playing) {
        return p;
      }
    }
    for (let i = 0; i < playerCount; ++i) {
      const p = playersArray[i];
      if (p.canPlay) {
        return p;
      }
    }
    return playersArray[0];
  }

  function _updateActivePlayer() {
    console.log("Updating active MPRIS player...-----------------------------------");
    const newPlayer = _pickActivePlayer();
    if (activePlayer !== newPlayer) {
      activePlayer = newPlayer;
    }
  }
}
