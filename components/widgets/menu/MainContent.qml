pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.widgets.menu

StyledContainer {
    id: root
    
    // Using sample values for demonstration
    width: 350
    height: 500
    
    containerColor: "transparent"
    
    property int currentTab: 0

    readonly property var tabs: [
        { name: "", loader: volumeMixerLoader },
        { name: "󰆧", loader: rubikTimerLoader },
        { name: "", loader: calendarLoader },
        { name: "", loader: notificationLoader }
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
            onTabClicked: index => { root.currentTab = index; }
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
                    State { name: "tab0"; when: root.currentTab === 0; PropertyChanges { target: contentRow; x: 0 } },
                    State { name: "tab1"; when: root.currentTab === 1; PropertyChanges { target: contentRow; x: -root.width } },
                    State { name: "tab2"; when: root.currentTab === 2; PropertyChanges { target: contentRow; x: -root.width * 2 } },
                    State { name: "tab3"; when: root.currentTab === 3; PropertyChanges { target: contentRow; x: -root.width * 3 } }
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

                    StyledScrollView {
                        width: root.width; height: parent.height
                        contentPadding: Widget.padding
                        scrollbarOpacity: slideAnimation.running ? 0 : 1

                        Loader {
                            id: volumeMixerLoader; active: true
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: StyledContainer {
                                implicitWidth: root.width - (Widget.padding * 2)
                                height: 300
                                containerColor: Theme.foregroundAlt

                                StyledText {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    width: parent.width - (2 * Widget.padding)

                                    text: "Volume Mixer Widget Placeholder"
                                    textColor: Theme.background
                                }
                            }
                        }
                    }

                    StyledScrollView {
                        width: root.width; height: parent.height
                        contentPadding: Widget.padding
                        scrollbarOpacity: slideAnimation.running ? 0 : 1

                        Loader {
                            id: rubikTimerLoader; active: root.currentTab === 1 || contentRow.x < 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: CubeTimer {
                                hideTimeDuringSolve: true
                                implicitWidth: root.width - (Widget.padding * 2)
                            }
                        }
                    }

                    StyledScrollView {
                        width: root.width; height: parent.height
                        contentPadding: Widget.padding
                        scrollbarOpacity: slideAnimation.running ? 0 : 1

                        Loader {
                            id: calendarLoader; active: root.currentTab === 2 || Math.abs(contentRow.x) > root.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: StyledContainer {
                                implicitWidth: root.width - (Widget.padding * 2)
                                height: 2000
                                containerColor: Theme.foregroundAlt
                                StyledText {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Calendar Widget Placeholder"
                                    textColor: Theme.background
                                }
                            }
                        }
                    }

                    StyledScrollView {
                        width: root.width; height: parent.height
                        contentPadding: Widget.padding
                        scrollbarOpacity: slideAnimation.running ? 0 : 1

                        Loader {
                            id: notificationLoader; active: root.currentTab === 3 || contentRow.x < -(root.width * 2)
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: StyledContainer {
                                implicitWidth: root.width - (Widget.padding * 2)
                                height: 500; containerColor: Theme.foregroundAlt
                                StyledText {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Notifications Widget Placeholder"
                                    textColor: Theme.background
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
