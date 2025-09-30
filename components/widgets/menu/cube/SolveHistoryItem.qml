// qs/components/widgets/SolveHistoryItem.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable

StyledContainer {
  id: root

  property string scramble: "R U R' U' R U R' U'"
  property int time: 0 // in milliseconds

  // Function to format time, consistent with CubeTimer.qml
  function formatTime(ms) {
    var totalSeconds = Math.floor(ms / 1000);
    var minutes = Math.floor(totalSeconds / 60);
    var seconds = totalSeconds % 60;
    var milliseconds = ms % 1000;

    // Pad with leading zeros
    var paddedMinutes = String(minutes).padStart(2, '0');
    var paddedSeconds = String(seconds).padStart(2, '0');
    var paddedMilliseconds = String(Math.floor(milliseconds / 10)).padStart(2, '0'); // For hundredths

    // Using a period for the final separator for better readability in history lists
    return `${paddedMinutes}:${paddedSeconds}.${paddedMilliseconds}`;
  }

  // Determine color based on time in seconds
  readonly property color timeColor: {
    var seconds = time / 1000;
    if (seconds < 15) return Theme.accent;
    if (seconds < 20) return Theme.warning;
    return Theme.error;
  }

  // The width will be set by the ListView delegate that creates this component
  implicitHeight: mainLayout.implicitHeight + (Widget.padding * 2)
  containerColor: Theme.foreground

  ColumnLayout {
    id: mainLayout
    anchors.fill: parent
    anchors.margins: Widget.padding

    Text {
      text: root.scramble
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize
      color: Theme.backgroundAlt
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
    }

    Text {
      text: formatTime(root.time)
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize * 1.8
      font.bold: true
      color: root.timeColor
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: Widget.spacing
    }
  }
}
