// qs/components/reusable/PipewireVolumeBar.qml
pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import Quickshell.Services.Pipewire

Item {
  id: root

  // -- Signals --
  signal visibilityChanged(real volume)

  // -- Public API --
  // Substrings of the app streams to control, in priority order: the bar
  // shows the first matching stream (by the first app with one) and a
  // change sets every matching stream
  property var targetApps: []
  // Instead the first stream that no excludedApps entry matches
  property bool otherApps: false
  property var excludedApps: []
  property bool useSystemVolume: false
  property alias orientation: bar.orientation
  property alias iconSource: bar.iconSource
  property alias showPercent: bar.showPercent
  property alias scrollStep: bar.scrollStep

  readonly property bool nodeFound: !useSystemVolume && _targetNode !== null && _targetNode.ready && _targetNode.audio
  property real volume: useSystemVolume ? AudioManager.volume : (nodeFound ? _targetNode.audio.volume : 0.0)
  property bool isMuted: useSystemVolume ? AudioManager.muted : (!nodeFound || _targetNode.audio.muted)

  // -- Configurable Appearance --
  // null

  // -- Implementation --
  implicitWidth: bar.implicitWidth
  implicitHeight: bar.implicitHeight

  // Every stream being controlled; _targetNode (the first) is the one shown
  property var _targetNodes: []
  readonly property var _targetNode: _targetNodes.length > 0 ? _targetNodes[0] : null
  // The controlled streams' levels, so a change on any of them shows the
  // bar; _nodeKey tells a level change from the set of streams changing
  readonly property string _levels: _targetNodes.map(n => n.audio ? `${n.audio.volume}:${n.audio.muted}` : "").join(",")
  property string _nodeKey: ""

  // All candidate audio-stream nodes, kept persistently bound so their
  // .properties are populated (and stay populated) well before we need
  // to search them. Binding is async, so we can't just bind on demand.
  readonly property var _audioStreams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

  PwObjectTracker {
    objects: root._audioStreams.concat(root._targetNodes)
  }

  // Re-run the search whenever any individual candidate node finishes
  // binding (node.ready flips true). This is what actually fixes the
  // race: tracking a node only *requests* a bind, it doesn't complete
  // it synchronously.
  Instantiator {
    model: root._audioStreams
    delegate: Item {
      id: streamWatcher
      required property var modelData
      Connections {
        target: streamWatcher.modelData
        function onReadyChanged() {
          if (streamWatcher.modelData.ready) {
            root._updateTargetNode();
          }
        }
      }
    }
  }

  StyledVolumeBar {
    id: bar
    anchors.fill: parent
    volumeLevel: root.volume
    isMuted: root.isMuted
    enabled: root.nodeFound || root.useSystemVolume
    onVolumeChanged: root.setVolume(newVolume)
  }

  onVolumeChanged: {
    if (root.useSystemVolume)
      root.visibilityChanged(root.volume);
  }

  on_LevelsChanged: {
    const key = root._keyOf(root._targetNodes);
    if (key === root._nodeKey)
      root.visibilityChanged(root.volume);
    root._nodeKey = key;
  }

  function setVolume(newVolume) {
    const clamped = Math.max(0.0, Math.min(1.0, newVolume));
    if (useSystemVolume) {
      AudioManager.setVolume(clamped);
      return;
    }
    _targetNodes.forEach(n => {
      if (n.ready && n.audio)
        n.audio.volume = clamped;
    });
  }

  function toggleMute() {
    if (useSystemVolume) {
      AudioManager.toggleMute();
      return;
    }
    if (!nodeFound)
      return;
    const muted = !_targetNode.audio.muted;
    _targetNodes.forEach(n => {
      if (n.ready && n.audio)
        n.audio.muted = muted;
    });
  }

  // Config changes (a reload, another saved config) pick the stream again
  onTargetAppsChanged: _updateTargetNode()
  onOtherAppsChanged: {
    if (Pipewire.ready)
      _updateTargetNode();
  }
  onExcludedAppsChanged: {
    if (Pipewire.ready)
      _updateTargetNode();
  }
  onUseSystemVolumeChanged: {
    if (Pipewire.ready)
      _updateTargetNode();
  }

  Component.onCompleted: {
    if (Pipewire.ready) {
      _updateTargetNode();
    }
  }

  Connections {
    target: Pipewire.nodes
    function onObjectInsertedPost(object, index) {
      if (Pipewire.ready) {
        root._updateTargetNode();
      }
    }
    function onObjectRemovedPost(object, index) {
      if (Pipewire.ready) {
        root._updateTargetNode();
      }
    }
  }

  Connections {
    target: Pipewire
    function onReadyChanged() {
      if (Pipewire.ready) {
        root._updateTargetNode();
      }
    }
  }

  function _keyOf(nodes) {
    return nodes.map(n => n.id).join(",");
  }

  function _setTargetNodes(nodes) {
    const key = _keyOf(nodes);
    if (key === _keyOf(_targetNodes))
      return;
    // on_LevelsChanged sees the new key and doesn't count this as a change;
    // set it again in case the levels read the same
    _targetNodes = nodes;
    _nodeKey = key;
  }

  function _updateTargetNode() {
    const apps = (targetApps ?? []).map(a => a.toLowerCase()).filter(a => a !== "");
    if (useSystemVolume || (!otherApps && apps.length === 0)) {
      _setTargetNodes([]);
      return;
    }
    const streams = Pipewire.nodes.values.filter(n => n.isStream && n.audio && n.ready).map(n => ({
          node: n,
          binary: n.properties["application.process.binary"]?.toLowerCase() ?? "",
          name: n.properties["application.name"]?.toLowerCase() ?? "",
          nickname: n.nickname?.toLowerCase() ?? ""
        }));

    if (otherApps) {
      const excluded = (excludedApps ?? []).map(a => a.toLowerCase()).filter(a => a !== "");
      const other = streams.find(s => (s.binary || s.name) && !excluded.some(ex => s.binary.includes(ex) || s.name.includes(ex)));
      _setTargetNodes(other ? [other.node] : []);
      return;
    }

    // By app, in the listed order, so the first listed app's stream is shown
    const matched = [];
    for (const app of apps) {
      for (const s of streams) {
        if (!matched.includes(s.node) && (s.binary.includes(app) || s.name.includes(app) || s.nickname.includes(app)))
          matched.push(s.node);
      }
    }
    _setTargetNodes(matched);
  }
}
