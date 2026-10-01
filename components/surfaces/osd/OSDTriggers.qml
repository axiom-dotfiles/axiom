pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.services

// What opens one OSD host (an EdgePopout or FloatingPopout) on its screen:
// its bars' own changes (poke, system volume and mute included) and the
// settings page's Show button. An edge OSD gives way to an edge menu on
// its edge (ShellManager.edgeOutranked) and puts a dock there away.
QtObject {
  id: root

  // An EdgePopout or FloatingPopout
  required property var host
  // The OSD's entry (OSDConfig.osds)
  required property var osd

  // Open (or keep open) on the target screen, or on every screen in "all"
  // mode; restarts the countdown
  function poke(force) {
    if (root.outranked)
      return;
    if (root.host.isOpen)
      root.host.updateDismissTimer();
    else if (force && ShellManager.showsOn(root.host.screen, root.osd.monitors))
      root.host.show();
  }

  // Picks up brightness changed outside axiom
  readonly property bool _open: root.host.isOpen
  on_OpenChanged: {
    if (root._open)
      BrightnessManager.refresh(root.host.screen.name);
  }

  // Its screen edge (a Bar.edgeName); none for a floating OSD
  readonly property string edgeName: root.osd.placement === "edge" ? Bar.edgeName(Bar.getLocationFromString(root.osd.edge)) : ""
  readonly property string _screenName: root.host.screen?.name ?? ""
  readonly property bool outranked: root.edgeName !== "" && ShellManager.edgeOutranked(root._screenName, root.edgeName, "osd")
  onOutrankedChanged: {
    if (root.outranked)
      root.host.hide();
  }
  readonly property var _claim: root._open && root.edgeName !== "" ? ({
      "screen": root._screenName,
      "edge": root.edgeName,
      "kind": "osd"
    }) : null
  on_ClaimChanged: ShellManager.setEdgeClaim(root, root._claim)
  Component.onDestruction: ShellManager.setEdgeClaim(root, null)

  readonly property Connections _shell: Connections {
    target: ShellManager

    function onShowOsd(id) {
      if (id === root.osd.id)
        root.poke(true);
    }
  }
}
