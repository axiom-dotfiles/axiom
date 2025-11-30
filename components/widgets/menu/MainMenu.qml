pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Quickshell.Wayland

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.widgets.menu
import qs.components.widgets.menu.chat

// Assuming these components exist:
// import "path/to/SettingsMenu.qml" as SettingsMenu
// import "path/to/ChatView.qml" as ChatView

StyledContainer {
  id: root

  readonly property bool panelEnabled: Menu.enablePanel

  visible: panelEnabled
  implicitWidth: panelEnabled ? 600 : 0
  implicitHeight: panelEnabled ? ((customHeight > 0) ? customHeight : Display.resolutionHeight - Appearance.screenMargin * 4) : 0

  property string panelId: ""
  property real customWidth: 0
  property real customHeight: 0
  property real minimumScrollableHeight: 250
  property bool mediaPlaying: true
  property int panelMargin: 10
  property real topSectionHeight: 120
  property real quickSettingsHeight: 60

  readonly property bool wantsKeyboardFocus: (root.currentTab === 1 && chatLoader.item) ? chatLoader.item.wantsKeyboardFocus : false

  property int tabBarHeight: 40

  readonly property real _minimumRequiredHeight: {
    var total = 0;
    total += minimumScrollableHeight;
    total += (panelMargin * 4);
    return total;
  }

  property int currentTab: 0
  readonly property var tabs: [
    {
      name: ""
    },
    {
      name: "󱜙"
    }
  ]

  borderColor: Theme.foregroundAlt
  backgroundColor: Theme.background

  Loader {
    anchors.fill: parent
    active: root.panelEnabled

    sourceComponent: Component {
      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
          id: panelTabBar
          Layout.fillWidth: true
          Layout.preferredHeight: root.tabBarHeight
          Layout.topMargin: Widget.padding
          Layout.bottomMargin: Widget.padding
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          currentTab: root.currentTab
          tabs: root.tabs
          onTabClicked: index => {
            root.currentTab = index;
          }
        }

        StyledContainer {
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.padding
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding

          backgroundColor: Theme.blue

        }

        StyledContainer {
          Layout.fillWidth: true
          Layout.fillHeight: true
          backgroundColor: Theme.background
          Layout.topMargin: Appearance.borderWidth
          Layout.bottomMargin: Appearance.borderWidth
          Layout.leftMargin: Appearance.borderWidth
          Layout.rightMargin: Appearance.borderWidth
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
                  x: -contentContainer.width
                }
              }
            ]

            Row {
              id: contentRow
              width: contentContainer.width * root.tabs.length
              height: contentContainer.height

              Behavior on x {
                NumberAnimation {
                  duration: 250
                  easing.type: Easing.InOutQuad
                }
              }

              Loader {
                id: settingsLoader
                width: contentContainer.width
                height: contentContainer.height
                sourceComponent: SettingsMenu {}
              }

              Loader {
                id: chatLoader
                width: contentContainer.width
                height: contentContainer.height
                sourceComponent: ChatView {
                  anchors.fill: parent
                }
              }
            }
          }
        }
        MenuBottomArea {
          id: bottomArea
          Layout.fillWidth: true
          Layout.bottomMargin: Widget.padding
          Layout.leftMargin: Widget.padding
          Layout.rightMargin: Widget.padding
          
          quickSettingsHeight: 40
          showMediaControl: true
          mediaPlaying: true
        }
      }
    }
  }
}
