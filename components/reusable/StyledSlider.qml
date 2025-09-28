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
    width: parent.width * root.value
    height: root.grooveHeight
    radius: height / 2
    color: root.fillColor
  }

  Rectangle {
    id: handleRect
    x: fillRect.width - (width / 2)
    anchors.verticalCenter: parent.verticalCenter
    width: root.handleWidth
    height: root.handleHeight
    radius: root.handleRadius
    color: root.handleColor
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
      let ratio = Math.max(0, Math.min(1, x / root.width));
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
        root.released(ratio);
      }
    }
  }
}
