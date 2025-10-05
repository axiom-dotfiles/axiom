import QtQuick
import Quickshell
import qs.config
import qs.components.reusable

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
    id: topBorder
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
    id: bottomBorder
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
    id: leftBorder
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
    id: rightBorder
    screen: root.screen
    edge: "right"
    frameWidth: root.frameWidth
    innerBorderRadius: root.innerBorderRadius
    frameColor: root.frameColor
    innerStrokeColor: root.innerStrokeColor
    strokeWidth: root.strokeWidth
  }
  
  // Top-left corner
  PanelWindow {
    screen: root.screen
    anchors {
      left: true
      top: true
    }
    width: frameWidth
    height: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      anchors.fill: parent
      corner: "top-left"
      radius: root.innerBorderRadius
      strokeWidth: root.strokeWidth
      fillColor: root.innerStrokeColor
    }
  }

  // Top-right corner
  PanelWindow {
    screen: root.screen
    anchors {
      right: true
      top: true
    }
    width: frameWidth
    height: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      anchors.fill: parent
      corner: "top-right"
      radius: root.innerBorderRadius
      strokeWidth: root.strokeWidth
      fillColor: root.innerStrokeColor
    }
  }

  // Bottom-left corner
  PanelWindow {
    screen: root.screen
    anchors {
      left: true
      bottom: true
    }
    width: frameWidth
    height: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      anchors.fill: parent
      corner: "bottom-left"
      radius: root.innerBorderRadius
      strokeWidth: root.strokeWidth
      fillColor: root.innerStrokeColor
    }
  }

  // Bottom-right corner
  PanelWindow {
    screen: root.screen
    anchors {
      right: true
      bottom: true
    }
    width: frameWidth
    height: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      anchors.fill: parent
      corner: "bottom-right"
      radius: root.innerBorderRadius
      strokeWidth: root.strokeWidth
      fillColor: root.innerStrokeColor
    }
  }
}
