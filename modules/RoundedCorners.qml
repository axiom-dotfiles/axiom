import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
  id: workspaceContainer

  // --- Configuration Properties ---
  property int screenMargin: 10
  property int frameWidth: 8
  property int outerBorderRadius: 0  // Changed to 0 for sharp outer corners
  property int innerBorderRadius: 12  // Radius for inner cutout
  property color frameColor: "blue"
  property color centerColor: "transparent"  // Color for the center area
  property color outerStrokeColor: "darkblue"  // Separate outer border color
  property color innerStrokeColor: "lightsteelblue"  // Inner border color
  property int strokeWidth: 1
  property bool antialiasing: false  // Toggle antialiasing

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

  // --- The Shape Definition for the Frame ---
  Rectangle {
    id: frameRect
    anchors.fill: parent
    color: "transparent"

    Shape {
      id: frameShape
      anchors.fill: parent
      antialiasing: workspaceContainer.antialiasing  // Control antialiasing

      // Optional: Add a background rectangle to ensure center is truly transparent
      ShapePath {
        fillColor: workspaceContainer.centerColor
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var fw = workspaceContainer.frameWidth;
            var innerR = workspaceContainer.innerBorderRadius;

            // Draw just the inner area
            return "M " + (fw + innerR) + "," + fw + " L " + (w - fw - innerR) + "," + fw + " A " + innerR + "," + innerR + " 0 0 1 " + (w - fw) + "," + (fw + innerR) + " L " + (w - fw) + "," + (h - fw - innerR) + " A " + innerR + "," + innerR + " 0 0 1 " + (w - fw - innerR) + "," + (h - fw) + " L " + (fw + innerR) + "," + (h - fw) + " A " + innerR + "," + innerR + " 0 0 1 " + fw + "," + (h - fw - innerR) + " L " + fw + "," + (fw + innerR) + " A " + innerR + "," + innerR + " 0 0 1 " + (fw + innerR) + "," + fw + " Z";
          }
        }
      }

      // Outer border with its own stroke color
      ShapePath {
        id: outerPath
        fillColor: workspaceContainer.frameColor
        strokeColor: workspaceContainer.outerStrokeColor
        strokeWidth: workspaceContainer.strokeWidth
        fillRule: ShapePath.WindingFill  // Try WindingFill instead
        joinStyle: ShapePath.MiterJoin   // Sharp corners
        capStyle: ShapePath.FlatCap       // Flat line ends

        PathSvg {
          path: {
            // Get dimensions from the shape
            var w = frameShape.width;
            var h = frameShape.height;
            var outerR = workspaceContainer.outerBorderRadius;
            var innerR = workspaceContainer.innerBorderRadius;
            var fw = workspaceContainer.frameWidth;
            var adjustedInnerR = Math.max(0, innerR);

            console.log("Dimensions: w=" + w + ", h=" + h + ", outerR=" + outerR + ", innerR=" + innerR + ", fw=" + fw);

            // --- OUTER PATH SEGMENTS (Clockwise) ---
            // Start at top-left
            var outerTopLeft = "M " + outerR + "," + 0;

            // Top edge
            var outerTopEdge = " L " + (w - outerR) + "," + 0;

            // Top-right corner (will be sharp if outerR is 0)
            var outerTopRightArc = (outerR > 0) ? " A " + outerR + "," + outerR + " 0 0 1 " + w + "," + outerR : " L " + w + "," + 0;

            // Right edge
            var outerRightEdge = " L " + w + "," + (h - outerR);

            // Bottom-right corner
            var outerBottomRightArc = (outerR > 0) ? " A " + outerR + "," + outerR + " 0 0 1 " + (w - outerR) + "," + h : " L " + w + "," + h;

            // Bottom edge
            var outerBottomEdge = " L " + outerR + "," + h;

            // Bottom-left corner
            var outerBottomLeftArc = (outerR > 0) ? " A " + outerR + "," + outerR + " 0 0 1 " + 0 + "," + (h - outerR) : " L " + 0 + "," + h;

            // Left edge
            var outerLeftEdge = " L " + 0 + "," + outerR;

            // Top-left corner (close the path)
            var outerTopLeftArc = (outerR > 0) ? " A " + outerR + "," + outerR + " 0 0 1 " + outerR + "," + 0 : " L " + 0 + "," + 0;

            var outerClosePath = " Z";

            // --- INNER PATH SEGMENTS (Counter-Clockwise) ---
            // Start at top-left of inner rectangle
            var innerTopLeft = "M " + (fw + adjustedInnerR) + "," + fw;

            // Top-left inner corner
            var innerTopLeftArc = (adjustedInnerR > 0) ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 1 " + fw + "," + (fw + adjustedInnerR) : " L " + fw + "," + fw;

            // Left inner edge
            var innerLeftEdge = " L " + fw + "," + (h - fw - adjustedInnerR);

            // Bottom-left inner corner
            var innerBottomLeftArc = (adjustedInnerR > 0) ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 1 " + (fw + adjustedInnerR) + "," + (h - fw) : " L " + fw + "," + (h - fw);

            // Bottom inner edge
            var innerBottomEdge = " L " + (w - fw - adjustedInnerR) + "," + (h - fw);

            // Bottom-right inner corner
            var innerBottomRightArc = (adjustedInnerR > 0) ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 1 " + (w - fw) + "," + (h - fw - adjustedInnerR) : " L " + (w - fw) + "," + (h - fw);

            // Right inner edge
            var innerRightEdge = " L " + (w - fw) + "," + (fw + adjustedInnerR);

            // Top-right inner corner
            var innerTopRightArc = (adjustedInnerR > 0) ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 1 " + (w - fw - adjustedInnerR) + "," + fw : " L " + (w - fw) + "," + fw;

            // Top inner edge (back to start)
            var innerTopEdge = " L " + (fw + adjustedInnerR) + "," + fw;

            var innerClosePath = " Z";

            // Combine all segments
            var fullOuterPath = outerTopLeft + outerTopEdge + outerTopRightArc + outerRightEdge + outerBottomRightArc + outerBottomEdge + outerBottomLeftArc + outerLeftEdge + outerTopLeftArc + outerClosePath;

            var fullInnerPath = innerTopLeft + innerTopLeftArc + innerLeftEdge + innerBottomLeftArc + innerBottomEdge + innerBottomRightArc + innerRightEdge + innerTopRightArc + innerTopEdge + innerClosePath;

            var completePath = fullOuterPath + " " + fullInnerPath;
            console.log("Path: " + completePath);
            return completePath;
          }
        }
      }

      // Inner border stroke (optional - draws just the inner cutout border)
      ShapePath {
        fillColor: "transparent"
        strokeColor: workspaceContainer.innerStrokeColor
        strokeWidth: workspaceContainer.strokeWidth

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var innerR = workspaceContainer.innerBorderRadius;
            var fw = workspaceContainer.frameWidth;
            var adjustedInnerR = Math.max(0, innerR);

            // Draw just the inner border
            var innerBorderPath = "M " + (fw + adjustedInnerR) + "," + fw + (adjustedInnerR > 0 ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 0 " + fw + "," + (fw + adjustedInnerR) : " L " + fw + "," + fw) + " L " + fw + "," + (h - fw - adjustedInnerR) + (adjustedInnerR > 0 ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 0 " + (fw + adjustedInnerR) + "," + (h - fw) : " L " + fw + "," + (h - fw)) + " L " + (w - fw - adjustedInnerR) + "," + (h - fw) + (adjustedInnerR > 0 ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 0 " + (w - fw) + "," + (h - fw - adjustedInnerR) : " L " + (w - fw) + "," + (h - fw)) + " L " + (w - fw) + "," + (fw + adjustedInnerR) + (adjustedInnerR > 0 ? " A " + adjustedInnerR + "," + adjustedInnerR + " 0 0 0 " + (w - fw - adjustedInnerR) + "," + fw : " L " + (w - fw) + "," + fw) + " L " + (fw + adjustedInnerR) + "," + fw + " Z";

            return innerBorderPath;
          }
        }
      }
    }
  }
}
