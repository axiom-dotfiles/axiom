pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config

StyledContainer {
  id: root

  property int currentTab: 0
  property color activeColor: Theme.accent
  property color inactiveColor: Theme.foregroundAlt

  property var tabs: []
  signal tabClicked(int index)

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Widget.padding
    anchors.rightMargin: Widget.padding
    uniformCellSizes: true

    Repeater {
      model: root.tabs

      delegate: StyledTabButton {
        required property int index
        required property var modelData
        activeColor: root.activeColor
        inactiveColor: root.inactiveColor

        text: modelData.name
        checked: root.currentTab === index

        onClicked: root.tabClicked(index)
      }
    }
  }

  StyledSeparator {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    separatorColor: "transparent"
    separatorHeight: 10
  }
}
