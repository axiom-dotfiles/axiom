pragma ComponentBehavior: Bound
import QtQuick

import qs.config
import qs.components.bar

// What a switcher shows after its workspaces on a strip monitor: a divider
// in the bar's separator style (a line when that's none), then the active
// workspace's windows in strip order (StripWindows). Nothing, divider
// included, while the workspace has none (`hasWindows`).
Grid {
  id: root

  required property var barConfig
  required property int workspaceId
  required property bool stripVertical
  required property real cell
  required property real cellRadius
  required property color activeColor
  required property color occupiedColor
  required property color textColor
  property bool clickable: true

  readonly property bool isVertical: barConfig.vertical
  readonly property bool hasWindows: windows.addresses.length > 0

  rows: isVertical ? 2 : 1
  columns: isVertical ? 1 : 2
  spacing: barConfig.widgetSpacing

  SeparatorMark {
    style: root.barConfig.separatorStyle === "none" ? "line" : root.barConfig.separatorStyle
    color: Theme.resolveColor(root.barConfig.separatorColor)
    thickness: root.barConfig.separatorThickness
    length: root.cell * (style === "chevron" ? 0.6 : 0.5)
    vertical: root.isVertical
    width: root.isVertical ? root.cell : implicitWidth
    height: root.isVertical ? implicitHeight : root.cell
  }

  StripWindows {
    id: windows
    barConfig: root.barConfig
    workspaceId: root.workspaceId
    stripVertical: root.stripVertical
    isVertical: root.isVertical
    thickness: root.cell
    cellLength: root.cell
    radius: root.cellRadius
    activeColor: root.activeColor
    occupiedColor: root.occupiedColor
    textColor: root.textColor
    clickable: root.clickable
  }
}
