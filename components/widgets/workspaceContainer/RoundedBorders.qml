import QtQuick
import Quickshell
import qs.config
import qs.components.reusable

Item {
  id: root
  property var screen: null
  property int frameWidth: Appearance.screenMargin
  property int innerBorderRadius: Appearance.borderRadius
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
    implicitWidth: frameWidth
    implicitHeight: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      borderRadius: root.innerBorderRadius
      fillColor: root.frameColor
      strokeColor: root.innerStrokeColor
      strokeWidth: root.strokeWidth
      isLeft: true
      isTop: true
    }
  }

  // Top-right corner
  PanelWindow {
    screen: root.screen
    anchors {
      right: true
      top: true
    }
    implicitWidth: frameWidth
    implicitHeight: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      borderRadius: root.innerBorderRadius
      fillColor: root.frameColor
      strokeColor: root.innerStrokeColor
      strokeWidth: root.strokeWidth
      isLeft: false
      isTop: true
    }
  }

  // Bottom-left corner
  PanelWindow {
    screen: root.screen
    anchors {
      left: true
      bottom: true
    }
    implicitWidth: frameWidth
    implicitHeight: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      borderRadius: root.innerBorderRadius
      fillColor: root.frameColor
      strokeColor: root.innerStrokeColor
      strokeWidth: root.strokeWidth
      isLeft: true
      isTop: false
    }
  }

  // Bottom-right corner
  PanelWindow {
    screen: root.screen
    anchors {
      right: true
      bottom: true
    }
    implicitWidth: frameWidth
    implicitHeight: frameWidth
    color: "transparent"
    mask: Region {}
    aboveWindows: true

    CornerPiece {
      borderRadius: root.innerBorderRadius
      fillColor: root.frameColor
      strokeColor: root.innerStrokeColor
      strokeWidth: root.strokeWidth
      isLeft: false
      isTop: false
    }
  }
}
