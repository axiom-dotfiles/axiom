pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// One page of the overlay: shown when it's the current page, sliding in
// from the side the navigation came from (`direction`). The content is
// only instantiated while `loaded`.
Item {
  id: root

  required property int pageIndex
  required property int currentIndex
  required property int direction
  required property bool loaded
  default property Component content

  readonly property bool current: root.currentIndex === root.pageIndex

  anchors.centerIn: parent
  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
  implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
  visible: root.current
  opacity: root.current ? 1 : 0

  onCurrentChanged: {
    if (root.current)
      slideIn.restart();
  }

  Loader {
    id: contentLoader
    anchors.centerIn: parent
    active: root.loaded
    sourceComponent: root.content
  }

  transform: Translate {
    id: slideTransform
  }

  Behavior on opacity {
    NumberAnimation {
      duration: Appearance.animFast
      easing.type: Easing.InOutQuad
    }
  }

  NumberAnimation {
    id: slideIn
    target: slideTransform
    property: "x"
    from: 100 * root.direction
    to: 0
    duration: Appearance.animFast
    easing.type: Easing.InOutQuad
  }
}
