pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config

BaseWidget {
  id: root

  // Content properties
  property string icon: ""
  property string text: ""
  property bool rotateText: true
  property real textScale: 1.0
  property real iconScale: 1.0
  property real spacing: 6
  property int maxTextLength: 0  // 0 = no limit
  property bool elideText: true  // Use ellipsis when truncating

  // Process text based on max length
  property string displayText: {
    if (maxTextLength <= 0 || text.length <= maxTextLength) {
      return text;
    }
    if (elideText && maxTextLength > 3) {
      return text.substring(0, maxTextLength - 3) + "...";
    }
    return text.substring(0, maxTextLength);
  }

  content: Component {
    Loader {
      sourceComponent: {
        if (!root.isVertical) {
          return horizontalLayout;
        } else if (root.rotateText) {
          return rotatedLayout;
        } else {
          return verticalLayout;
        }
      }

      // Horizontal layout
      Component {
        id: horizontalLayout
        Row {
          spacing: root.spacing

          Text {
            color: Theme.background
            text: root.icon
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * root.iconScale
            visible: root.icon !== ""
          }

          Text {
            color: Theme.background
            text: root.displayText || "—"
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * root.textScale
          }
        }
      }

      // Vertical layout (no rotation)
      Component {
        id: verticalLayout
        Column {
          spacing: root.displayText !== "" ? 2 : 0

          Text {
            color: Theme.background
            text: root.icon
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * root.iconScale
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.icon !== ""
          }

          Text {
            color: Theme.background
            text: root.displayText || "—"
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.8 * root.textScale
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.displayText !== ""
          }
        }
      }

      // Rotated layout for vertical bars
      Component {
        id: rotatedLayout
        Item {
          implicitWidth: Math.max(root.icon !== "" ? iconText.height : 0, root.displayText !== "" ? mainText.height : 0) + (root.displayText !== "" && root.icon !== "" ? root.spacing : 0)

          implicitHeight: (root.icon !== "" ? iconText.width : 0) + (root.displayText !== "" ? mainText.width : 0) + (root.displayText !== "" && root.icon !== "" ? root.spacing : 0)

          Text {
            id: iconText
            color: Theme.background
            text: root.icon
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * root.iconScale
            visible: root.icon !== ""
            anchors {
              centerIn: parent
              verticalCenterOffset: root.displayText !== "" && root.icon !== "" ? -(mainText.width / 2) - 3 : 0
            }
          }

          Text {
            id: mainText
            color: Theme.background
            text: root.displayText || "—"
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * root.textScale
            rotation: -90
            visible: root.displayText !== ""
            anchors {
              centerIn: parent
              verticalCenterOffset: root.icon !== "" ? (iconText.width / 2) + 3 : 0
            }
          }
        }
      }
    }
  }
}
