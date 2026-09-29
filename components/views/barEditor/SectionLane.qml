pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// One bar section in the bar editor: its widgets top to bottom, in bar
// order. Chips can be dragged within it, to another lane, or dropped on
// it from the library; the chips past the drop point slide aside to show
// where it would land.
Rectangle {
  id: root

  required property var dragLayer
  // The section's key in the bar's `widgets`
  required property string zone
  required property string title

  readonly property var widgets: BarManager.selectedBar()?.widgets?.[root.zone] ?? []
  readonly property bool hovering: root.dragLayer.hoverZone === root.zone
  readonly property real chipHeight: Widget.height + Widget.padding / 2
  readonly property real rowStep: root.chipHeight + Widget.spacing

  // `anchor`: the + button, so the picker opens beside it
  signal addRequested(Item anchor)

  radius: Widget.radius
  color: root.hovering ? Qt.alpha(Theme.accent, 0.1) : Theme.backgroundAlt
  border.color: root.hovering ? Theme.accent : "transparent"
  border.width: 1

  Behavior on color {
    ColorAnimation {
      duration: Appearance.animFast
    }
  }

  Component.onCompleted: root.dragLayer.registerLane(root)
  Component.onDestruction: root.dragLayer.unregisterLane(root)

  // Where a drop at `point` (in the drag layer) would insert: before the
  // first chip whose middle is below it
  function indexAt(point) {
    const p = root.dragLayer.mapToItem(list, point.x, point.y);
    for (let i = 0; i < repeater.count; i++) {
      const chip = repeater.itemAt(i);
      if (chip && p.y < chip.y + chip.height / 2)
        return i;
    }
    return repeater.count;
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: Widget.spacing

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      StyledText {
        text: root.title
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      // Center only: pin it dead center so the other sections can't push it
      SquareIconButton {
        readonly property bool locked: BarManager.selectedBar()?.lockCenter ?? false

        visible: root.zone === "center"
        size: Widget.height - 6
        iconText: locked ? "lock" : "lock_open"
        iconSize: Appearance.fontSize - 1
        iconColor: locked ? Theme.background : Theme.foreground
        backgroundColor: locked ? Theme.accent : "transparent"
        tooltipText: I18n.tr(locked ? "Center locked: it stays dead center, other sections make room" : "Lock the center section in place")
        onClicked: BarManager.updateBarField("lockCenter", !locked)
      }

      SquareIconButton {
        id: addButton
        size: Widget.height - 6
        iconText: "+"
        iconSize: Appearance.fontSize + 2
        backgroundColor: "transparent"
        tooltipText: I18n.tr("Add a widget")
        onClicked: root.addRequested(addButton)
      }
    }

    Flickable {
      id: flick
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      contentWidth: width
      // Room below the last chip for the gap a drop opens
      contentHeight: list.height + root.rowStep
      boundsBehavior: Flickable.StopAtBounds
      interactive: root.dragLayer.dragging === null

      Item {
        id: list
        width: flick.width
        height: Math.max(0, repeater.count * root.rowStep - Widget.spacing)

        // Where the dragged widget would land
        Rectangle {
          visible: root.hovering
          width: list.width
          height: root.chipHeight
          y: Math.max(0, root.dragLayer.hoverIndex) * root.rowStep
          radius: Widget.radius
          color: Qt.alpha(Theme.accent, 0.12)
          border.color: Theme.accent
          border.width: 1
        }

        // Keyed by count: edits to a widget update its chip in place
        Repeater {
          id: repeater
          model: root.widgets.length

          delegate: WidgetChip {
            id: chip
            required property int index
            readonly property var widget: root.widgets[index] ?? ({})

            dragLayer: root.dragLayer
            compact: true
            width: list.width
            height: root.chipHeight
            y: chip.index * root.rowStep
            type: chip.widget.type ?? ""
            hiddenWidget: chip.widget.visible === false
            selected: BarManager.selectedWidget.zone === root.zone && BarManager.selectedWidget.index === chip.index
            faded: root.dragLayer.dragging?.kind === "move" && root.dragLayer.dragging.zone === root.zone && root.dragLayer.dragging.index === chip.index
            payload: ({
                "kind": "move",
                "zone": root.zone,
                "index": chip.index,
                "type": chip.type
              })
            onClicked: BarManager.selectWidget(root.zone, chip.index)

            // Chips at and past the drop point make room for it
            transform: Translate {
              y: root.hovering && chip.index >= root.dragLayer.hoverIndex ? root.rowStep : 0

              Behavior on y {
                NumberAnimation {
                  duration: Appearance.animFast
                  easing.type: Easing.OutCubic
                }
              }
            }
          }
        }
      }

      StyledText {
        visible: repeater.count === 0 && !root.hovering
        width: flick.width
        y: root.rowStep / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.tr("Drop widgets here")
        opacity: 0.45
        textSize: Appearance.fontSize - 1
      }
    }
  }
}
