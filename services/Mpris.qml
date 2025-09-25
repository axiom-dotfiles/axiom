pragma Singleton
import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Io

QtObject {
    id: root

    // --- Signals ---
    signal artReady()

    // --- Private Properties ---
    property var activePlayer: null

    // --- Public API ---

    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property string identity: activePlayer ? activePlayer.identity : ""
    readonly property int playbackState: activePlayer ? activePlayer.playbackState : MprisPlaybackState.Stopped
    readonly property bool isPlaying: playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: activePlayer ? activePlayer.trackTitle : "No Track Playing"
    readonly property string trackArtist: activePlayer ? activePlayer.trackArtist : "Unknown Artist"
    readonly property real position: activePlayer ? activePlayer.position : 0
    readonly property real length: activePlayer ? activePlayer.length : 0
    readonly property real progress: length > 0 ? (position / length) : 0
    readonly property string artUrl: activePlayer ? activePlayer.trackArtUrl : ""
    readonly property string artFileName: artUrl ? Qt.md5(artUrl) + ".jpg" : ""
    readonly property string artFilePath: artFileName ? `/tmp/quickshell-media-art/${artFileName}` : ""
    property bool artDownloaded: false
    readonly property bool canPlay: activePlayer ? activePlayer.canPlay : false
    readonly property bool canPause: activePlayer ? activePlayer.canPause : false
    readonly property bool canTogglePlaying: activePlayer ? activePlayer.canTogglePlaying : false
    readonly property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
    readonly property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false
    readonly property bool canSeek: activePlayer ? activePlayer.canSeek : false

    // --- Control Functions ---

    function togglePlayPause() {
        if (hasActivePlayer && activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying()
        }
    }

    function next() {
        if (hasActivePlayer && activePlayer.canGoNext) {
            activePlayer.next()
        }
    }

    function previous() {
        if (hasActivePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous()
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
        if (!seconds || seconds < 0) return "0:00"
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // --- Private Logic, Timers, and Workers ---

    // This hidden repeater monitors state changes for *every* player
    // CHANGED: Assigned to a property to give it a "home" inside the QtObject.
    property var _playerStateRepeater: Repeater {
        model: Mpris.players
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() { _updateActivePlayer() }
        }
    }

    // Album art downloader
    // CHANGED: Assigned to a property.
    property Process _artDownloader: Process {
        running: false
        command: ["bash", "-c", `mkdir -p /tmp/quickshell-media-art && [ -f '${root.artFilePath}' ] || curl --fail -sSL '${root.artUrl}' -o '${root.artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.artDownloaded = true
                root.artReady()
            } else {
                console.warn("Failed to download album art from:", root.artUrl, "Exit code:", exitCode)
                root.artDownloaded = false
            }
        }
    }

    // Internal timer for smooth position updates
    // CHANGED: Assigned to a property.
    property Timer _positionTimer: Timer {
        running: root.isPlaying && root.hasActivePlayer
        interval: 500
        repeat: true
        onTriggered: {
            if(root.activePlayer) root.activePlayer.positionChanged()
        }
    }

    // --- Connections & Initial Setup ---

    // CHANGED: Assigned to a property.
    property Connections _playersConnection: Connections {
        target: Mpris.players
        function onCountChanged() {
            _updateActivePlayer()
        }
    }

    // This handler manages the art downloader process
    onActivePlayerChanged: {
        if (artUrl) {
            artDownloaded = false
            // CHANGED: Use the property name to access the Process object
            _artDownloader.running = true
        } else {
            artDownloaded = false
        }
    }

    Component.onCompleted: {
        _updateActivePlayer()
    }

    // --- Private Functions ---

    function _pickActivePlayer() {
        const playerCount = Mpris.players.count;
        if (playerCount === 0) return null;

        for (let i = 0; i < playerCount; ++i) {
            const p = Mpris.players.get(i);
            if (p.dbusName && p.dbusName.indexOf("org.mpris.MediaPlayer2.spotify") !== -1) {
                return p;
            }
        }
        for (let i = 0; i < playerCount; ++i) {
            const p = Mpris.players.get(i);
            if (p.playbackState === MprisPlaybackState.Playing) {
                return p;
            }
        }
        for (let i = 0; i < playerCount; ++i) {
            const p = Mpris.players.get(i);
            if (p.canPlay) {
                return p;
            }
        }
        return Mpris.players.get(0);
    }

    function _updateActivePlayer() {
        const newPlayer = _pickActivePlayer();
        if (activePlayer !== newPlayer) {
            activePlayer = newPlayer;
        }
    }
}
