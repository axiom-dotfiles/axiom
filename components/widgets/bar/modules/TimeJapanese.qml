pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import qs.config
import qs.components.reusable

Item {
  id: root

  // Orientation support
  property int orientation: Config.orientation
  property bool isVertical: barConfig.vertical
  property bool showDate: true
  property bool use24Hour: true // Japanese time is typically 24-hour

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  // Dynamic dimensions based on orientation
  height: isVertical ? implicitHeight : Widget.height
  width: isVertical ? Widget.height : implicitWidth

  implicitWidth: isVertical ? Widget.height : (layoutLoader.item ? layoutLoader.item.implicitWidth + Widget.padding * 2 : 100)
  implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + Widget.padding * 2 : Widget.height) : Widget.height

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.info
    radius: Appearance.borderRadius
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: isVertical ? verticalComponent : horizontalComponent

    Component {
      id: horizontalComponent
      Row {
        spacing: 6

        // Date: 2025年10月9日
        Text {
          color: Theme.background
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize
          text: Qt.formatDateTime(clock.date, "yyyy年M月d日")
          visible: root.showDate
        }

        Rectangle {
          width: 1
          height: Appearance.fontSize
          color: Theme.background
          opacity: 0.5
          visible: root.showDate
          anchors.verticalCenter: parent.verticalCenter
        }

        // Time: 14時30分45秒
        Text {
          color: Theme.background
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize
          text: Qt.formatDateTime(clock.date, "H時mm分ss秒")
        }
      }
    }

    Component {
      id: verticalComponent
      Column {
        spacing: 4

        // Time display - Japanese style
        Column {
          spacing: 2
          anchors.horizontalCenter: parent.horizontalCenter

          // Hours
          Column {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: Qt.formatDateTime(clock.date, "H")
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: "時"
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          // Minutes
          Column {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: Qt.formatDateTime(clock.date, "mm")
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: "分"
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          // Seconds
          Column {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: Qt.formatDateTime(clock.date, "ss")
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: "秒"
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        // Separator line
        Rectangle {
          width: parent.width * 0.6
          height: 1
          color: Theme.background
          opacity: 0.3
          visible: root.showDate
          anchors.horizontalCenter: parent.horizontalCenter
        }

        // Date display - Japanese style
        Column {
          spacing: 2
          visible: root.showDate
          anchors.horizontalCenter: parent.horizontalCenter

          // Month
          Column {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: Qt.formatDateTime(clock.date, "M")
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: "月"
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          // Day
          Column {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: Qt.formatDateTime(clock.date, "d")
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              color: Theme.background
              font.family: Appearance.fontFamily
              font.pixelSize: Appearance.fontSize
              text: "日"
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          // Text {
          //   color: Theme.background
          //   font.family: Appearance.fontFamily
          //   font.pixelSize: Appearance.fontSize
          //   text: {
          //     const days = ["日", "月", "火", "水", "木", "金", "土"];
          //     return days[clock.date.getDay()];
          //   }
          //   anchors.horizontalCenter: parent.horizontalCenter
          // }
        }
      }
    }
  }
}
