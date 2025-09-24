pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import qs.config

Item {
  id: root

  // Orientation support
  property int orientation: Config.orientation
  property bool isVertical: orientation === Qt.Vertical
  property bool showDate: true
  property bool use24Hour: false

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
    color: Theme.accentAlt
    radius: Appearance.borderRadius
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: isVertical ? verticalComponent : horizontalComponent

    Component {
      id: horizontalComponent
      Row {
        spacing: 8

        Text {
          color: Theme.background
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize
          text: Qt.formatDateTime(clock.date, "MMM d, yyyy")
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

        Text {
          color: Theme.background
          font.family: Appearance.fontFamily
          font.pixelSize: Appearance.fontSize
          text: Qt.formatDateTime(clock.date, root.use24Hour ? "HH:mm:ss" : "hh:mm:ss ap")
        }
      }
    }

    Component {
      id: verticalComponent
      Column {
        spacing: 2

        // Time display - larger and more prominent
        Column {
          spacing: 0
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 1.1
            font.bold: true
            text: Qt.formatDateTime(clock.date, root.use24Hour ? "HH" : "hh")
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.9
            font.bold: true
            text: Qt.formatDateTime(clock.date, "mm")
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.8
            text: Qt.formatDateTime(clock.date, "ss")
            opacity: 0.8
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.7
            text: Qt.formatDateTime(clock.date, "ap")
            visible: !root.use24Hour
            opacity: 0.9
            anchors.horizontalCenter: parent.horizontalCenter
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

        // Date display - compact format
        Column {
          spacing: 0
          visible: root.showDate
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.8
            text: Qt.formatDateTime(clock.date, "MMM")
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 1.1
            font.bold: true
            text: Qt.formatDateTime(clock.date, "dd")
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            color: Theme.background
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize * 0.7
            text: Qt.formatDateTime(clock.date, "ddd")  // Day of week
            opacity: 0.8
            anchors.horizontalCenter: parent.horizontalCenter
          }
        }
      }
    }
  }
}
