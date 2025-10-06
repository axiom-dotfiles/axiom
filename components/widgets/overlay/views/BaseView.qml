import QtQuick
import QtQuick.Layouts

import qs.config

Item {
  id: overlayColumn

  required property var screen

  Component.onCompleted: {
    console.log("========== OverlayColumn ==========");
    console.log("  > Screen:", screen.name, "Primary:", isPrimaryScreen, "Width:", screen.width, "Height:", screen.height, "Aspect Ratio:", Display.aspectRatio);
    console.log("===================================");
  }

  implicitHeight: columnLayout.implicitHeight
  implicitWidth: columnLayout.implicitWidth
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

        ColumnLayout {
          id: columnLayout
          anchors.fill: parent
          // spacing: Menu.cardSpacing

          // Rectangle {
          //   id: background
          //   Layout.preferredHeight: Menu.cardUnit
          //   Layout.fillWidth: true
          //   color: Theme.backgroundAlt
          //   radius: Menu.cardBorderRadius
          //   // border.color: Theme.accentAlt
          //   // border.width: Menu.cardBorderWidth
          GridLayout {
            // anchors.centerIn: parent
            // width: parent.width - (Menu.cardPadding * 2)
            // height: parent.height - (Menu.cardPadding * 2)
            // Layout.fillWidth: true
            // Layout.fillHeight: true
            Layout.preferredHeight: Menu.cardUnit
            Layout.preferredWidth: Menu.cardUnit
            Layout.margins: Menu.cardPadding
            columns: 2
            rows: 2
            columnSpacing: Menu.cardSpacing
            rowSpacing: Menu.cardSpacing
            Repeater {
              model: 4
              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.accent
                radius: Menu.cardBorderRadius
                // border.color: Theme.accent
                // border.width: Menu.cardBorderWidth
              }
            }
            // }
          }

          Rectangle {
            id: background2
            Layout.preferredHeight: Menu.cardUnit
            Layout.preferredWidth: Menu.cardUnit
            // Layout.fillWidth: true
            Layout.margins: Menu.cardPadding
            color: Theme.accentAlt
            radius: Menu.cardBorderRadius
          }
        }
      }
    }
  }
}
