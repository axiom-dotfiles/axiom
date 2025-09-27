pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls // For BusyIndicator

import qs.config
import qs.services
import qs.components.reusable
import qs.components.widgets.popouts
import qs.components.widgets.menu // For TabBar

Item {
  id: themeSelectorRoot

    // --- Configuration ---
    // You might want to move these to a central config file like Appearance.qml
    readonly property int wallpaperPreviewSize: 120
    readonly property int columnSpacing: Widget.padding * 2
    readonly property int internalPadding: Widget.padding
EdgePopup {
  id: root
    

    // --- Sizing ---
    // The component sizes itself based on its content.

    // --- EdgePopup Properties ---
    panelId: "themeSelector"
    edge: EdgePopup.Edge.Top
    position: 0.5
    active: false
    enableTrigger: true
    customHeight: mainContainer.implicitHeight + (Appearance.borderWidth * 2)
    customWidth: mainContainer.implicitWidth + (Appearance.borderWidth * 2)
    triggerLength: 5
    closeOnClickOutside: true
    aboveWindows: true
    edgeMargin: Config.containerOffset

    animationDuration: 200
    easingType: Easing.OutQuad

    // --- Connections to Singleton ---
    Connections {
        target: ThemeManager
        function onGenerationFailed(errorText) {
            Notifs.sendNotification(
                "Theme Generation",
                "Failed to generate themes",
                "There was an error while processing the wallpaper. Details: " + errorText,
                {}
            )
        }
    }

    StyledContainer {
        id: mainContainer
      
        anchors.fill: parent
        containerColor: Theme.backgroundAlt
        containerBorderColor: Theme.accent
        containerBorderWidth: Appearance.borderWidth
        containerRadius: Appearance.borderRadius
        implicitWidth: Math.max(1, (themeSelectorRoot.wallpaperPreviewSize * 3) + (themeSelectorRoot.internalPadding * 4) + themeSelectorRoot.columnSpacing + 250) // 250 for the right column width
        implicitHeight: Math.max(1, (themeSelectorRoot.wallpaperPreviewSize * 2) + (themeSelectorRoot.internalPadding * 3))
        RowLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: internalPadding
            spacing: columnSpacing

            //=================================================================
            // LEFT: Wallpaper Grid
            //=================================================================
            StyledScrollView {
                id: wallpaperScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentPadding: internalPadding
                showScrollBar: true

                GridView {
                    id: wallpaperGrid
                    model: ThemeManager.wallpaperModel
                    cellWidth: wallpaperPreviewSize + internalPadding
                    cellHeight: wallpaperPreviewSize + internalPadding

                    delegate: Item {
                        required property var modelData
                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight

                        property bool isActive: Config.wallpaper === modelData.fileUrl
                        property bool isHovered: wallpaperMouseArea.hovered

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: internalPadding / 2
                            radius: Appearance.borderRadius
                            border.width: Appearance.borderWidth * 2
                            border.color: isActive ? Theme.accent : (isHovered ? Theme.accentAlt : "transparent")
                            clip: true

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Image {
                                id: wallpaperImage
                                anchors.fill: parent
                                source: modelData.fileUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MouseArea {
                                id: wallpaperMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                property bool hovered: false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeManager.generateThemesFromWallpaper(modelData.fileUrl)
                                onEntered: hovered = true
                                onExited: hovered = false
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "No wallpapers found in pictures/wallpapers"
                    textColor: Theme.foregroundAlt
                    visible: ThemeManager.wallpaperModel.count === 0 && !ThemeManager.isGenerating
                }

                // Loading Overlay
                Rectangle {
                    anchors.fill: parent
                    color: "#99000000" // Semi-transparent overlay
                    radius: Appearance.borderRadius
                    visible: ThemeManager.isGenerating

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: parent.visible
                    }
                }
            }

            //=================================================================
            // RIGHT: Controls
            //=================================================================
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                spacing: internalPadding

                // --- Dark Mode Toggle ---
                StyledContainer {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    containerColor: Theme.background
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: internalPadding
                        anchors.rightMargin: internalPadding

                        StyledText {
                            text: "Automatic Dark Mode"
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: Appearance.autoThemeSwitch
                            onToggled: ThemeManager.toggleDarkMode()
                        }
                    }
                }

                // --- Theme Source Tabs ---
                TabBar {
                    id: themeSourceTabs
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    tabs: [{ name: "Default" }, { name: "Generated" }]
                    onTabClicked: (index) => themeStack.currentIndex = index
                }

                // --- Theme Lists (in a Stack) ---
                StackLayout {
                    id: themeStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: themeSourceTabs.currentTab

                    // View for Default Themes
                    StyledScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentPadding: internalPadding
                        showScrollBar: true

                        ListView {
                            model: ThemeManager.defaultThemes
                            spacing: internalPadding / 2
                            delegate: StyledTextButton {
                                required property var modelData
                                width: parent.width // Use available width
                                text: modelData.name
                                backgroundColor: Appearance.theme === modelData.name ? Theme.accent : Theme.backgroundHighlight
                                textHoverColor: Appearance.theme === modelData.name ? Theme.foreground : Theme.background
                                onClicked: ThemeManager.applyTheme(modelData.name)
                                Component.onCompleted: {
                                  console.log("Default Theme Found: " + modelData.name);
                                }
                            }
                        }

                        StyledText {
                           anchors.centerIn: parent
                           text: "No default themes found."
                           textColor: Theme.foregroundAlt
                           visible: ThemeManager.defaultThemes.count === 0
                        }
                    }

                    // View for Generated Themes
                    StyledScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentPadding: internalPadding
                        showScrollBar: true

                        ListView {
                            model: ThemeManager.generatedThemes
                            spacing: internalPadding / 2
                            delegate: StyledTextButton {
                                required property var modelData
                                width: parent.width // Use available width
                                text: modelData.name
                                backgroundColor: Appearance.theme === modelData.name ? Theme.accent : Theme.backgroundHighlight
                                textHoverColor: Appearance.theme === modelData.name ? Theme.foreground : Theme.background
                                onClicked: ThemeManager.applyTheme(modelData.name)
                            }
                        }
                        
                        StyledText {
                           anchors.centerIn: parent
                           text: "Select a wallpaper to generate themes."
                           textColor: Theme.foregroundAlt
                           wrapMode: Text.WordWrap
                           horizontalAlignment: Text.AlignHCenter
                           visible: ThemeManager.generatedThemes.count === 0
                        }
                    }
                }
            }
        }
    }
}

}
