// /components/reusable/StyledSlider.qml
pragma ComponentBehavior: Bound
import QtQuick

import qs.config

Item {
  id: component
  
  // -- Signals --
  signal moved(real value)
  signal released(real value)

  // -- Public API --
  property real value: 0.0
  property real targetValue: value
  property real _internalValue: value
  property bool pressed: mouseArea.isDragging
  property bool smoothUpdate: true

  // -- Configurable Appearance --
  property alias troughColor: troughRect.color
  property alias fillColor: fillRect.color
  property alias handleColor: handleRect.color
  property alias handleRadius: handleRect.radius

  property alias handleWidth: handleRect.width
  property alias handleHeight: handleRect.height
  property alias troughHeight: troughRect.height
  
  // -- Implementation --
  Binding {
    target: component
    property: "_internalValue"
    value: component.targetValue
    when: !mouseArea.isDragging && component.smoothUpdate
  }
  
  onValueChanged: {
    if (!mouseArea.isDragging && !component.smoothUpdate) {
      _internalValue = value
    }
  }
  
  Behavior on _internalValue {
    enabled: !mouseArea.isDragging && component.smoothUpdate
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutQuad
    }
  }
  
  Rectangle {
    id: troughRect
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 4
    radius: Appearance.borderRadius
    color: Theme.backgroundHighlight
  }
  
  Rectangle {
    id: fillRect
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width * (mouseArea.isDragging ? component.value : component._internalValue)
    height: troughRect.height
    radius: height / 2
    color: Theme.foreground
    
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
    width: 24
    height: 14
    radius: Appearance.borderRadius
    color: Theme.backgroundAlt
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
  
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    
    property bool isDragging: false
    
    function updatePosition(x) {
      let ratio = Math.max(0, Math.min(1, x / component.width));
      component.value = ratio;
      component.moved(ratio);
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
        let ratio = Math.max(0, Math.min(1, mouseX / component.width));
        component.value = ratio;
        component.released(ratio);
      }
    }
    
    onCanceled: {
      isDragging = false;
    }
  }
}
