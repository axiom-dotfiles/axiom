import QtQuick
import Quickshell
import qs.config
Item {
  id: root
  property var screen: null
  property int frameWidth: Appearance.screenMargin
  property int innerBorderRadius: 12
  property color frameColor: Theme.background
  property color innerStrokeColor: Theme.foreground
  property color centerColor: "transparent"
  property int strokeWidth: Appearance.borderWidth
  
  Component.onCompleted: {
    console.log("RoundedBorders initialized");
  }
  
  // Top border
  BorderPanel {
    screen: root.screen
    edge: "top"
    frameWidth: root.frameWidth
    innerBorderRadius: root.innerBorderRadius
    frameColor: root.frameColor
    innerStrokeColor: root.innerStrokeColor
    strokeWidth: root.strokeWidth
  }
  
  // Bottom border
  BorderPanel {
    screen: root.screen
    edge: "bottom"
    frameWidth: root.frameWidth
    innerBorderRadius: root.innerBorderRadius
    frameColor: root.frameColor
    innerStrokeColor: root.innerStrokeColor
    strokeWidth: root.strokeWidth
  }
  
  // Left border
  BorderPanel {
    screen: root.screen
    edge: "left"
    frameWidth: root.frameWidth
    innerBorderRadius: root.innerBorderRadius
    frameColor: root.frameColor
    innerStrokeColor: root.innerStrokeColor
    strokeWidth: root.strokeWidth
  }
  
  // Right border
  BorderPanel {
    screen: root.screen
    edge: "right"
    frameWidth: root.frameWidth
    innerBorderRadius: root.innerBorderRadius
    frameColor: root.frameColor
    innerStrokeColor: root.innerStrokeColor
    strokeWidth: root.strokeWidth
  }
  
  // TODO: Corner SVG components will be added here
}
