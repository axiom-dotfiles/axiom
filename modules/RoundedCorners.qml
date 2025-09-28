import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
  id: workspaceContainer

  // --- Configuration Properties ---
  property int screenMargin: 10
  property int frameWidth: 8
  property int outerBorderRadius: 0  // Sharp outer corners
  property int innerBorderRadius: 12  // Radius for inner cutout
  property color frameColor: "blue"
  property color centerColor: "transparent"
  property color outerStrokeColor: "darkblue"
  property color innerStrokeColor: "lightsteelblue"
  property int strokeWidth: 1
  property bool antialiasing: true  // Changed to true for smoother curves

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

            // --- OUTER PATH (Clockwise) ---
            var path = "";
            
            if (outerR > 0) {
              path = "M " + outerR + ",0";
              path += " L " + (w - outerR) + ",0";
              path += " Q " + w + ",0 " + w + "," + outerR;  // Use quadratic for smoother
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
            // Moving counter-clockwise from top-left
            if (innerR > 0) {
              // Start at left edge, just below top-left corner
              path += " M " + fw + "," + (fw + innerR);
              // Move up and arc to top edge (counter-clockwise)
              path += " Q " + fw + "," + fw + " " + (fw + innerR) + "," + fw;
              // Top edge moving right
              path += " L " + (w - fw - innerR) + "," + fw;
              // Top-right corner
              path += " Q " + (w - fw) + "," + fw + " " + (w - fw) + "," + (fw + innerR);
              // Right edge moving down
              path += " L " + (w - fw) + "," + (h - fw - innerR);
              // Bottom-right corner
              path += " Q " + (w - fw) + "," + (h - fw) + " " + (w - fw - innerR) + "," + (h - fw);
              // Bottom edge moving left
              path += " L " + (fw + innerR) + "," + (h - fw);
              // Bottom-left corner
              path += " Q " + fw + "," + (h - fw) + " " + fw + "," + (h - fw - innerR);
              // Left edge back to start
              path += " L " + fw + "," + (fw + innerR);
            } else {
              // Sharp inner corners (counter-clockwise)
              path += " M " + fw + "," + fw;
              path += " L " + fw + "," + (h - fw);
              path += " L " + (w - fw) + "," + (h - fw);
              path += " L " + (w - fw) + "," + fw;
              path += " L " + fw + "," + fw;
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

            var path = "";
            if (innerR > 0) {
              // Clockwise for stroke-only path
              path = "M " + (fw + innerR) + "," + fw;
              path += " L " + (w - fw - innerR) + "," + fw;
              path += " Q " + (w - fw) + "," + fw + " " + (w - fw) + "," + (fw + innerR);
              path += " L " + (w - fw) + "," + (h - fw - innerR);
              path += " Q " + (w - fw) + "," + (h - fw) + " " + (w - fw - innerR) + "," + (h - fw);
              path += " L " + (fw + innerR) + "," + (h - fw);
              path += " Q " + fw + "," + (h - fw) + " " + fw + "," + (h - fw - innerR);
              path += " L " + fw + "," + (fw + innerR);
              path += " Q " + fw + "," + fw + " " + (fw + innerR) + "," + fw;
            } else {
              path = "M " + fw + "," + fw;
              path += " L " + (w - fw) + "," + fw;
              path += " L " + (w - fw) + "," + (h - fw);
              path += " L " + fw + "," + (h - fw);
              path += " L " + fw + "," + fw;
            }
            path += " Z";
            return path;
          }
        }
      }
    }
  }
}
