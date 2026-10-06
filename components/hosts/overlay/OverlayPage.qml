pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.reusable

// One page of the overlay: shown when it's the current page, sliding in
// from the side the navigation came from (`direction`), while the page it
// replaces slides out the other way and fades. The content is only
// instantiated while `loaded` (or still leaving).
Item {
  id: root

  required property int pageIndex
  required property int currentIndex
  required property int direction
  required property bool loaded
  default property Component content

  readonly property bool current: root.currentIndex === root.pageIndex
  // Still on screen, sliding out after another page took its place
  property bool _leaving: false
  readonly property real _shift: Math.max(Widget.spacing * 3, Math.round(root.width * 0.06))

  anchors.centerIn: parent
  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
  implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
  visible: root.current || root._leaving
  opacity: root.current ? 1 : 0

  onCurrentChanged: {
    if (root.current) {
      slideOut.stop();
      root._leaving = false;
      slideIn.from = root._shift * root.direction;
      slideIn.restart();
    } else if (root.visible) {
      slideIn.stop();
      root._leaving = true;
      slideAway.to = -root._shift * root.direction;
      slideOut.restart();
    }
  }

  Loader {
    id: contentLoader
    anchors.centerIn: parent
    active: root.loaded || root._leaving
    sourceComponent: root.content
  }

  transform: Translate {
    id: slideTransform
  }

  Glide on opacity {
    duration: Appearance.animNormal
  }

  NumberAnimation {
    id: slideIn
    target: slideTransform
    property: "x"
    to: 0
    duration: Appearance.animNormal
    easing.type: Appearance.easing
  }

  SequentialAnimation {
    id: slideOut
    NumberAnimation {
      id: slideAway
      target: slideTransform
      property: "x"
      duration: Appearance.animNormal
      easing.type: Appearance.easing
    }
    ScriptAction {
      script: {
        root._leaving = false;
        slideTransform.x = 0;
      }
    }
  }
}
