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

StyledContainer {
  id: root

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
    total += topSection.height;
    total += minimumScrollableHeight;
    total += bottomArea.implicitHeight;
    total += (panelMargin * 4);
    return total;
  }

  property int currentTab: 0
  readonly property var tabs: [
    {
      name: "",
      loader: settingsLoader
    },
    {
      name: "󱜙",
      loader: chatLoader
    }
  ]

  implicitWidth: 600
  implicitHeight: (customHeight > 0) ? customHeight : Display.resolutionHeight - Widget.containerWidth * 4 // TODO: Remove random numbers

  containerBorderWidth: Appearance.borderWidth
  containerBorderColor: Theme.foregroundAlt
  containerColor: Theme.background
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
      Layout.fillHeight: true
      containerColor: Theme.background
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
              target: settingsLoader
              visible: true
            }
            PropertyChanges {
              target: chatLoader
              visible: false
            }
          },
          State {
            name: "tab1"
            when: root.currentTab === 1
            PropertyChanges {
              target: settingsLoader
              visible: false
            }
            PropertyChanges {
              target: chatLoader
              visible: true
            }
          }
        ]

        Loader {
          id: settingsLoader
          anchors.fill: parent
          sourceComponent: SettingsMenu {}
          visible: root.currentTab === 0
        }

        Loader {
          id: chatLoader
          anchors.fill: parent
          sourceComponent: ChatView {
            anchors.fill: parent
          }
          visible: root.currentTab === 1
        }

        // Component {
        //   id: settingsComponent
        //   MainContent {
        //     id: settingsContent
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        //   }
        // }
        //
        // Component {
        //   id: chatComponent
        //   MainContent {
        //     id: chatContent
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        //   }
        // }
      }
    }
  }

  // --- Bottom-Anchored ---
  // ColumnLayout {
  //   id: bottomArea
  //   anchors.bottom: parent.bottom
  //   anchors.left: parent.left
  //   anchors.right: parent.right
  //
  //   anchors.bottomMargin: root.panelMargin
  //   anchors.leftMargin: root.panelMargin
  //   anchors.rightMargin: root.panelMargin
  //
  //   spacing: Widget.containerWidth // Internal spacing between items in this section
  //
  //   MediaControl {
  //     id: mediaControl
  //     Layout.fillWidth: true
  //     // playing: root.mediaPlaying
  //     visible: true
  //     containerColor: Theme.accent
  //   }
  //
  //   QuickSettings {
  //     Layout.fillWidth: true
  //     Layout.preferredHeight: root.quickSettingsHeight
  //   }
  // }
  //
  // --- Top-Anchored and Fill Layout Area ---
  // REFACTORED: This is now a ColumnLayout, replacing the old 'Item' with manual anchors.
  // It dynamically manages the top section and the main scrollable content area.
  // ColumnLayout {
  //   id: topAreaLayout
  //   anchors.top: parent.top
  //   anchors.left: parent.left
  //   anchors.right: parent.right
  //   // Anchor the bottom of this layout to the top of the bottom layout
  //   anchors.bottom: bottomArea.top
  //
  //   // REFACTORED: Margins and spacing are now consistently controlled by panelMargin
  //   anchors.topMargin: root.panelMargin
  //   anchors.leftMargin: root.panelMargin
  //   anchors.rightMargin: root.panelMargin
  //   anchors.bottomMargin: bottomArea.visibleChildren.length > 0 ? root.panelMargin : 0
  //   spacing: root.panelMargin
  //
  //   // This is the fixed-height top section.
  //   StyledContainer {
  //     id: topSection
  //     Layout.fillWidth: true
  //     Layout.preferredHeight: root.topSectionHeight // Layout respects preferred height
  //     containerBorderColor: Theme.border
  //
  //     // Note: Anchors are relative to this container now, not the whole panel.
  //     StyledText {
  //       anchors.centerIn: parent
  //       text: "Top Section - Reserved for Future Component"
  //       textColor: Theme.foregroundAlt
  //
  //     }
  //
  //     MouseArea {
  //       anchors.fill: parent
  //       cursorShape: Qt.PointingHandCursor
  //       onClicked: {
  //         console.log("Top section clicked - toggling dark mode for demo.");
  //         ShellManager.toggleDarkMode();
  //       }
  //     }
  //   }
  //
  //   // -- Add other fixed-height top components here. They will stack automatically. --
  //
  //   // This is the primary scrollable content area.
  //   // REFACTORED: Using Layout.fillHeight, it automatically expands to fill the
  //   // remaining space within this ColumnLayout.
  //   MainContent {
  //     id: tabbedContent
  //     Layout.fillWidth: true
  //     Layout.fillHeight: true // This is the key to making it fill the space
  //   }
  // }
  //
  // // Timer for demonstration
  // Timer {
  //   interval: 3000
  //   running: true
  //   repeat: false
  //   onTriggered: {
  //     root.mediaPlaying = !root.mediaPlaying;
  //   }
  // }
}
