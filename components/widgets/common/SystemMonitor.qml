import QtQuick
import QtQuick.Layouts

import qs.config

ColumnLayout {
  id: root
  
  property string label: "Monitor"
  property string iconText: "●"
  property color iconColor: Theme.background
  property real percentage: 0
  property real temperature: 0
  property string unit: "°C"
  
  spacing: height * 0.05
  anchors.fill: parent
  
  // Label
  Text {
    Layout.alignment: Qt.AlignHCenter
    text: root.label
    font.pixelSize: parent.height * 0.08
    font.weight: Font.Medium
    color: root.iconColor
    opacity: 0.7
  }
  
  // Percentage Circle
  PercentageCircle {
    id: percentageCircle
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: parent.width * 0.6
    Layout.preferredHeight: Layout.preferredWidth
    percentage: root.percentage
    iconText: root.iconText
    iconColor: root.iconColor

    fillColor: root.percentage > 80 ? Theme.error : root.percentage > 50 ? Theme.warning : Theme.info
    backgroundColor: Theme.foreground
    backgroundOpacity: 0.1
  }
  
  // Percentage Text
  Text {
    Layout.alignment: Qt.AlignHCenter
    text: Math.round(root.percentage) + "%"
    font.pixelSize: parent.height * 0.12
    font.weight: Font.Bold
    color: root.percentage > 80 ? "#ef4444" : root.percentage > 50 ? "#f59e0b" : "#10b981"
  }
  
  // Temperature
  Text {
    Layout.alignment: Qt.AlignHCenter
    text: Math.round(temperature) + unit
    font.pixelSize: parent.height * 0.09
    font.weight: Font.Medium
    color: Theme.foreground
    opacity: 0.6
  }
}
