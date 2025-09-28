import QtQuick
import QtQuick.Shapes
import Quickshell

import qs.config

PanelWindow {
  id: workspaceContainer

  // --- Configuration Properties ---
  property int screenMargin: 10
  property int frameWidth: 8
  property int outerBorderRadius: 0  // Sharp outer corners
  property int innerBorderRadius: 12  // Radius for inner cutout
  property color frameColor: "green"
  property color centerColor: "transparent"
  property color outerStrokeColor: "red"
  property color innerStrokeColor: "blue"
  property int strokeWidth: 1
  property bool antialiasing: true  // Changed to true for smoother curves
  
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
      // Add these for smoother rendering
      layer.enabled: true
      layer.samples: 8  // Multisampling for smoother edges

      // Main frame path with hole
      ShapePath {
        id: framePath
        fillColor: workspaceContainer.frameColor
        strokeColor: "transparent"  // Remove stroke from main shape
        strokeWidth: 0
        fillRule: ShapePath.OddEvenFill
        joinStyle: ShapePath.RoundJoin  // Smoother joins
        capStyle: ShapePath.RoundCap    // Smoother caps

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var outerR = workspaceContainer.outerBorderRadius;
            var innerR = workspaceContainer.innerBorderRadius;
            var fw = workspaceContainer.frameWidth;
            
            // Ensure inner radius doesn't exceed frame width
            innerR = Math.min(innerR, fw);
            
            // Determine which edge has the bar (no frame on bar edge)
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
            var innerLeft = barAtLeft ? 0 : fw;
            var innerTop = barAtTop ? 0 : fw;
            var innerRight = barAtRight ? w : w - fw;
            var innerBottom = barAtBottom ? h : h - fw;
            
            // Always keep the rounded corners for visual appeal
            // But adjust positions based on bar location
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
            var innerLeft = barAtLeft ? 0 : fw;
            var innerTop = barAtTop ? 0 : fw;
            var innerRight = barAtRight ? w : w - fw;
            var innerBottom = barAtBottom ? h : h - fw;

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
