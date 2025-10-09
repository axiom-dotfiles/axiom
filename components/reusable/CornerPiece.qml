import QtQuick
import QtQuick.Shapes

import qs.config

// TODO: Completely fix
Item {
  id: root
  property int borderRadius: Appearance.borderRadius
  property color fillColor: Theme.background
  property color strokeColor: Theme.foreground
  property int strokeWidth: Appearance.borderWidth
  
  property bool isLeft: parent.anchors.left !== undefined
  property bool isTop: parent.anchors.top !== undefined
  
  anchors.fill: parent
  
  Shape {
    anchors.fill: parent
    
    ShapePath {
      fillColor: root.fillColor
      strokeColor: "transparent"
      
      // Start at outer corner
      startX: root.isLeft ? 0 : parent.width
      startY: root.isTop ? 0 : parent.height
      
      // Go to edge before arc
      PathLine {
        x: root.isLeft ? 0 : parent.width
        y: root.isTop ? root.borderRadius : (parent.height - root.borderRadius)
      }
      
      // Arc along inner curve
      PathArc {
        x: root.isLeft ? root.borderRadius : (parent.width - root.borderRadius)
        y: root.isTop ? 0 : parent.height
        radiusX: root.borderRadius
        radiusY: root.borderRadius
        direction: root.isTop === root.isLeft ? PathArc.Clockwise : PathArc.Counterclockwise
      }
      
      // Back to start along edge
      PathLine {
        x: root.isLeft ? 0 : parent.width
        y: root.isTop ? 0 : parent.height
      }
    }
  }
  
  // Draw just the arc stroke
  Shape {
    anchors.fill: parent
    
    ShapePath {
      strokeColor: root.strokeColor
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      
      startX: root.isLeft ? 0 : parent.width
      startY: root.isTop ? root.borderRadius : (parent.height - root.borderRadius)
      
      PathArc {
        x: root.isLeft ? root.borderRadius : (parent.width - root.borderRadius)
        y: root.isTop ? 0 : parent.height
        radiusX: root.borderRadius
        radiusY: root.borderRadius
        direction: root.isTop === root.isLeft ? PathArc.Clockwise : PathArc.Counterclockwise
      }
    }
  }
}
