pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.widgets.overlay.layouts

Item {
  id: overlayColumn

  required property var screen

  Component.onCompleted: {
    console.log("========== OverlayColumn ==========");
    console.log("  > Screen:", screen.name, "Primary:", isPrimaryScreen, "Width:", screen.width, "Height:", screen.height, "Aspect Ratio:", Display.aspectRatio);
    console.log("===================================");
  }

  implicitHeight: parent.implicitHeight
  implicitWidth: parent.implicitWidth
  RowLayout {
    id: cardContainer
    anchors.fill: parent
    anchors.margins: Menu.cardSpacing / 2
    Repeater {
      model: Menu.columns
      delegate: Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: Menu.cardUnit
        color: "transparent"

        Cell2x2 {
          id: topCell
          topLeft: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          topRight: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomLeft: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomRight: Rectangle {
            color: Theme.accentAlt
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
        }

        Cell2x2 {
          id: bot
          topLeft: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          topRight: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomLeft: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
          bottomRight: Rectangle {
            color: Theme.accent
            anchors.fill: parent
            radius: Menu.cardBorderRadius
          }
        }
      }
    }
  }
}
