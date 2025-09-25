pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.widgets.menu
import qs.components.reusable

StyledContainer {
    id: root

    // --- Public Properties ---
    property real customWidth: 0
    property real customHeight: 0
    property real minimumScrollableHeight: 250
    property bool mediaPlaying: false
    property int panelMargin: 10 // Unified margin for the panel's main sections

    // --- Fallback Sizing ---
    implicitWidth: 600
    implicitHeight: Display.resolutionHeight - Widget.containerWidth * 4

    // --- Root Component Sizing Logic ---
    width: customWidth > 0 ? customWidth : implicitWidth
    height: Math.max(customHeight > 0 ? customHeight : implicitHeight, _minimumRequiredHeight)

    // --- Internal Properties ---
    property real topSectionHeight: 120
    property real quickSettingsHeight: 60

    // REFACTORED: Simplified and more accurate calculation based on the new layout structure.
    readonly property real _minimumRequiredHeight: {
        var total = 0;
        total += topSection.height;
        total += minimumScrollableHeight;
        total += bottomArea.implicitHeight;
        // Add all margins and spacing controlled by panelMargin
        // 1. Top margin of topAreaLayout
        // 2. Spacing inside topAreaLayout
        // 3. Spacing between topAreaLayout and bottomArea
        // 4. Bottom margin of bottomArea
        total += (panelMargin * 4);
        return total;
    }

    // --- Component Styling ---
    containerBorderWidth: Appearance.borderWidth
    containerBorderColor: Theme.border
    containerColor: Theme.background

    // --- Bottom-Anchored Layout Area ---
    // This container holds all bottom-anchored items.
    ColumnLayout {
        id: bottomArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // REFACTORED: Margins are now consistently controlled by panelMargin
        anchors.bottomMargin: root.panelMargin
        anchors.leftMargin: root.panelMargin
        anchors.rightMargin: root.panelMargin

        spacing: Widget.containerWidth // Internal spacing between items in this section

        // -- Add new bottom-anchored components here. They will stack automatically. --
        PowerPanelMediaControl {
            id: mediaControl
            Layout.fillWidth: true
            playing: root.mediaPlaying
            visible: root.mediaPlaying
            containerColor: Theme.accent
        }

        PowerPanelQuickSettings {
            Layout.fillWidth: true
            Layout.preferredHeight: root.quickSettingsHeight
        }
    }

    // --- Top-Anchored and Fill Layout Area ---
    // REFACTORED: This is now a ColumnLayout, replacing the old 'Item' with manual anchors.
    // It dynamically manages the top section and the main scrollable content area.
    ColumnLayout {
        id: topAreaLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // Anchor the bottom of this layout to the top of the bottom layout
        anchors.bottom: bottomArea.top
        
        // REFACTORED: Margins and spacing are now consistently controlled by panelMargin
        anchors.topMargin: root.panelMargin
        anchors.leftMargin: root.panelMargin
        anchors.rightMargin: root.panelMargin
        anchors.bottomMargin: bottomArea.visibleChildren.length > 0 ? root.panelMargin : 0
        spacing: root.panelMargin

        // This is the fixed-height top section.
        StyledContainer {
            id: topSection
            Layout.fillWidth: true
            Layout.preferredHeight: root.topSectionHeight // Layout respects preferred height
            containerBorderColor: Theme.border

            // Note: Anchors are relative to this container now, not the whole panel.
            StyledText {
                anchors.centerIn: parent
                text: "Top Section - Reserved for Future Component"
                textColor: Theme.foregroundAlt
            }
        }

        // -- Add other fixed-height top components here. They will stack automatically. --

        // This is the primary scrollable content area.
        // REFACTORED: Using Layout.fillHeight, it automatically expands to fill the
        // remaining space within this ColumnLayout.
        PowerPanelTabs {
            id: tabbedContent
            Layout.fillWidth: true
            Layout.fillHeight: true // This is the key to making it fill the space
        }
    }

    // Timer for demonstration
    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            root.mediaPlaying = !root.mediaPlaying
        }
    }
}
