pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components.methods

Rectangle {
  id: root

  color: "transparent"
  radius: Appearance.borderRadius
  border.color: Theme.accentAlt

  // State management
  property int currentTab: 0

  // Tab definitions
  readonly property var tabs: [
    {
      name: "Volume",
      loader: volumeMixerLoader
    },
    {
      name: "Timer",
      loader: rubikTimerLoader
    },
    {
      name: "Calendar",
      loader: calendarLoader
    },
    {
      name: "Notifs",
      loader: notificationLoader
    }
  ]

  // Constants
  readonly property real tabBarHeight: 40

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Tab Navigation Bar
    PowerPanelTabBar {
      Layout.fillWidth: true
      Layout.preferredHeight: tabBarHeight
      currentTab: root.currentTab
      tabs: root.tabs
      onTabClicked: index => {
        root.currentTab = index;
      }
    }

    // Spacing
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.padding
    }

    // Content Viewport with Animation
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "transparent"
      clip: true

      Item {
        id: contentContainer
        anchors.fill: parent

        // State-based positioning for tab animation
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
              duration: 250
              easing.type: Easing.InOutQuad
            }
          }

          // Volume Mixer Widget
          PowerPanelScrollableContent {
            width: root.width
            height: parent.height

            Loader {
              id: volumeMixerLoader
              width: parent.width - (Widget.padding * 2)
              x: Widget.padding
              y: Widget.padding
              active: true

              // TODO: Load actual Volume Mixer widget here
              sourceComponent: Rectangle {
                height: 200
                color: Theme.backgroundHighlight
                radius: Appearance.borderRadius

                Text {
                  anchors.centerIn: parent
                  text: "Volume Mixer Widget Placeholder"
                  font.family: Appearance.fontFamily
                  font.pixelSize: Appearance.fontSize
                  color: Theme.foregroundAlt
                }
              }
            }
          }

          // Rubik's Timer Widget
          PowerPanelScrollableContent {
            width: root.width
            height: parent.height

            Loader {
              id: rubikTimerLoader
              width: parent.width - (Widget.padding * 2)
              x: Widget.padding
              y: Widget.padding
              active: root.currentTab === 1 || contentRow.x < 0

              // TODO: Load actual Rubik's Timer widget here
              sourceComponent: Rectangle {
                height: 300
                color: Theme.backgroundHighlight
                radius: Appearance.borderRadius

                Text {
                  anchors.centerIn: parent
                  text: "Rubik's Timer Widget Placeholder"
                  font.family: Appearance.fontFamily
                  font.pixelSize: Appearance.fontSize
                  color: Theme.foregroundAlt
                }
              }
            }
          }

          // Calendar Widget
          PowerPanelScrollableContent {
            width: root.width
            height: parent.height

            Loader {
              id: calendarLoader
              width: parent.width - (Widget.padding * 2)
              x: Widget.padding
              y: Widget.padding
              active: root.currentTab === 2 || Math.abs(contentRow.x) > root.width

              // TODO: Load actual Calendar widget here
              sourceComponent: Rectangle {
                height: 2000
                color: Theme.backgroundHighlight
                radius: Appearance.borderRadius

                Text {
                  anchors.centerIn: parent
                  text: "Calendar Widget Placeholder"
                  font.family: Appearance.fontFamily
                  font.pixelSize: Appearance.fontSize
                  color: Theme.foregroundAlt
                }
              }
            }
          }

          // Notifications Widget
          PowerPanelScrollableContent {
            width: root.width
            height: parent.height

            Loader {
              id: notificationLoader
              width: parent.width - (Widget.padding * 2)
              x: Widget.padding
              y: Widget.padding
              active: root.currentTab === 3 || contentRow.x < -(root.width * 2)

              // TODO: Load actual Notifications widget here
              sourceComponent: Rectangle {
                height: 500
                color: Theme.backgroundHighlight
                radius: Appearance.borderRadius

                Text {
                  anchors.centerIn: parent
                  text: "Notifications Widget Placeholder"
                  font.family: Appearance.fontFamily
                  font.pixelSize: Appearance.fontSize
                  color: Theme.foregroundAlt
                }
              }
            }
          }
        }
      }
    }
  }
}
