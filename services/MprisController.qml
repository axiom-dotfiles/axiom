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

  // --- Properties we can pass through ---
  readonly property bool hasActivePlayer: activePlayer !== null
  readonly property bool isPlaying: playbackState === MprisPlaybackState.Playing
  readonly property int playbackState: activePlayer ? activePlayer.playbackState : MprisPlaybackState.Stopped

  // --- Properties we fully control to be explicit ---
  property string identity: ""
  property string trackTitle: ""
  property string trackId: ""
  property string trackArtist: ""
  property real position: 0
  property real length: 0
  property real progress: length > 0 ? (position / length) : 0

  // --- Everything else ---
  property string artUrl: activePlayer ? activePlayer.trackArtUrl : ""
  property string artFileName: artUrl ? Qt.md5(artUrl) + ".jpg" : ""
  property string artFilePath: artFileName ? `/tmp/quickshell-media-art/${artFileName}` : ""
  property bool artDownloaded: false
  property int artVersion: 0
  property bool canPlay: activePlayer ? activePlayer.canPlay : false
  property bool canPause: activePlayer ? activePlayer.canPause : false
  property bool canTogglePlaying: activePlayer ? activePlayer.canTogglePlaying : false
  property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
  property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false
  property bool canSeek: activePlayer ? activePlayer.canSeek : false
  property bool isInitialized: Mpris.players !== null && Mpris.players.values.length > 0

  // --- Public ---
  function logCurrentSongProperties() {
    if (!hasActivePlayer) {
      console.log("No active MPRIS player.");
      return;
    }
    console.log("Active MPRIS Player Properties:");
    console.log("  Identity:", identity);
    console.log("  Playback State:", playbackState === MprisPlaybackState.Playing ? "Playing" : (playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped"));
    console.log("  Track Title:", trackTitle);
    console.log("  Track Artist:", trackArtist);
    console.log("  Track ID:", trackId);
    console.log("  Position (ms):", position);
    console.log("  Length (ms):", length);
    console.log("  Progress:", (progress * 100).toFixed(2) + "%");
    console.log("  Art URL:", artUrl);
    console.log("  Can Play:", canPlay);
    console.log("  Can Pause:", canPause);
    console.log("  Can Toggle Playing:", canTogglePlaying);
    console.log("  Can Go Next:", canGoNext);
    console.log("  Can Go Previous:", canGoPrevious);
    console.log("  Can Seek:", canSeek);
  }

  function updateAllMetadata() {
    if (!hasActivePlayer) {
      console.log("No active MPRIS player to update metadata from.");
      return;
    }
    identity = activePlayer.identity || "";
    trackTitle = activePlayer.trackTitle || "";
    trackId = activePlayer.trackId || "";
    trackArtist = activePlayer.trackArtist || "";
    length = activePlayer.length || 0;
    root.updatePosition();
    root.logCurrentSongProperties();
    root.metadataUpdated();
  }

  function updatePosition() {
    if (hasActivePlayer && isPlaying) {
      activePlayer.positionChanged();
      // Potential bug with youtube music AUR package and mpris
      // Simply requires a skip to sync positions
      if (activePlayer.position > length) {
        position = activePlayer.position - length;
        progress = length > 0 ? (position / length) : 0;
      } else {
        position = activePlayer.position;
        progress = length > 0 ? (position / length) : 0;
      }
    }
  }

  property Connections _mprisConnections: Connections {
    target: activePlayer
    ignoreUnknownSignals: true
    function onTrackTitleChanged() {
      console.log("MprisController: Track ID changed.");
      root.updateAllMetadata();
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
        updateAllMetadata();
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
