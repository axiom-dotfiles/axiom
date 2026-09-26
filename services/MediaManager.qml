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

  // --- Properties we fully control to be explicit, partially due to a bug with YT Music ---
  property real position: 0
  property real length: 0
  readonly property real progress: length > 0 ? (position / length) : 0

  // --- Everything else ---
  property string identity: activePlayer ? activePlayer.identity : ""
  property string trackTitle: activePlayer ? activePlayer.trackTitle : ""
  property string trackArtist: activePlayer ? activePlayer.trackArtist : ""
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

  // --- Art download trigger ---
  // artUrl is already reactively derived from activePlayer.trackArtUrl, so
  // this single handler fires for both "track changed on the same player"
  // and "active player switched" — the two cases that should invalidate
  // whatever art is currently shown. Without this, _artDownloader was
  // fully wired up (command, exit handling, artReady/artVersion bump) but
  // nothing ever actually set it running, so no art ever downloaded.
  onArtUrlChanged: {
    // Reset immediately so the UI falls back to its placeholder rather
    // than briefly showing the previous track's art under the new one.
    root.artDownloaded = false;
    // Coalesced: players often clear the URL and set the new one in quick
    // succession on a track change
    Qt.callLater(root._fetchArt);
  }

  // The URL the running download is for; a result for any other URL is stale
  property string _artFetchUrl: ""

  // Built here from the current values (not a binding): bindings on artUrl
  // may not have updated yet inside onArtUrlChanged, which used to start
  // curl with the previous, often empty, URL
  function _fetchArt() {
    const url = root.artUrl;
    if (!url || url === root._artFetchUrl && root._artDownloader.running)
      return;
    root._artFetchUrl = url;
    // URL and path go in as arguments ($1, $2), never into the script
    // text; downloads land in .part and are renamed, so an interrupted one
    // is never mistaken for a cached file
    root._artDownloader.command = ["bash", "-c", 'mkdir -p "$(dirname "$2")" && { [ -s "$2" ] || { curl --fail -sSL --max-time 15 "$1" -o "$2.part" && mv -f "$2.part" "$2"; }; }', "art", url, root.artFilePath];
    root._artDownloader.running = false;
    root._artDownloader.running = true;
  }

  // --- Public ---
  function logCurrentSongProperties() {
    if (!hasActivePlayer) {
      console.log("[MediaManager] No active MPRIS player.");
      return;
    }
    console.log("[MediaManager] Active MPRIS Player Properties:");
    console.log("[MediaManager]   Identity:", identity);
    console.log("[MediaManager]   Playback State:", playbackState === MprisPlaybackState.Playing ? "Playing" : (playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped"));
    console.log("[MediaManager]   Track Title:", trackTitle);
    console.log("[MediaManager]   Track Artist:", trackArtist);
    console.log("[MediaManager]   Position (ms):", position);
    console.log("[MediaManager]   Length (ms):", length);
    console.log("[MediaManager]   Progress:", (progress * 100).toFixed(2) + "%");
    console.log("[MediaManager]   Art URL:", artUrl);
    console.log("[MediaManager]   Can Play:", canPlay);
    console.log("[MediaManager]   Can Pause:", canPause);
    console.log("[MediaManager]   Can Toggle Playing:", canTogglePlaying);
    console.log("[MediaManager]   Can Go Next:", canGoNext);
    console.log("[MediaManager]   Can Go Previous:", canGoPrevious);
    console.log("[MediaManager]   Can Seek:", canSeek);
  }

  function updateAllMetadata() {
    if (!hasActivePlayer) {
      console.log("[MediaManager] No active MPRIS player to update metadata from.");
      return;
    }
    length = activePlayer.length || 0;
    root.updatePosition();
    // root.logCurrentSongProperties();
    root.metadataUpdated();
  }

  function updatePosition() {
    if (hasActivePlayer) {
      activePlayer.positionChanged();
      // Potential bug with youtube music AUR package and mpris
      // Simply requires a skip to sync positions
      if (activePlayer.position > length && length > 0) {
        position = activePlayer.position - length;
      } else {
        position = activePlayer.position;
      }
    }
  }

  property Connections _mprisConnections: Connections {
    target: activePlayer
    ignoreUnknownSignals: true
    function onTrackTitleChanged() {
      root.updateAllMetadata();
    }
    // Some players report the length after the title
    function onLengthChanged() {
      root.length = root.activePlayer.length || 0;
    }
  }

  onActivePlayerChanged: {
    if (activePlayer)
      updateAllMetadata();
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

  // Media keys (keybind actions mediaPlayPause, ...), for the active player
  property IpcHandler _ipc: IpcHandler {
    target: "media"

    function playPause(): void {
      root.togglePlayPause();
    }

    function next(): void {
      root.next();
    }

    function previous(): void {
      root.previous();
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
    onExited: (exitCode, exitStatus) => {
      const url = root._artFetchUrl;
      root._artFetchUrl = "";
      // The track moved on while this was downloading: fetch the new one
      if (url !== root.artUrl) {
        Qt.callLater(root._fetchArt);
        return;
      }
      if (exitCode === 0) {
        console.log("[MediaManager] Album art ready:", root.artFilePath);
        root.artDownloaded = true;
        root.artVersion++;
        root.artReady();
      } else {
        console.warn("[MediaManager] Failed to download album art from:", url, "Exit code:", exitCode);
        root.artDownloaded = false;
      }
    }
  }

  property Timer _positionTimer: Timer {
    running: root.isPlaying && root.hasActivePlayer
    interval: 500
    repeat: true
    // Copies the position into `position` too, so every consumer sees it
    // advance (not only ones that call updatePosition themselves)
    onTriggered: root.updatePosition()
  }

  // Players already running at startup (later ones: onPlayersChanged)
  Component.onCompleted: {
    if (root.players.length > 0) {
      root._updateActivePlayer();
      root.updateAllMetadata();
    }
  }

  function _pickActivePlayer() {
    const playersArray = Mpris.players.values;
    console.log("[MediaManager] Picking active MPRIS player from", playersArray.length, "available players.");
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
    const newPlayer = _pickActivePlayer();
    if (activePlayer !== newPlayer) {
      activePlayer = newPlayer;
    }
  }

  // Every player, for player switchers
  readonly property var players: Mpris.players?.values ?? []
  // A player the user picked; kept until it goes away
  property var _pinnedPlayer: null

  function selectPlayer(player) {
    root._pinnedPlayer = player;
    root.activePlayer = player;
    updateAllMetadata();
  }

  // Players come and go after startup: keep a pinned player while it
  // exists, otherwise re-pick (and drop a player that has vanished)
  onPlayersChanged: {
    if (root._pinnedPlayer && root.players.includes(root._pinnedPlayer))
      return;
    root._pinnedPlayer = null;
    _updateActivePlayer();
    if (root.activePlayer)
      updateAllMetadata();
  }
}
