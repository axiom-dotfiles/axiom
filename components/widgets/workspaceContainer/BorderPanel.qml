import QtQuick
import Quickshell
import qs.config
PanelWindow {
  id: border
  required property string edge // "top", "bottom", "left", "right"
  required property int frameWidth
  required property int innerBorderRadius
  required property color frameColor
  required property color innerStrokeColor
  required property int strokeWidth
  
  Component.onCompleted: {
  }
  
  property int inset: innerBorderRadius
  property bool isHorizontal: edge === "top" || edge === "bottom"
  property bool isVertical: edge === "left" || edge === "right"
  
  anchors {
    left: edge === "left" || edge === "top" || edge === "bottom"
    right: edge === "right" || edge === "top" || edge === "bottom"
    top: edge === "top" || edge === "left" || edge === "right"
    bottom: edge === "bottom" || edge === "left" || edge === "right"
  }
  
  implicitWidth: isVertical ? frameWidth : 0
  implicitHeight: isHorizontal ? frameWidth : 0
  
  exclusiveZone: frameWidth
  aboveWindows: true
  color: "transparent"
  mask: Region {}
  
  Rectangle {
    anchors.fill: parent
    color: border.frameColor
  }
  
  Rectangle {
    color: border.innerStrokeColor
    
    anchors {
      left: border.isHorizontal ? parent.left : undefined
      right: border.isHorizontal ? parent.right : undefined
      leftMargin: border.isHorizontal ? (border.frameWidth + border.inset) : 0
      rightMargin: border.isHorizontal ? (border.frameWidth + border.inset) : 0
      
      top: border.isVertical ? parent.top : undefined
      bottom: border.isVertical ? parent.bottom : undefined
      topMargin: border.isVertical ? border.inset : 0
      bottomMargin: border.isVertical ? border.inset : 0
    }
    
    x: border.edge === "left" ? (border.frameWidth - border.strokeWidth) : (border.isVertical ? 0 : null)
    y: border.edge === "top" ? (border.frameWidth - border.strokeWidth) : (border.isHorizontal ? 0 : null)
    
    implicitWidth: border.isVertical ? border.strokeWidth : (parent.width - (border.frameWidth + border.inset))
    implicitHeight: border.isHorizontal ? border.strokeWidth : (parent.height - border.inset)
  }
}
