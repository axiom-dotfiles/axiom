import QtQuick
import QtQuick.Layouts

// Your project's imports
import qs.services
import qs.config
import qs.components.reusable

StyledContainer {
    id: root

    visible: Mpris.hasActivePlayer
    clip: true

    Layout.preferredHeight: Mpris.hasActivePlayer ? 80 : 0

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    Connections {
        target: Mpris
        function onArtReady() {
            albumArt.source = Mpris.artFilePath + "?time=" + Date.now()
        }
    }

    Loader {
        id: mediaControlLoader
        anchors.fill: parent
        anchors.margins: Widget.padding
        active: root.visible

        sourceComponent: RowLayout {
            spacing: 12

            // --- Album Art ---
            StyledContainer {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                // ...
                Image { id: albumArt; /* ... */ }
            }

            // --- Track Info & Progress ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText { text: Mpris.trackTitle; /* ... */ }
                StyledText { text: Mpris.trackArtist; /* ... */ }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText { text: Mpris.formatTime(Mpris.position); /* ... */ }

                    StyledSlider {
                        Layout.fillWidth: true
                        enabled: Mpris.canSeek
                        // BIND: Display the current progress
                        value: Mpris.progress

                        // ACTION: On release, tell the controller to seek
                        onReleased: (newValue) => Mpris.setPositionByRatio(newValue)
                    }

                    StyledText { text: Mpris.formatTime(Mpris.length); /* ... */ }
                }
            }

            // --- Playback & Volume Controls ---
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                StyledIconButton { /* Previous Button */ onClicked: Mpris.previous(); /* ... */ }
                StyledIconButton { /* Play/Pause Button */ onClicked: Mpris.togglePlayPause(); /* ... */ }
                StyledIconButton { /* Next Button */ onClicked: Mpris.next(); /* ... */ }

                Item { Layout.preferredWidth: 10 } // Spacer

                // --- CORRECTED VOLUME SLIDER ---
                // The visibility is now based on the player supporting the volume property.
                visible: Mpris.activePlayer?.volumeSupported ?? false

                StyledText {
                    text: "󰕾" // Volume icon
                    textSize: Appearance.fontSize
                    textColor: Theme.foregroundAlt
                }

                StyledSlider {
                    Layout.preferredWidth: 80
                    
                    // BIND: Display the current volume level
                    value: Mpris.activePlayer ? Mpris.activePlayer.volume : 0

                    // ACTION: While dragging, update the player's volume directly.
                    // This uses the 'moved' signal for live updates.
                    onMoved: (newValue) => {
                        if (Mpris.activePlayer) {
                            Mpris.activePlayer.volume = newValue;
                        }
                    }
                }
                
                // Added volume percentage from your example
                StyledText {
                    // Use a ternary to avoid "NaN" if player disappears mid-render
                    text: Mpris.activePlayer ? Math.round(Mpris.activePlayer.volume * 100) + "%" : "0%"
                    textColor: Theme.foregroundAlt
                    textSize: Appearance.fontSize - 4
                    Layout.preferredWidth: 35 // Reserve space to prevent layout shifts
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
