import QtQuick
import QtQuick.Shapes
import Quickshell

// Main popout component that handles positioning and reverse corners
PopupWindow {
    id: root
    
    // --- Public API ---
    property Item anchor: null  // The bar item to anchor to
    property int edge: SeamlessPopout.Edge.Right  // Which edge of the bar we're attached to
    property real gap: 0  // Gap between bar and popout (usually 0 for seamless)
    property real cornerRadius: 12  // Radius for the rounded corners
    property bool showCorners: true  // Whether to show the reverse corners
    
    // Colors
    property color backgroundColor: "#2a2a2a"
    property color cornerFillColor: "#1a1a1a"  // Should match bar color
    property color borderColor: "transparent"
    property real borderWidth: 0
    
    // Content
    default property alias content: contentContainer.children
    
    // Animation
    property int animationDuration: 200
    property var easingCurve: Easing.OutCubic
    
    // Edge enumeration
    enum Edge {
        Top,
        Right,
        Bottom,
        Left
    }
    
    // --- Internal Properties ---
    readonly property bool isHorizontal: edge === SeamlessPopout.Edge.Top || edge === SeamlessPopout.Edge.Bottom
    readonly property bool isVertical: edge === SeamlessPopout.Edge.Left || edge === SeamlessPopout.Edge.Right
    
    // --- Window Configuration ---
    color: "transparent"
    visible: opacity > 0
    
    // Position relative to anchor
    anchor {
        window: root.anchor
        rect {
            x: {
                switch(root.edge) {
                    case SeamlessPopout.Edge.Left:
                        return -(width + gap);
                    case SeamlessPopout.Edge.Right:
                        return anchor ? anchor.width + gap : 0;
                    default:
                        return 0;
                }
            }
            y: {
                switch(root.edge) {
                    case SeamlessPopout.Edge.Top:
                        return -(height + gap);
                    case SeamlessPopout.Edge.Bottom:
                        return anchor ? anchor.height + gap : 0;
                    default:
                        return 0;
                }
            }
            width: 1
            height: 1
        }
    }
    
    // --- Main Content ---
    Item {
        id: container
        anchors.fill: parent
        
        // Background with rounded corners
        Rectangle {
            id: background
            anchors.fill: parent
            color: root.backgroundColor
            radius: root.cornerRadius
            border.color: root.borderColor
            border.width: root.borderWidth
        }
        
        // Content container
        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.margins: root.borderWidth
        }
        
        // Reverse corner overlays
        Item {
            id: cornerOverlay
            anchors.fill: parent
            visible: root.showCorners
            
            // Top-left corner
            ReverseCorner {
                visible: (root.edge === SeamlessPopout.Edge.Right && root.anchor.y < root.y) ||
                        (root.edge === SeamlessPopout.Edge.Bottom && root.anchor.x < root.x)
                x: 0
                y: 0
                radius: root.cornerRadius
                fillColor: root.cornerFillColor
                rotation: 0
            }
            
            // Top-right corner
            ReverseCorner {
                visible: (root.edge === SeamlessPopout.Edge.Left && root.anchor.y < root.y) ||
                        (root.edge === SeamlessPopout.Edge.Bottom && root.anchor.x > root.x)
                x: parent.width - root.cornerRadius
                y: 0
                radius: root.cornerRadius
                fillColor: root.cornerFillColor
                rotation: 90
            }
            
            // Bottom-right corner
            ReverseCorner {
                visible: (root.edge === SeamlessPopout.Edge.Left && root.anchor.y > root.y) ||
                        (root.edge === SeamlessPopout.Edge.Top && root.anchor.x > root.x)
                x: parent.width - root.cornerRadius
                y: parent.height - root.cornerRadius
                radius: root.cornerRadius
                fillColor: root.cornerFillColor
                rotation: 180
            }
            
            // Bottom-left corner
            ReverseCorner {
                visible: (root.edge === SeamlessPopout.Edge.Right && root.anchor.y > root.y) ||
                        (root.edge === SeamlessPopout.Edge.Top && root.anchor.x < root.x)
                x: 0
                y: parent.height - root.cornerRadius
                radius: root.cornerRadius
                fillColor: root.cornerFillColor
                rotation: 270
            }
        }
    }
    
    // --- Animations ---
    property bool showing: false
    
    opacity: showing ? 1 : 0
    scale: showing ? 1 : 0.95
    
    Behavior on opacity {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingCurve
        }
    }
    
    Behavior on scale {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingCurve
        }
    }
    
    // --- Public Methods ---
    function show() {
        showing = true;
    }
    
    function hide() {
        showing = false;
    }
    
    function toggle() {
        showing = !showing;
    }
}

// Separate component for the reverse corner shape
// This is cleaner as a separate component for reusability
component ReverseCorner: Shape {
    property real radius: 12
    property color fillColor: "#1a1a1a"
    
    width: radius
    height: radius
    antialiasing: true
    
    ShapePath {
        fillColor: parent.fillColor
        strokeWidth: 0
        
        PathSvg {
            path: {
                var r = radius;
                // Create a quarter circle cutout
                var path = "M 0,0";
                path += " L 0," + r;
                path += " Q 0,0 " + r + ",0";
                path += " Z";
                return path;
            }
        }
    }
}
