// qs/components/reusable/StyledScrollView.qml
import QtQuick
import QtQuick.Controls
import qs.config

ScrollView {
  id: root

  property int contentPadding: Widget.padding

  // --- FIX ---
  // CHANGED: The alias now points directly to the opacity property of the scrollbar.
  // EXPLANATION: An alias must target a specific property (like id.property), not an entire object (id).
  property alias scrollbarOpacity: verticalScrollBar.opacity

  contentWidth: availableWidth

  topPadding: contentPadding
  bottomPadding: contentPadding
  leftPadding: contentPadding
  rightPadding: contentPadding

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
      implicitWidth: 6
      radius: 3
      color: Theme.accent
      opacity: parent.pressed ? 0.8 : 0.4

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
    }

    background: Rectangle {
      implicitWidth: 8
      color: Theme.backgroundAlt
      opacity: 0.2
      radius: 4
    }
  }
}
