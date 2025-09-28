pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.widgets.notifications
import qs.components.widgets.menu
import qs.components.widgets.menu.calendar
import qs.components.widgets.menu.chat
import qs.components.widgets.menu.cube

StyledContainer {
  id: root

  // TODO: implement a way to calculate widgets
  // requested width/height for this depending
  // on their configuration
  width: 350
  height: 500

  containerColor: "transparent"

  property int currentTab: 0

  readonly property var tabs: [
    {
      name: "",
      loader: volumeMixerLoader
    },
    {
      name: "󰆧",
      loader: rubikTimerLoader
    },
    {
      name: "",
      loader: calendarLoader
    },
    {
      name: "",
      loader: notificationLoader
    }
  ]

  readonly property real tabBarHeight: 40

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    TabBar {
      Layout.fillWidth: true
      Layout.preferredHeight: tabBarHeight
      currentTab: root.currentTab
      tabs: root.tabs
      onTabClicked: index => {
        root.currentTab = index;
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.padding
    }

    StyledContainer {
      Layout.fillWidth: true
      Layout.fillHeight: true
      containerColor: Theme.backgroundAlt
      clip: true

      Item {
        id: contentContainer
        anchors.fill: parent

        states: [
          State {
            name: "tab0"
            when: root.currentTab === 0
            PropertyChanges {
              target: contentRow
              x: 0
            }
          },
          State {
            name: "tab1"
            when: root.currentTab === 1
            PropertyChanges {
              target: contentRow
              x: -root.width
            }
          },
          State {
            name: "tab2"
            when: root.currentTab === 2
            PropertyChanges {
              target: contentRow
              x: -root.width * 2
            }
          },
          State {
            name: "tab3"
            when: root.currentTab === 3
            PropertyChanges {
              target: contentRow
              x: -root.width * 3
            }
          }
        ]

        Row {
          id: contentRow
          height: parent.height

          Behavior on x {
            NumberAnimation {
              id: slideAnimation
              duration: 250
              easing.type: Easing.InOutQuad
            }
          }

          // --- Tab 1: Volume Mixer ---
          StyledScrollView {
            id: volumeScrollView
            width: root.width
            height: parent.height
            showScrollBar: false
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            Loader {
              id: volumeMixerLoader
              active: true // Or root.currentTab === 0
              sourceComponent: SinkWrapper {
                width: volumeScrollView.availableWidth
              }
            }
          }

          // --- Tab 2: Rubik Timer ---
          StyledScrollView {
            id: timerScrollView
            width: root.width
            height: parent.height
            showScrollBar: true
            contentPadding: Widget.padding
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            Loader {
              id: rubikTimerLoader
              active: root.currentTab === 1
              sourceComponent: CubeTimer {
                hideTimeDuringSolve: true
                width: timerScrollView.availableWidth
              }
            }
          }

          // --- Tab 3: Calendar ---
          StyledScrollView {
            id: calendarScrollView
            width: root.width
            height: parent.height
            showScrollBar: false
            contentPadding: Widget.padding
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            Loader {
              id: calendarLoader
              sourceComponent: CalendarMenu {
                width: calendarScrollView.availableWidth
              }
            }
          }

          // --- Tab 4: Notifications ---
          StyledScrollView {
            id: notificationScrollView
            width: root.width
            height: parent.height
            showScrollBar: true
            contentPadding: Widget.padding
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            Loader {
              id: notificationLoader
              sourceComponent: NotificationList {
                width: notificationScrollView.availableWidth
              }
            }
          }
        }
      }
    }
  }
}
