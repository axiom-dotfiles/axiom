pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.components.content.base
import qs.components.content.parts

// The lock screen's password field (x-hosts: lockscreen only; x-required,
// so every lock screen layout has one). It only unlocks on the screen the
// lock surface makes the target, on a real lock: in the layouts editor's
// preview, or anywhere else, it's an inert field.
// properties: { placeholder, centered, showMessages }
Card {
  id: root

  // The lock surface's host: { kind: "lockscreen", target, preview, key,
  // bare }
  readonly property bool onLockscreen: root.host?.kind === "lockscreen"
  readonly property bool live: root.onLockscreen && root.host.target === true && root.host.preview !== true

  // The field draws its own box, so no card around it, whatever the lock
  // screen's moduleBorders
  color: "transparent"
  border.width: 0

  // Tells the lock surface a Password module shows, so it doesn't draw its
  // own field
  property string _reportedKey: ""
  function _report() {
    const key = root.onLockscreen ? (root.host.key ?? "") : "";
    if (key === root._reportedKey)
      return;
    LockManager.reportPasswordField(root._reportedKey, false);
    LockManager.reportPasswordField(key, true);
    root._reportedKey = key;
  }
  Component.onCompleted: root._report()
  onHostChanged: root._report()
  Component.onDestruction: LockManager.reportPasswordField(root._reportedKey, false)

  PasswordField {
    anchors.fill: parent
    anchors.margins: root.pad
    active: root.live
    placeholder: root.properties.placeholder
    centered: root.properties.centered
    showMessages: root.properties.showMessages
  }
}
