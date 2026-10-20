pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import qs.config

// A ScrollView with the shell's padding and a thin accent scroll bar that
// shows only when asked.
ScrollView {
  id: root

  property int contentPadding: Widget.padding
  property bool showScrollBar: false

  contentWidth: availableWidth

  topPadding: contentPadding
  bottomPadding: contentPadding
  leftPadding: contentPadding
  rightPadding: showScrollBar ? contentPadding * 2 : contentPadding

  ScrollBar.vertical.policy: ScrollBar.AsNeeded
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  ScrollBar.vertical {
    Glide on opacity {
      duration: Appearance.animNormal
    }

    contentItem: Rectangle {
      implicitWidth: root.showScrollBar ? Widget.px(6) : 0
      radius: width / 2
      color: Theme.accent
      opacity: parent.pressed ? 0.8 : 0.4
      visible: root.showScrollBar

      Glide on opacity {
        duration: Appearance.animNormal
      }
    }

    background: Rectangle {
      implicitWidth: root.showScrollBar ? Widget.px(8) : 0
      color: Theme.backgroundAlt
      visible: root.showScrollBar
      opacity: 0.2
      radius: width / 2
    }
  }
}
