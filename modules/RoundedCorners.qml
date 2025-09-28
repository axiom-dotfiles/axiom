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
            
            // Determine which edge has no frame based on Bar configuration
            var hasTopFrame = !workspaceContainer.vertical || !workspaceContainer.rightSide;
            var hasLeftFrame = !workspaceContainer.vertical || workspaceContainer.rightSide;
            var hasBottomFrame = workspaceContainer.vertical || !workspaceContainer.rightSide;
            var hasRightFrame = workspaceContainer.vertical || workspaceContainer.rightSide;
            
            // Adjust frame widths for each edge
            var topFw = hasTopFrame ? fw : 0;
            var bottomFw = hasBottomFrame ? fw : 0;
            var leftFw = hasLeftFrame ? fw : 0;
            var rightFw = hasRightFrame ? fw : 0;

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
            // Adjust corner radii based on which edges have frames
            var topLeftR = (hasTopFrame && hasLeftFrame) ? innerR : 0;
            var topRightR = (hasTopFrame && hasRightFrame) ? innerR : 0;
            var bottomRightR = (hasBottomFrame && hasRightFrame) ? innerR : 0;
            var bottomLeftR = (hasBottomFrame && hasLeftFrame) ? innerR : 0;
            
            // Calculate inner rectangle bounds
            var innerLeft = leftFw;
            var innerTop = topFw;
            var innerRight = w - rightFw;
            var innerBottom = h - bottomFw;
            
            // Build inner path counter-clockwise
            if (topLeftR > 0 || topRightR > 0 || bottomRightR > 0 || bottomLeftR > 0) {
              // Start at left edge, just below top-left corner
              path += " M " + innerLeft + "," + Math.min(innerTop + topLeftR, innerBottom);
              
              // Top-left corner
              if (topLeftR > 0) {
                path += " Q " + innerLeft + "," + innerTop + " " + (innerLeft + topLeftR) + "," + innerTop;
              } else {
                path += " L " + innerLeft + "," + innerTop;
                path += " L " + (innerLeft + topLeftR) + "," + innerTop;
              }
              
              // Top edge
              path += " L " + (innerRight - topRightR) + "," + innerTop;
              
              // Top-right corner
              if (topRightR > 0) {
                path += " Q " + innerRight + "," + innerTop + " " + innerRight + "," + (innerTop + topRightR);
              } else {
                path += " L " + innerRight + "," + innerTop;
                path += " L " + innerRight + "," + (innerTop + topRightR);
              }
              
              // Right edge
              path += " L " + innerRight + "," + (innerBottom - bottomRightR);
              
              // Bottom-right corner
              if (bottomRightR > 0) {
                path += " Q " + innerRight + "," + innerBottom + " " + (innerRight - bottomRightR) + "," + innerBottom;
              } else {
                path += " L " + innerRight + "," + innerBottom;
                path += " L " + (innerRight - bottomRightR) + "," + innerBottom;
              }
              
              // Bottom edge
              path += " L " + (innerLeft + bottomLeftR) + "," + innerBottom;
              
              // Bottom-left corner
              if (bottomLeftR > 0) {
                path += " Q " + innerLeft + "," + innerBottom + " " + innerLeft + "," + (innerBottom - bottomLeftR);
              } else {
                path += " L " + innerLeft + "," + innerBottom;
                path += " L " + innerLeft + "," + (innerBottom - bottomLeftR);
              }
              
              // Left edge back to start
              path += " L " + innerLeft + "," + Math.min(innerTop + topLeftR, innerBottom);
            } else {
              // Sharp inner corners (counter-clockwise)
              path += " M " + innerLeft + "," + innerTop;
              path += " L " + innerLeft + "," + innerBottom;
              path += " L " + innerRight + "," + innerBottom;
              path += " L " + innerRight + "," + innerTop;
              path += " L " + innerLeft + "," + innerTop;
            }
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
            
            // Determine which edge has no frame based on Bar configuration
            var hasTopFrame = !workspaceContainer.vertical || !workspaceContainer.rightSide;
            var hasBottomFrame = !workspaceContainer.vertical || workspaceContainer.rightSide;
            var hasLeftFrame = workspaceContainer.vertical || !workspaceContainer.rightSide;
            var hasRightFrame = workspaceContainer.vertical || workspaceContainer.rightSide;
            
            // Adjust frame widths for each edge
            var topFw = hasTopFrame ? fw : 0;
            var bottomFw = hasBottomFrame ? fw : 0;
            var leftFw = hasLeftFrame ? fw : 0;
            var rightFw = hasRightFrame ? fw : 0;
            
            // Adjust corner radii based on which edges have frames
            var topLeftR = (hasTopFrame && hasLeftFrame) ? innerR : 0;
            var topRightR = (hasTopFrame && hasRightFrame) ? innerR : 0;
            var bottomRightR = (hasBottomFrame && hasRightFrame) ? innerR : 0;
            var bottomLeftR = (hasBottomFrame && hasLeftFrame) ? innerR : 0;
            
            // Calculate inner rectangle bounds
            var innerLeft = leftFw;
            var innerTop = topFw;
            var innerRight = w - rightFw;
            var innerBottom = h - bottomFw;

            var path = "";
            if (topLeftR > 0 || topRightR > 0 || bottomRightR > 0 || bottomLeftR > 0) {
              // Clockwise for stroke-only path
              path = "M " + (innerLeft + topLeftR) + "," + innerTop;
              
              // Top edge
              path += " L " + (innerRight - topRightR) + "," + innerTop;
              
              // Top-right corner
              if (topRightR > 0) {
                path += " Q " + innerRight + "," + innerTop + " " + innerRight + "," + (innerTop + topRightR);
              } else {
                path += " L " + innerRight + "," + innerTop;
              }
              
              // Right edge
              path += " L " + innerRight + "," + (innerBottom - bottomRightR);
              
              // Bottom-right corner
              if (bottomRightR > 0) {
                path += " Q " + innerRight + "," + innerBottom + " " + (innerRight - bottomRightR) + "," + innerBottom;
              } else {
                path += " L " + innerRight + "," + innerBottom;
              }
              
              // Bottom edge
              path += " L " + (innerLeft + bottomLeftR) + "," + innerBottom;
              
              // Bottom-left corner
              if (bottomLeftR > 0) {
                path += " Q " + innerLeft + "," + innerBottom + " " + innerLeft + "," + (innerBottom - bottomLeftR);
              } else {
                path += " L " + innerLeft + "," + innerBottom;
              }
              
              // Left edge
              path += " L " + innerLeft + "," + (innerTop + topLeftR);
              
              // Top-left corner
              if (topLeftR > 0) {
                path += " Q " + innerLeft + "," + innerTop + " " + (innerLeft + topLeftR) + "," + innerTop;
              } else {
                path += " L " + innerLeft + "," + innerTop;
              }
            } else {
              path = "M " + innerLeft + "," + innerTop;
              path += " L " + innerRight + "," + innerTop;
              path += " L " + innerRight + "," + innerBottom;
              path += " L " + innerLeft + "," + innerBottom;
              path += " L " + innerLeft + "," + innerTop;
            }
            path += " Z";
            return path;
          }
        }
      }
    }
  }
}
