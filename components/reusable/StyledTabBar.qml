pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// A row of equal-width tabs (StyledTabButtons), one per label in `tabs`.
// The owner keeps the current index: set `currentIndex`, and update it
// from tabClicked.
RowLayout {
  id: root

  property var tabs: []
  property int currentIndex: 0

  signal tabClicked(int index)

  Layout.fillWidth: true
  Layout.fillHeight: false
  Layout.preferredHeight: 32
  spacing: Widget.spacing
  uniformCellSizes: true

  Repeater {
    model: root.tabs

    StyledTabButton {
      required property int index
      required property string modelData
      text: modelData
      checked: root.currentIndex === index
      onClicked: root.tabClicked(index)
    }
  }
}
