import QtQuick
import QtQuick.Layouts
import qs.config

Item {
  id: root
  
  property real percentage: 0
  property string iconText: "●"
  property color iconColor: Theme.background
  property color fillColor: Theme.accentAlt
  property color backgroundColor: "#ffffff"
  property real backgroundOpacity: 0.1
  property real strokeInset: 0.85
  
  implicitWidth: 120
  implicitHeight: 120
  
  // Background circle
  Rectangle {
    id: bgCircle
    anchors.centerIn: parent
    width: Math.min(root.width, root.height)
    height: width
    radius: width / 2
    color: root.backgroundColor
    opacity: root.backgroundOpacity
  }
  
  // Progress circle using Canvas
  Canvas {
    id: progressCanvas
    anchors.centerIn: parent
    width: bgCircle.width
    height: bgCircle.height
    
    onPaint: {
      var ctx = getContext("2d");
      var centerX = width / 2;
      var centerY = height / 2;
      var radius = (width / 2) * root.strokeInset;
      var lineWidth = width * 0.15;
      
      ctx.clearRect(0, 0, width, height);
      
      // Draw the arc
      ctx.beginPath();
      ctx.arc(
        centerX, 
        centerY, 
        radius, 
        -Math.PI / 2, 
        -Math.PI / 2 + (root.percentage / 100) * 2 * Math.PI, 
        false
      );
      ctx.lineWidth = lineWidth;
      ctx.strokeStyle = root.fillColor;
      ctx.lineCap = "butt";
      ctx.stroke();
    }
    
    Connections {
      target: root
      function onPercentageChanged() {
        progressCanvas.requestPaint();
      }
      function onFillColorChanged() {
        progressCanvas.requestPaint();
      }
      function onStrokeInsetChanged() {
        progressCanvas.requestPaint();
      }
    }
  }
  
  // Center icon
  Text {
    anchors.centerIn: parent
    text: root.iconText
    color: root.iconColor
    font.pixelSize: bgCircle.width * 0.35
  }
  
  Behavior on percentage {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }
}
