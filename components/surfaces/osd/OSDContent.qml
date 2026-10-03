pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// One OSD's bars, laid out by its settings: vertical bars side by side,
// horizontal bars as rows; or, along its edge, one line parallel to it
// (end to end when the bars run along it too).
Item {
  id: root

  // The OSD's entry (OSDConfig.osds)
  required property var osd
  required property string screenName
  // The edge it slides out of runs vertically
  property bool edgeVertical: false

  // A bar changed; `force` when the bar's showOsd says to open
  signal poked(bool force)

  // Length of each bar along its axis; the OSD grows with the bar count in
  // the other direction
  readonly property int barLength: 190
  readonly property int barSpacing: 20
  readonly property bool vertical: osd.orientation === "Vertical"

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    readonly property bool rowFlow: root.osd.alongEdge ? !root.edgeVertical : root.vertical
    flow: rowFlow ? GridLayout.LeftToRight : GridLayout.TopToBottom
    columnSpacing: root.barSpacing
    rowSpacing: root.barSpacing

    Repeater {
      // By count, so edits to a bar update it in place
      model: root.osd.bars.length

      delegate: OSDBar {
        required property int index

        entry: root.osd.bars[index]
        screenName: root.screenName
        vertical: root.vertical
        showPercent: root.osd.showPercent
        Layout.preferredWidth: root.vertical ? implicitWidth : root.barLength
        Layout.preferredHeight: root.vertical ? root.barLength : implicitHeight
        onPoked: root.poked(entry.showOsd)
      }
    }
  }
}
