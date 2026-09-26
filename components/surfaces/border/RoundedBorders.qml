import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.reusable

Item {
  id: root
  property var screen: null
  property int frameWidth: Appearance.screenMargin
  // TODO: breaks on change to borderWidth
  property int innerBorderRadius: Appearance.borderRadius
  property int curveSize: innerBorderRadius - Appearance.borderWidth
  property color frameColor: Theme.background
  property color innerStrokeColor: Theme.foreground
  property color centerColor: "transparent"
  property int strokeWidth: Appearance.borderWidth

  // Corners sit in the space left once every edge is reserved, so a
  // floating bar (inside the border, reserving its own space) would push
  // them in past it. Pull them back out to the border's corners.
  readonly property var edges: Bar.edgesFor(root.screen)
  function cornerMargin(edge) {
    const bar = root.edges[edge];
    if (!bar?.floating || !bar.reserveSpace)
      return -root.strokeWidth;
    // A transparent bar reserves gaps_out less (see BarPanel)
    const gap = bar.background === "transparent" ? (HyprlandManager.gapsOut[edge] ?? 0) : 0;
    return -(bar.extent - gap);
  }

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
    // frameColor: "green"
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
    margins {
      left: root.cornerMargin("left")
      top: root.cornerMargin("top")
    }
    implicitWidth: curveSize + strokeWidth * 2
    implicitHeight: curveSize + strokeWidth * 2
    color: "transparent"
    // color: "red"
    mask: Region {}
    aboveWindows: true
    // WlrLayershell.layer: WlrLayer.Overlay

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
    margins {
      right: root.cornerMargin("right")
      top: root.cornerMargin("top")
    }
    implicitWidth: curveSize + strokeWidth * 2
    implicitHeight: curveSize + strokeWidth * 2
    // color: "red"
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    // WlrLayershell.layer: WlrLayer.Overlay

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
    margins {
      left: root.cornerMargin("left")
      bottom: root.cornerMargin("bottom")
    }
    implicitWidth: curveSize + strokeWidth * 2
    implicitHeight: curveSize + strokeWidth * 2
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    // WlrLayershell.layer: WlrLayer.Overlay

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
    margins {
      right: root.cornerMargin("right")
      bottom: root.cornerMargin("bottom")
    }
    implicitWidth: curveSize + strokeWidth * 2
    implicitHeight: curveSize + strokeWidth * 2
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    // WlrLayershell.layer: WlrLayer.Overlay

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
