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
import qs.components.widgets.menu

StyledContainer {
  id: root
  // TODO: not hardcode this
  implicitWidth: 350
  implicitHeight: 500
  property int currentTab: 0
  readonly property var tabs: [
    {
      name: "Applications"
    },
    {
      name: "Devices"
    }
  ]
  readonly property real tabBarHeight: 40
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    TabBar {
      Layout.fillWidth: true
      Layout.preferredHeight: root.tabBarHeight
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
      containerColor: Theme.backgroundHighlight
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

          // --- Applications Tab ---
          StyledScrollView {
            width: root.width
            height: parent.height
            showScrollBar: false
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            ColumnLayout {
              Layout.fillWidth: true
              width: parent.width
              spacing: Widget.spacing

              // --- CORRECTED ---
              property var filteredNodes: Pipewire.nodes.values.filter(node => node.isStream && node.isSink)

              // StyledText {
              //   text: "No applications are currently playing audio."
              //   Layout.fillWidth: true
              //   horizontalAlignment: Text.AlignHCenter
              //   // Bind visibility directly to the length of the filtered list
              //   visible: filteredNodes.length === 0
              // }

              Repeater {
                model: ScriptModel {
                  values: Pipewire.nodes.values.filter(node => {
                    return node.isStream && node.isSink;
                  })
                }

                delegate: AudioControl {
                  Layout.fillWidth: true
                  required property var modelData
                  node: modelData

                  Component.onCompleted: {
                    console.log("AudioControl created for application node:", node.name);
                  }
                }
              }
            }
          }

          // --- Devices Tab ---
          StyledScrollView {
            width: root.width
            height: parent.height
            contentPadding: Widget.padding
            scrollbarOpacity: slideAnimation.running ? 0 : 1

            ColumnLayout {
              Layout.fillWidth: true
              width: parent.width

              property var filteredNodes: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream)

              StyledText {
                text: "No output devices found."
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: false // TODO: fix
              }

              Repeater {
                model: ScriptModel {
                  values: Pipewire.nodes.values.filter(node => {
                    return node.isSink && !node.isStream;
                  })
                }
                delegate: AudioControl {
                  Layout.fillWidth: true
                  required property var modelData
                  node: modelData
                }
              }
            }
          }
        }
      }
    }
  }
}
