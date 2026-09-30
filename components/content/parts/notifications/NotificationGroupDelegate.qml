pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.services
import qs.components.reusable

// One app's notifications as a single card: the app header (icon, name,
// count, newest time, or dismiss-all while hovered), then its entries.
// Collapsed, a group of several shows only the newest, with the rest as
// cards stacked underneath; clicking the header expands it.
Item {
  id: root

  // { key, appName, appIcon, desktopEntry, entries (NotificationManager
  //   entries, newest first), newestTime, critical }
  required property var group
  property real now: Date.now()
  property bool expanded: false

  readonly property var entries: root.group?.entries ?? []
  readonly property int count: root.entries.length
  readonly property bool stacked: !root.expanded && root.count > 1
  readonly property int stackDepth: root.stacked ? Math.min(2, root.count - 1) : 0
  readonly property int stackStep: 5

  function dismissAll() {
    if (!slideOut.running)
      slideOut.start();
  }

  Layout.fillWidth: true
  implicitHeight: card.height + root.stackDepth * root.stackStep
  opacity: 0

  Component.onCompleted: appear.start()
  onCountChanged: {
    if (root.count <= 1)
      root.expanded = false;
  }

  transform: Translate {
    id: shift
  }

  ParallelAnimation {
    id: appear
    NumberAnimation {
      target: root
      property: "opacity"
      from: 0
      to: 1
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: shift
      property: "y"
      from: -8
      to: 0
      duration: Appearance.animNormal
      easing.type: Easing.OutCubic
    }
  }

  SequentialAnimation {
    id: slideOut
    ParallelAnimation {
      NumberAnimation {
        target: shift
        property: "x"
        to: root.width
        duration: Appearance.animNormal
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: root
        property: "opacity"
        to: 0
        duration: Appearance.animNormal
      }
    }
    ScriptAction {
      // Snapshot: each dismiss shrinks the live list
      script: root.entries.slice().forEach(e => NotificationManager.dismiss(e.uid))
    }
  }

  // The collapsed rest of the group, peeking out under the card
  Repeater {
    model: root.stackDepth

    Rectangle {
      required property int index
      z: -1 - index
      anchors.horizontalCenter: parent.horizontalCenter
      width: card.width - 16 * (index + 1)
      height: 20
      y: card.height - height + root.stackStep * (index + 1)
      radius: Widget.radius
      color: Theme.backgroundAlt
      opacity: 0.7 - index * 0.25
    }
  }

  Rectangle {
    id: card
    width: parent.width
    height: body.implicitHeight + Widget.padding * 2
    clip: true
    radius: Widget.radius
    color: hover.hovered ? Qt.tint(Theme.backgroundAlt, Qt.alpha(Theme.backgroundHighlight, 0.4)) : Theme.backgroundAlt
    border.width: root.group?.critical ? Appearance.borderWidth : 0
    border.color: Qt.alpha(Theme.error, 0.6)

    Behavior on height {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: Appearance.animFast
      }
    }

    HoverHandler {
      id: hover
    }

    // Critical urgency
    Rectangle {
      visible: root.group?.critical ?? false
      x: 4
      width: 3
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Widget.padding
      radius: 1.5
      color: Theme.error
    }

    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      // App header
      Item {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight

        TapHandler {
          enabled: root.count > 1
          onTapped: root.expanded = !root.expanded
        }
        HoverHandler {
          cursorShape: root.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        RowLayout {
          id: header
          width: parent.width
          spacing: Widget.spacing

          NotificationAvatar {
            appIcon: root.group?.appIcon ?? ""
            desktopEntry: root.group?.desktopEntry ?? ""
            size: 18
          }

          StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: (root.group?.appName ?? "") + (root.count > 1 ? "  ·  " + root.count : "")
            textColor: Theme.foregroundAlt
            textSize: Appearance.fontSize - 2
            font.bold: true
          }

          Item {
            implicitWidth: Math.max(newest.implicitWidth, 20)
            implicitHeight: 20

            StyledText {
              id: newest
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              opacity: hover.hovered ? 0 : 0.7
              text: {
                root.now;
                return I18n.formatRelative(root.group?.newestTime ?? Date.now());
              }
              textColor: Theme.foregroundAlt
              textSize: Appearance.fontSize - 3

              Behavior on opacity {
                NumberAnimation {
                  duration: Appearance.animFast
                }
              }
            }

            StyledIconButton {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: 20
              height: 20
              visible: opacity > 0
              opacity: hover.hovered ? 1 : 0
              iconText: "close"
              iconSize: 12
              borderRadius: 10
              iconColor: Theme.foregroundAlt
              hoverColor: Theme.background
              tooltipText: I18n.tr(root.count > 1 ? "Dismiss all" : "Dismiss")
              onClicked: root.dismissAll()

              Behavior on opacity {
                NumberAnimation {
                  duration: Appearance.animFast
                }
              }
            }
          }

          StyledIcon {
            visible: root.count > 1
            text: "expand_more"
            textColor: Theme.foregroundAlt
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
              NumberAnimation {
                duration: Appearance.animNormal
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }

      Repeater {
        model: ScriptModel {
          values: root.expanded ? root.entries : root.entries.slice(0, 1)
          objectProp: "uid"
        }

        ColumnLayout {
          id: row
          required property var modelData
          required property int index
          Layout.fillWidth: true
          spacing: Widget.spacing

          StyledSeparator {
            visible: row.index > 0
            Layout.fillWidth: true
            separatorHeight: 1
            separatorColor: Theme.backgroundHighlight
          }

          NotificationItemDelegate {
            entry: row.modelData
            now: root.now
            showMeta: root.count > 1
            showTime: root.expanded
          }
        }
      }

      StyledText {
        visible: root.stacked
        Layout.fillWidth: true
        text: I18n.tr("+{0} more", root.count - 1)
        textColor: Theme.accent
        textSize: Appearance.fontSize - 3

        TapHandler {
          onTapped: root.expanded = true
        }
        HoverHandler {
          cursorShape: Qt.PointingHandCursor
        }
      }
    }
  }
}
