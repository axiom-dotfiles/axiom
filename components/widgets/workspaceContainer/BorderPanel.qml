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
    console.log("BorderPanel on edge:", edge);
  }
  
  property int inset: innerBorderRadius
  property bool isHorizontal: edge === "top" || edge === "bottom"
  property bool isVertical: edge === "left" || edge === "right"
  
  // Always anchor to the full edge
  anchors {
    left: edge === "left" || edge === "top" || edge === "bottom"
    right: edge === "right" || edge === "top" || edge === "bottom"
    top: edge === "top" || edge === "left" || edge === "right"
    bottom: edge === "bottom" || edge === "left" || edge === "right"
  }
  
  margins {
    left: 0
    right: 0
    top: 0
    bottom: 0
  }
  
  // Panel always takes frameWidth - largest possible thickness
  width: isVertical ? frameWidth : undefined
  height: isHorizontal ? frameWidth : undefined
  
  exclusiveZone: frameWidth
  aboveWindows: true
  color: "transparent"
  mask: Region {}
  
  // Fill rectangle
  Rectangle {
    anchors.fill: parent
    color: border.frameColor
  }
  
  // Inner stroke rectangle - positioned toward center
  Rectangle {
    color: border.innerStrokeColor
    
    anchors {
      // Horizontal edges (top/bottom)
      left: border.isHorizontal ? parent.left : undefined
      right: border.isHorizontal ? parent.right : undefined
      leftMargin: border.isHorizontal ? (border.frameWidth + border.inset) : 0
      rightMargin: border.isHorizontal ? (border.frameWidth + border.inset) : 0
      
      // Vertical edges (left/right)
      top: border.isVertical ? parent.top : undefined
      bottom: border.isVertical ? parent.bottom : undefined
      topMargin: border.isVertical ? border.inset : 0
      bottomMargin: border.isVertical ? border.inset : 0
    }
    
    // Position towards center based on edge
    x: border.edge === "left" ? (border.frameWidth - border.strokeWidth) : (border.isVertical ? 0 : undefined)
    y: border.edge === "top" ? (border.frameWidth - border.strokeWidth) : (border.isHorizontal ? 0 : undefined)
    
    width: border.isVertical ? border.strokeWidth : (parent.width - (border.frameWidth + border.inset) * 2)
    height: border.isHorizontal ? border.strokeWidth : (parent.height - border.inset * 2)
  }
}
