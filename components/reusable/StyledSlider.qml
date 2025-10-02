import QtQuick
import qs.config

Item {
  id: root
  
  property real value: 0.0
  signal moved(real value)
  signal released(real value)
  property color grooveColor: Theme.backgroundHighlight
  property color fillColor: Theme.foreground
  property color handleColor: Theme.foreground
  property int handleRadius: Appearance.borderRadius
  property int handleWidth: 24
  property int handleHeight: 14
  property int grooveHeight: 4
  
  property bool pressed: mouseArea.isDragging
  property real targetValue: value
  property bool smoothUpdate: true
  
  property real _internalValue: value
  
  Binding {
    target: root
    property: "_internalValue"
    value: root.targetValue
    when: !mouseArea.isDragging && root.smoothUpdate
  }
  
  onValueChanged: {
    if (!mouseArea.isDragging && !root.smoothUpdate) {
      _internalValue = value
    }
  }
  
  Behavior on _internalValue {
    enabled: !mouseArea.isDragging && root.smoothUpdate
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutQuad
    }
  }
  
  Rectangle {
    id: grooveRect
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.grooveHeight
    radius: height / 2
    color: root.grooveColor
  }
  
  Rectangle {
    id: fillRect
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * (mouseArea.isDragging ? root.value : root._internalValue)
    height: root.grooveHeight
    radius: height / 2
    color: root.fillColor
    
    Behavior on width {
      enabled: !mouseArea.isDragging
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutQuad
      }
    }
  }
  
  Rectangle {
    id: handleRect
    x: fillRect.width - (width / 2)
    anchors.verticalCenter: parent.verticalCenter
    width: root.handleWidth
    height: root.handleHeight
    radius: root.handleRadius
    color: root.handleColor
    
    // Enhanced visual feedback
    scale: mouseArea.isDragging ? 1.2 : (mouseArea.containsMouse ? 1.1 : 1.0)
    
    Behavior on scale {
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutQuad
      }
    }
    
    Behavior on opacity {
      NumberAnimation {
        duration: 150
      }
    }
  }
  
  // TODO: not here
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    
    property bool isDragging: false
    
    function updatePosition(x) {
      let ratio = Math.max(0, Math.min(1, x / root.width));
      root.value = ratio;  // Update value directly
      root.moved(ratio);
    }
    
    onPressed: {
      isDragging = true;
      updatePosition(mouseX);
    }
    
    onPositionChanged: {
      if (isDragging) {
        updatePosition(mouseX);
      }
    }
    
    onReleased: {
      if (isDragging) {
        isDragging = false;
        let ratio = Math.max(0, Math.min(1, mouseX / root.width));
        root.value = ratio;  // Ensure final value is set
        root.released(ratio);
      }
    }
    
    onCanceled: {
      isDragging = false;
    }
  }
}
