import QtQuick
import qs.components.reusable
import Quickshell.Services.Pipewire

Item {
  id: root

  property string targetApplication: ""
  property alias orientation: bar.orientation
  property alias iconSource: bar.iconSource

  implicitWidth: bar.implicitWidth
  implicitHeight: bar.implicitHeight

  property var _targetNode: null

  PwObjectTracker {
    objects: [root._targetNode]
  }

  readonly property bool nodeFound: _targetNode !== null && _targetNode.ready && _targetNode.audio

  readonly property string nodeName: {
    if (!nodeFound) {
      return "Not Found";
    }
    return _targetNode.properties["application.process.binary"] || _targetNode.properties["application.name"] || _targetNode.nickname || _targetNode.description || "Unknown Stream";
  }

  property real volume: nodeFound ? _targetNode.audio.volume : 0.0
  property bool isMuted: !nodeFound || _targetNode.audio.muted

  signal visibilityChanged(real volume)

  StyledVolumeBar {
    id: bar
    anchors.fill: parent
    volumeLevel: root.volume
    isMuted: root.isMuted
    enabled: root.nodeFound
    onVolumeChanged: root.setVolume(newVolume)
    onVolumeLevelChanged: {
      root.visibilityChanged(root.volume);
    }
    Component.onCompleted: {
      console.log("PipewireVolumeBar initialized for application:", root.targetApplication);
      console.log("Initial volume:", root.volume, "Muted:", root.isMuted, "Node Found:", root.nodeFound);
    }
  }

  function setVolume(newVolume) {
    if (nodeFound) {
      _targetNode.audio.volume = Math.max(0.0, Math.min(1.0, newVolume));
    }
  }

  function toggleMute() {
    if (nodeFound) {
      _targetNode.audio.muted = !_targetNode.audio.muted;
    }
  }


  onTargetApplicationChanged: _updateTargetNode()

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

  function _updateTargetNode() {
    if (targetApplication === "") {
      if (_targetNode !== null)
        _targetNode = null;
      return;
    }

    const nodes = Pipewire.nodes.values;
    const searchString = targetApplication.toLowerCase();

    if (searchString === "master") {
      const excludedBinaries = ["youtube-music", "electron", "zen-bin"];

      for (let i = 0; i < nodes.length; ++i) {
        const n = nodes[i];
        const appBinary = n.properties["application.process.binary"];

        if (n.isStream && n.audio && appBinary && !excludedBinaries.includes(appBinary)) {
          _targetNode = n;
          root.visibilityChanged(root.volume);
          return;
        }
      }
    }

    for (let i = 0; i < nodes.length; ++i) {
      const n = nodes[i];

      if (n.isStream && n.audio) {
        const appBinary = n.properties["application.process.binary"]?.toLowerCase();
        const appName = n.properties["application.name"]?.toLowerCase();
        const appNickname = n.nickname?.toLowerCase();

        if ((appBinary && appBinary.includes(searchString)) || (appName && appName.includes(searchString)) || (appNickname && appNickname.includes(searchString))) {
          console.log("PipewireVolumeBar: Found target node for", targetApplication, "->", appBinary || appName || appNickname);
          _targetNode = n;
          return;
        }
      }
    }

    if (_targetNode !== null) {
      console.log("PipewireVolumeBar: Lost target node for", targetApplication);
      _targetNode = null;
    }
  }
}
