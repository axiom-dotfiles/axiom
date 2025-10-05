// CornerPiece.qml
// This component draws the curved stroke in a corner, connecting the straight border panels.
import QtQuick
import QtQuick.Shapes

import qs.config

Item {
    id: root

    // --- INPUT PROPERTIES ---
    // Type of corner to draw
    required property string corner // "top-left", "top-right", "bottom-left", "bottom-right"
    
    // The inner radius of the border curve
    required property real radius
    
    // The thickness of the border stroke
    required property real strokeWidth
    
    // The color of the corner piece
    required property color fillColor
    property color strokeColor: Theme.foreground

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 8

        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            // We use PathSvg because it gives us precise control to draw the shape.
            // The shape is defined by four points and two quadratic curves (Q).
            // It starts from one inner edge, curves to the other inner edge,
            // goes straight to the outer edge, curves along the outer edge,
            // and then closes the path.
            PathSvg {
                path: {
                    var w = root.width;   // Width of the container (frameWidth)
                    var h = root.height;  // Height of the container (frameWidth)
                    var r = root.radius;
                    var s = root.strokeWidth;
                    var path = "";

                    // Calculate path based on which corner we are drawing
                    switch (root.corner) {
                        case "top-left":
                            // The visual corner is at the bottom-right of this item (w, h)
                            // Move to the start of the inner curve (on the vertical line)
                            path = "M " + (w - s) + "," + (h - r);
                            // Inner curve to the horizontal line
                            path += " Q " + (w - s) + "," + (h - s) + " " + (w - r) + "," + (h - s);
                            // Line to the outer edge
                            path += " L " + (w - r) + "," + h;
                            // Outer curve back to the vertical line
                            path += " Q " + w + "," + h + " " + w + "," + (h - r);
                            // Close the shape
                            path += " Z";
                            break;

                        case "top-right":
                            // The visual corner is at the bottom-left of this item (0, h)
                            path = "M " + s + "," + (h - r);
                            path += " Q " + s + "," + (h - s) + " " + r + "," + (h - s);
                            path += " L " + r + "," + h;
                            path += " Q " + 0 + "," + h + " " + 0 + "," + (h - r);
                            path += " Z";
                            break;

                        case "bottom-left":
                            // The visual corner is at the top-right of this item (w, 0)
                            path = "M " + (w - s) + "," + r;
                            path += " Q " + (w - s) + "," + s + " " + (w - r) + "," + s;
                            path += " L " + (w - r) + "," + 0;
                            path += " Q " + w + "," + 0 + " " + w + "," + r;
                            path += " Z";
                            break;

                        case "bottom-right":
                            // The visual corner is at the top-left of this item (0, 0)
                            path = "M " + s + "," + r;
                            path += " Q " + s + "," + s + " " + r + "," + s;
                            path += " L " + r + "," + 0;
                            path += " Q " + 0 + "," + 0 + " " + 0 + "," + r;
                            path += " Z";
                            break;
                    }
                    return path;
                }
            }
        }
    }
}
