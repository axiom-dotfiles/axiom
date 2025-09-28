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
  property bool antialiasing: false

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

      // Main frame path with hole
      ShapePath {
        id: outerPath
        fillColor: workspaceContainer.frameColor
        strokeColor: workspaceContainer.outerStrokeColor
        strokeWidth: workspaceContainer.strokeWidth
        fillRule: ShapePath.OddEvenFill  // Changed to OddEvenFill for proper hole rendering
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap

        PathSvg {
          path: {
            var w = frameShape.width;
            var h = frameShape.height;
            var outerR = workspaceContainer.outerBorderRadius;
            var innerR = workspaceContainer.innerBorderRadius;
            var fw = workspaceContainer.frameWidth;

            // --- OUTER PATH (Clockwise) ---
            var outerPath = "";
            
            if (outerR > 0) {
              outerPath = "M " + outerR + ",0";
              outerPath += " L " + (w - outerR) + ",0";
              outerPath += " A " + outerR + "," + outerR + " 0 0 1 " + w + "," + outerR;
              outerPath += " L " + w + "," + (h - outerR);
              outerPath += " A " + outerR + "," + outerR + " 0 0 1 " + (w - outerR) + "," + h;
              outerPath += " L " + outerR + "," + h;
              outerPath += " A " + outerR + "," + outerR + " 0 0 1 0," + (h - outerR);
              outerPath += " L 0," + outerR;
              outerPath += " A " + outerR + "," + outerR + " 0 0 1 " + outerR + ",0";
            } else {
              // Sharp corners
              outerPath = "M 0,0";
              outerPath += " L " + w + ",0";
              outerPath += " L " + w + "," + h;
              outerPath += " L 0," + h;
            }
            outerPath += " Z";

            // --- INNER PATH (Counter-Clockwise for hole) ---
            var innerPath = "";
            
            if (innerR > 0) {
              // Start at top-left of inner rect, moving right
              innerPath = " M " + (fw + innerR) + "," + fw;
              // Top edge
              innerPath += " L " + (w - fw - innerR) + "," + fw;
              // Top-right corner (counter-clockwise)
              innerPath += " A " + innerR + "," + innerR + " 0 0 0 " + (w - fw) + "," + (fw + innerR);
              // Right edge
              innerPath += " L " + (w - fw) + "," + (h - fw - innerR);
              // Bottom-right corner
              innerPath += " A " + innerR + "," + innerR + " 0 0 0 " + (w - fw - innerR) + "," + (h - fw);
              // Bottom edge
              innerPath += " L " + (fw + innerR) + "," + (h - fw);
              // Bottom-left corner
              innerPath += " A " + innerR + "," + innerR + " 0 0 0 " + fw + "," + (h - fw - innerR);
              // Left edge
              innerPath += " L " + fw + "," + (fw + innerR);
              // Top-left corner
              innerPath += " A " + innerR + "," + innerR + " 0 0 0 " + (fw + innerR) + "," + fw;
            } else {
              // Sharp inner corners
              innerPath = " M " + fw + "," + fw;
              innerPath += " L " + (w - fw) + "," + fw;
              innerPath += " L " + (w - fw) + "," + (h - fw);
              innerPath += " L " + fw + "," + (h - fw);
            }
            innerPath += " Z";

            return outerPath + innerPath;
          }
        }
      }

      // Inner border stroke (optional)
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

            var innerBorderPath = "";
            
            if (innerR > 0) {
              innerBorderPath = "M " + (fw + innerR) + "," + fw;
              innerBorderPath += " L " + (w - fw - innerR) + "," + fw;
              innerBorderPath += " A " + innerR + "," + innerR + " 0 0 1 " + (w - fw) + "," + (fw + innerR);
              innerBorderPath += " L " + (w - fw) + "," + (h - fw - innerR);
              innerBorderPath += " A " + innerR + "," + innerR + " 0 0 1 " + (w - fw - innerR) + "," + (h - fw);
              innerBorderPath += " L " + (fw + innerR) + "," + (h - fw);
              innerBorderPath += " A " + innerR + "," + innerR + " 0 0 1 " + fw + "," + (h - fw - innerR);
              innerBorderPath += " L " + fw + "," + (fw + innerR);
              innerBorderPath += " A " + innerR + "," + innerR + " 0 0 1 " + (fw + innerR) + "," + fw;
            } else {
              innerBorderPath = "M " + fw + "," + fw;
              innerBorderPath += " L " + (w - fw) + "," + fw;
              innerBorderPath += " L " + (w - fw) + "," + (h - fw);
              innerBorderPath += " L " + fw + "," + (h - fw);
            }
            innerBorderPath += " Z";

            return innerBorderPath;
          }
        }
      }
    }
  }
}
