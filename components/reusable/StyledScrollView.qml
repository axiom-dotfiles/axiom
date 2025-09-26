// qs/components/reusable/StyledScrollView.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import qs.config

ScrollView {
  id: root

  property int contentPadding: Widget.padding
  property bool showScrollBar: false

  property alias scrollbarOpacity: verticalScrollBar.opacity

  contentWidth: availableWidth

  topPadding: contentPadding
  bottomPadding: contentPadding
  leftPadding: contentPadding
  rightPadding: showScrollBar ? contentPadding * 2 : contentPadding

  ScrollBar.vertical.policy: ScrollBar.AsNeeded
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  ScrollBar.vertical {
    id: verticalScrollBar

    Behavior on opacity {
      NumberAnimation {
        duration: 150
      }
    }

    contentItem: Rectangle {
      implicitWidth: root.showScrollBar ? 6 : 0
      radius: 3
      color: Theme.accent
      opacity: parent.pressed ? 0.8 : 0.4
      visible: root.showScrollBar

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
    }

    background: Rectangle {
      implicitWidth: root.showScrollBar ? 8 : 0
      color: Theme.backgroundAlt
      visible: root.showScrollBar
      opacity: 0.2
      radius: 4
    }
  }
}
