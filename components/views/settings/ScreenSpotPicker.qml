pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.components.reusable

// A small screen showing where something sits (`spot`, 0-1 from the top
// left), with `presets` to click: dots that each apply their values. Used
// for docks and OSDs (EntryListCard) and the launcher (LauncherPlace).
Rectangle {
  id: root

  // [{ label, values, x, y }]: a dot at (x, y) (0-1 from the top left) that
  // applies `values`; the label is its tooltip, an I18n key the caller
  // declares
  property var presets: []
  property point spot: Qt.point(0.5, 0.5)
  readonly property real dot: 14

  // A preset was clicked
  signal picked(var values)

  // The spot of something on a screen edge (its name: "Top", …), `along`
  // it from its start (left/top) and `across` the screen from it (0-1)
  function edgeSpot(edge, along, across) {
    switch (edge) {
    case "Top":
      return Qt.point(along, across);
    case "Left":
      return Qt.point(across, along);
    case "Right":
      return Qt.point(1 - across, along);
    }
    return Qt.point(along, 1 - across);
  }

  implicitWidth: 192
  implicitHeight: 108
  color: Theme.background
  border.color: Theme.border
  border.width: Appearance.borderWidth
  radius: Widget.radius / 2

  Repeater {
    model: root.presets

    delegate: Rectangle {
      id: preset
      required property var modelData
      readonly property bool hovered: presetArea.containsMouse

      width: root.dot
      height: root.dot
      radius: width / 2
      x: modelData.x * (root.width - width)
      y: modelData.y * (root.height - height)
      color: hovered ? Theme.accentAlt : Theme.backgroundHighlight
      border.color: Theme.border
      border.width: 1

      MouseArea {
        id: presetArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(preset.modelData.values)
      }

      LazyLoader {
        active: preset.hovered
        StyledToolTip {
          target: preset
          // i18n: keys from the presets (the callers')
          text: I18n.tr(preset.modelData.label)
        }
      }
    }
  }

  // Where it is now
  Rectangle {
    width: root.dot - 4
    height: root.dot - 4
    radius: width / 2
    x: root.spot.x * (root.width - root.dot) + 2
    y: root.spot.y * (root.height - root.dot) + 2
    color: Theme.accent
  }
}
