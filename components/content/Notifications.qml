pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.services
import qs.config
import qs.components.reusable
import qs.components.content.base
import qs.components.content.parts
import qs.components.content.parts.notifications

// The notification menu (the Notifications widget's popout, or an overlay
// card): a header with do not disturb and clear all, then one card per app,
// newest first.
Panel {
  id: root

  compactContent: CompactFigure {
    icon: NotificationManager.dnd ? "notifications_off" : "notifications"
    iconColor: NotificationManager.count > 0 ? Theme.accent : Theme.foregroundAlt
    value: String(NotificationManager.count)
    label: I18n.tr(NotificationManager.dnd ? "muted" : "notifications")
  }

  readonly property int maxListHeight: 440

  implicitWidth: 400

  // Groups by key, and their keys newest first. The Repeater is keyed by
  // the key strings, so a group's card (and whether it's expanded) survives
  // notifications coming and going.
  property var groups: ({})
  property var groupKeys: []

  // Refreshes relative times
  property real now: Date.now()

  function rebuildGroups() {
    const byKey = {};
    const keys = [];
    // Entries are newest first, so groups and their entries come out sorted
    for (const entry of NotificationManager.entries) {
      const key = entry.appName || entry.desktopEntry || "";
      if (!byKey[key]) {
        byKey[key] = {
          key: key,
          appName: entry.appName || entry.desktopEntry || I18n.tr("Unknown"),
          appIcon: entry.appIcon,
          desktopEntry: entry.desktopEntry,
          entries: [],
          newestTime: entry.time,
          critical: false
        };
        keys.push(key);
      }
      const group = byKey[key];
      group.entries.push(entry);
      if (entry.urgency === NotificationUrgency.Critical)
        group.critical = true;
      if (!group.appIcon && entry.appIcon)
        group.appIcon = entry.appIcon;
      if (!group.desktopEntry && entry.desktopEntry)
        group.desktopEntry = entry.desktopEntry;
    }
    root.groups = byKey;
    root.groupKeys = keys;
    root.now = Date.now();
  }

  function clearAll() {
    if (!clearOut.running)
      clearOut.start();
  }

  Connections {
    target: NotificationManager
    function onEntriesChanged() {
      root.rebuildGroups();
    }
  }

  Component.onCompleted: rebuildGroups()

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.now = Date.now()
  }

  // Everything slides out together, then goes
  SequentialAnimation {
    id: clearOut
    ParallelAnimation {
      NumberAnimation {
        target: listShift
        property: "x"
        to: scroll.width
        duration: Appearance.animNormal
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: scroll
        property: "opacity"
        to: 0
        duration: Appearance.animNormal
      }
    }
    ScriptAction {
      script: NotificationManager.clearAll()
    }
    PropertyAction {
      target: listShift
      property: "x"
      value: 0
    }
    PropertyAction {
      target: scroll
      property: "opacity"
      value: 1
    }
  }

  NotificationHeader {
    onClearAll: root.clearAll()
  }

  StyledSeparator {
    Layout.fillWidth: true
    separatorColor: Theme.backgroundHighlight
  }

  StyledScrollView {
    id: scroll
    visible: root.groupKeys.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: root.embedded ? -1 : Math.min(root.maxListHeight, list.implicitHeight)
    Layout.fillHeight: root.embedded
    contentPadding: 0
    showScrollBar: list.implicitHeight > (root.embedded ? scroll.height : root.maxListHeight)
    rightPadding: showScrollBar ? 12 : 0
    clip: true

    ColumnLayout {
      id: list
      width: scroll.availableWidth
      spacing: Widget.spacing

      transform: Translate {
        id: listShift
      }

      Repeater {
        model: ScriptModel {
          values: root.groupKeys
        }

        NotificationGroupDelegate {
          required property string modelData
          group: root.groups[modelData] ?? null
          now: root.now
        }
      }
    }
  }

  // Empty: centred in whatever room is left (the card's slot, or a fixed
  // height in a popout)
  Item {
    visible: root.groupKeys.length === 0
    Layout.fillWidth: true
    Layout.fillHeight: root.embedded
    Layout.preferredHeight: root.embedded ? -1 : emptyState.implicitHeight + Widget.padding * 6

    ColumnLayout {
      id: emptyState
      anchors.centerIn: parent
      width: parent.width
      spacing: Widget.spacing / 2

      StyledIcon {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: NotificationManager.dnd ? "notifications_paused" : "notifications_active"
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize * 3
        opacity: 0.4
      }

      StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: I18n.tr("All caught up")
        textColor: Theme.foregroundAlt
      }

      StyledText {
        visible: NotificationManager.dnd
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: I18n.tr("Do not disturb is on")
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 2
        opacity: 0.7
      }
    }
  }
}
