pragma ComponentBehavior: Bound
import QtQuick

import qs.config
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
  // bare, passwordBorder, greetingBorder }
  readonly property bool onLockscreen: root.host?.kind === "lockscreen"
  readonly property bool live: root.onLockscreen && root.host.target === true && root.host.preview !== true

  // The field draws its own box, so no card around it: with the lock
  // screen's passwordBorder (independent of its moduleBorders) a box hugs
  // the field instead of filling the slot
  readonly property bool boxed: root.host?.passwordBorder === true

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

  // Boxed, it's drawn like LockSurface's fallback field: a box as tall as
  // the field plus padding, across the slot
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: root.pad
    height: root.boxed ? field.implicitHeight + Widget.padding * 2 : parent.height - root.pad * 2
    radius: Widget.radius
    color: root.boxed ? Theme.background : "transparent"
    border.color: Theme.border
    border.width: root.boxed ? Appearance.borderWidth : 0

    PasswordField {
      id: field
      anchors.fill: parent
      anchors.margins: root.boxed ? Widget.padding : 0
      active: root.live
      placeholder: root.properties.placeholder
      centered: root.properties.centered
      showMessages: root.properties.showMessages
    }
  }
}
