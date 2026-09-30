pragma ComponentBehavior: Bound
import QtQuick

import qs.config

// Layout helper for the bar: a divider line, a dot, or plain space, taking
// exactly `size` px along the bar.
BarWidget {
  id: root

  readonly property color color: Theme.resolveColor(properties.color)

  // BarWidgetHost sizing contract
  readonly property string sizePolicy: "fixed"
  readonly property real preferredSize: properties.size

  implicitWidth: isVertical ? root.barConfig.widgetSize : properties.size
  implicitHeight: isVertical ? properties.size : root.barConfig.widgetSize

  // Across the bar, so it divides the modules on either side
  Rectangle {
    visible: root.properties.style === "line"
    anchors.centerIn: parent
    readonly property real span: root.barConfig.widgetSize * root.properties.length / 100
    width: root.isVertical ? span : root.properties.thickness
    height: root.isVertical ? root.properties.thickness : span
    radius: root.properties.thickness / 2
    color: root.color
  }

  Rectangle {
    visible: root.properties.style === "dot"
    anchors.centerIn: parent
    width: root.properties.thickness * 2
    height: width
    radius: width / 2
    color: root.color
  }
}
