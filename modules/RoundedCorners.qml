import QtQuick
import QtQuick.Shapes
import Quickshell

import qs.config

PanelWindow {
  id: workspaceContainer

  // --- Configuration Properties ---
  property int screenMargin: 10
  property int frameWidth: 8
  property int outerBorderRadius: 0
  property int innerBorderRadius: 12
  property color frameColor: Theme.background
  property color centerColor: "transparent"
  property color outerStrokeColor: "transparent"
  property color innerStrokeColor: Theme.foreground
  property int strokeWidth: 1
  property bool antialiasing: true

  // --- Bar Configuration Properties ---
  readonly property bool vertical: Bar.vertical ?? false
  readonly property bool rightSide: Bar.rightSide ?? false

  // --- Panel Configuration ---
  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }
  aboveWindows: true
  color: "transparent"
  mask: Region {}

  Rectangle {
    id: frameRect
    anchors.fill: parent
    color: "transparent"

    Shape {
      id: frameShape
      anchors.fill: parent
      antialiasing: workspaceContainer.antialiasing
      layer.enabled: true
      layer.samples: 8

      // Main frame path with hole
      ShapePath {
        id: framePath
        fillColor: workspaceContainer.frameColor
        strokeColor: "transparent"
        strokeWidth: 0
        fillRule: ShapePath.OddEvenFill
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var outerR = workspaceContainer.outerBorderRadius;
            var innerR = workspaceContainer.innerBorderRadius;
            var fw = workspaceContainer.frameWidth;

            // Ensure inner radius doesn't exceed frame width
            innerR = Math.min(innerR, fw);

            // Determine which edge has the bar
            var barAtTop = !workspaceContainer.vertical && !workspaceContainer.rightSide;
            var barAtLeft = workspaceContainer.vertical && !workspaceContainer.rightSide;
            var barAtBottom = !workspaceContainer.vertical && workspaceContainer.rightSide;
            var barAtRight = workspaceContainer.vertical && workspaceContainer.rightSide;

            // --- OUTER PATH (Clockwise) ---
            var path = "";

            if (outerR > 0) {
              path = "M " + outerR + ",0";
              path += " L " + (w - outerR) + ",0";
              path += " Q " + w + ",0 " + w + "," + outerR;
              path += " L " + w + "," + (h - outerR);
              path += " Q " + w + "," + h + " " + (w - outerR) + "," + h;
              path += " L " + outerR + "," + h;
              path += " Q 0," + h + " 0," + (h - outerR);
              path += " L 0," + outerR;
              path += " Q 0,0 " + outerR + ",0";
            } else {
              // Sharp corners
              path = "M 0,0";
              path += " L " + w + ",0";
              path += " L " + w + "," + h;
              path += " L 0," + h;
              path += " L 0,0";
            }
            path += " Z";

            // --- INNER PATH (Counter-Clockwise) ---
            // Calculate inner rectangle bounds
            // Offset by half stroke width when at screen edge to keep stroke fully visible
            var halfStroke = workspaceContainer.strokeWidth / 2;
            var innerLeft = barAtLeft ? halfStroke : fw;
            var innerTop = barAtTop ? halfStroke : fw;
            var innerRight = barAtRight ? w - halfStroke : w - fw;
            var innerBottom = barAtBottom ? h - halfStroke : h - fw;

            // Always keep rounded corners for visual consistency
            var topLeftR = innerR;
            var topRightR = innerR;
            var bottomRightR = innerR;
            var bottomLeftR = innerR;

            // Build inner path counter-clockwise with curves
            // Start at left edge, just below top-left corner
            path += " M " + innerLeft + "," + Math.min(innerTop + topLeftR, innerBottom);

            // Top-left corner
            path += " Q " + innerLeft + "," + innerTop + " " + (innerLeft + topLeftR) + "," + innerTop;

            // Top edge
            path += " L " + (innerRight - topRightR) + "," + innerTop;

            // Top-right corner
            path += " Q " + innerRight + "," + innerTop + " " + innerRight + "," + (innerTop + topRightR);

            // Right edge
            path += " L " + innerRight + "," + (innerBottom - bottomRightR);

            // Bottom-right corner
            path += " Q " + innerRight + "," + innerBottom + " " + (innerRight - bottomRightR) + "," + innerBottom;

            // Bottom edge
            path += " L " + (innerLeft + bottomLeftR) + "," + innerBottom;

            // Bottom-left corner
            path += " Q " + innerLeft + "," + innerBottom + " " + innerLeft + "," + (innerBottom - bottomLeftR);

            // Close path
            path += " Z";

            return path;
          }
        }
      }

      // Outer border stroke (separate path)
      ShapePath {
        fillColor: "transparent"
        strokeColor: workspaceContainer.outerStrokeColor
        strokeWidth: workspaceContainer.strokeWidth
        joinStyle: ShapePath.RoundJoin

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var outerR = workspaceContainer.outerBorderRadius;

            var path = "";
            if (outerR > 0) {
              path = "M " + outerR + ",0";
              path += " L " + (w - outerR) + ",0";
              path += " Q " + w + ",0 " + w + "," + outerR;
              path += " L " + w + "," + (h - outerR);
              path += " Q " + w + "," + h + " " + (w - outerR) + "," + h;
              path += " L " + outerR + "," + h;
              path += " Q 0," + h + " 0," + (h - outerR);
              path += " L 0," + outerR;
              path += " Q 0,0 " + outerR + ",0";
            } else {
              path = "M 0,0 L " + w + ",0 L " + w + "," + h + " L 0," + h + " L 0,0";
            }
            path += " Z";
            return path;
          }
        }
      }

      // Inner border stroke (separate path)
      ShapePath {
        fillColor: "transparent"
        strokeColor: workspaceContainer.innerStrokeColor
        strokeWidth: workspaceContainer.strokeWidth
        joinStyle: ShapePath.RoundJoin

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var innerR = Math.min(workspaceContainer.innerBorderRadius, workspaceContainer.frameWidth);
            var fw = workspaceContainer.frameWidth;

            // Determine which edge has the bar
            var barAtTop = !workspaceContainer.vertical && !workspaceContainer.rightSide;
            var barAtLeft = workspaceContainer.vertical && !workspaceContainer.rightSide;
            var barAtBottom = !workspaceContainer.vertical && workspaceContainer.rightSide;
            var barAtRight = workspaceContainer.vertical && workspaceContainer.rightSide;

            // Calculate inner rectangle bounds
            // Offset by half stroke width when at screen edge to keep stroke fully visible
            var halfStroke = workspaceContainer.strokeWidth / 2;
            var innerLeft = barAtLeft ? halfStroke : fw;
            var innerTop = barAtTop ? halfStroke : fw;
            var innerRight = barAtRight ? w - halfStroke : w - fw;
            var innerBottom = barAtBottom ? h - halfStroke : h - fw;

            // Keep all corners rounded
            var topLeftR = innerR;
            var topRightR = innerR;
            var bottomRightR = innerR;
            var bottomLeftR = innerR;

            // Build path clockwise for stroke
            var path = "M " + (innerLeft + topLeftR) + "," + innerTop;

            // Top edge
            path += " L " + (innerRight - topRightR) + "," + innerTop;

            // Top-right corner
            path += " Q " + innerRight + "," + innerTop + " " + innerRight + "," + (innerTop + topRightR);

            // Right edge
            path += " L " + innerRight + "," + (innerBottom - bottomRightR);

            // Bottom-right corner
            path += " Q " + innerRight + "," + innerBottom + " " + (innerRight - bottomRightR) + "," + innerBottom;

            // Bottom edge
            path += " L " + (innerLeft + bottomLeftR) + "," + innerBottom;

            // Bottom-left corner
            path += " Q " + innerLeft + "," + innerBottom + " " + innerLeft + "," + (innerBottom - bottomLeftR);

            // Left edge
            path += " L " + innerLeft + "," + (innerTop + topLeftR);

            // Top-left corner
            path += " Q " + innerLeft + "," + innerTop + " " + (innerLeft + topLeftR) + "," + innerTop;

            path += " Z";

            return path;
          }
        }
      }
    }
  }
}
