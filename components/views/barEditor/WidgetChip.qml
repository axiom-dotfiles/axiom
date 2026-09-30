pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// One bar widget in the editor: its type's icon and name, as a pill. With
// a `payload`, pressing and moving it starts a drag on `dragLayer`; a
// click without moving is `clicked`.
Rectangle {
  id: root

  // The DragLayer that carries it and names the types
  required property var dragLayer
  property string type: ""
  // The widget's own `visible: false` (kept in config, not shown on the bar)
  property bool hiddenWidget: false
  property bool selected: false
  // The short type name, for narrow places
  property bool compact: false
  // Left in place, faded, while it's being carried
  property bool faded: false
  // What dragging it carries ({ kind, zone, index, type }); null: it can't be dragged
  property var payload: null

  signal clicked

  implicitWidth: row.implicitWidth + Widget.padding * 2
  implicitHeight: Widget.height + Widget.padding / 2
  radius: Widget.radius
  color: root.selected ? Theme.accent : (area.containsMouse ? Theme.backgroundHighlight : Theme.background)
  border.color: root.selected ? Theme.accent : Theme.border
  border.width: 1
  opacity: root.faded ? 0.3 : (root.hiddenWidget ? 0.6 : 1)

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.leftMargin: root.compact ? Widget.padding / 2 : Widget.padding
    anchors.rightMargin: root.compact ? Widget.padding / 2 : Widget.padding
    spacing: root.compact ? Widget.spacing / 2 : Widget.spacing

    StyledIcon {
      text: root.dragLayer.icon(root.type)
      textColor: root.selected ? Theme.background : Theme.accent
      Layout.preferredWidth: Appearance.fontSize * 1.3
    }

    StyledText {
      text: root.compact ? root.dragLayer.shortLabel(root.type) : root.dragLayer.label(root.type)
      textColor: root.selected ? Theme.background : Theme.foreground
      font.bold: root.selected
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    // Hidden on the bar
    StyledIcon {
      visible: root.hiddenWidget
      text: "visibility_off"
      textColor: root.selected ? Theme.background : Theme.foreground
      opacity: 0.7
    }
  }

  DragArea {
    id: area
    anchors.fill: parent
    dragEnabled: root.payload !== null
    dragLayer: root.dragLayer
    payload: root.payload
    onTapped: root.clicked()
  }
}
