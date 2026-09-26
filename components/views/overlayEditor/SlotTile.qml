pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// One slot of a cell on the canvas: its module's icon and name (plus a
// hint for modules whose look depends on their properties), or a plus when
// empty. Click to edit it, drag the module to another slot (swapping) or
// out into a cell of its own, drop a module from the library on it.
// Positioned and sized by CanvasCell.
Rectangle {
  id: root

  required property var dragLayer
  required property int column
  required property int cell
  required property string slot
  // [col, row, colSpan, rowSpan] in the cell's layout
  required property var rect
  // { type, properties } or null
  property var module: null

  readonly property string targetKind: "slot"
  readonly property string type: root.module?.type ?? ""
  readonly property bool selected: root.dragLayer.editor.isSelected(root.column, root.cell, root.slot)
  // The configured module doesn't fit this slot's shape (blocks Save)
  readonly property bool misfit: root.type !== "" && !OverlayConfig.fits(root.type, root.rect)
  readonly property bool carried: root.dragLayer.draggingKind === "module-move" && root.dragLayer.dragging.column === root.column && root.dragLayer.dragging.cell === root.cell && root.dragLayer.dragging.slot === root.slot
  readonly property bool hovered: root.dragLayer.hoverTarget === root
  // While a module is carried: whether it could land here
  readonly property bool takesCarried: root.dragLayer.carryingModule && (root.dragLayer.draggingKind === "module-add" ? OverlayConfig.fits(root.dragLayer.dragging.type, root.rect) : root.dragLayer.editor.canMoveModule(root.dragLayer.dragging, {
      "column": root.column,
      "cell": root.cell,
      "slot": root.slot
    }))
  readonly property bool small: root.width < Appearance.fontSize * 7 || root.height < Appearance.fontSize * 4

  readonly property bool isSwatch: root.type === "ColorSwatch"
  readonly property color fill: root.isSwatch ? Theme.resolveColor(root.module.properties?.color) : Theme.background
  readonly property color ink: root.isSwatch ? Utils.getContrastColor(root.fill) : Theme.foreground
  readonly property string detail: {
    const props = root.module?.properties ?? {};
    switch (root.type) {
    case "ColorSwatch":
      return props.color ?? "";
    case "SystemGraphs":
      return (props.metrics ?? []).join(", ");
    case "Disks":
      return (props.paths ?? []).join(", ");
    }
    return "";
  }

  function indexAt(point) {
    return -1;
  }

  Component.onCompleted: root.dragLayer.registerTarget(root)
  Component.onDestruction: root.dragLayer.unregisterTarget(root)

  radius: Appearance.borderRadius
  color: root.module ? root.fill : (area.containsMouse ? Qt.alpha(Theme.accent, 0.08) : "transparent")
  border.color: root.hovered ? (root.dragLayer.hoverValid ? Theme.accent : Theme.error) : root.misfit ? Theme.error : root.selected ? Theme.accent : Theme.border
  border.width: root.hovered || root.selected || root.misfit ? Math.max(Appearance.borderWidth, 2) : Appearance.borderWidth
  opacity: root.carried ? 0.3 : (root.dragLayer.carryingModule && !root.takesCarried && !root.hovered ? 0.35 : (root.module || root.selected || area.containsMouse || root.dragLayer.carryingModule ? 1 : 0.55))

  Behavior on opacity {
    NumberAnimation {
      duration: Appearance.animFast
    }
  }

  // Where the carried module would land
  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    visible: root.hovered && root.dragLayer.hoverValid
    color: Qt.alpha(Theme.accent, 0.22)
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - 8
    spacing: 2

    StyledIcon {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.module ? root.dragLayer.moduleIcon(root.type) : "add"
      textColor: root.isSwatch ? root.ink : (root.module ? Theme.accent : Theme.foreground)
      textSize: root.small ? Appearance.fontSize + 2 : Appearance.fontSize + 8
      opacity: root.module ? 1 : 0.6
    }

    StyledText {
      width: parent.width
      visible: root.module !== null && !root.small
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.dragLayer.moduleLabel(root.type)
      textColor: root.ink
      textSize: Appearance.fontSize - 1
      font.bold: true
    }

    StyledText {
      width: parent.width
      visible: text !== "" && !root.small
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.hovered && !root.dragLayer.hoverValid || root.misfit ? I18n.tr("doesn't fit") : root.detail
      textColor: root.hovered && !root.dragLayer.hoverValid || root.misfit ? Theme.error : root.ink
      textSize: Appearance.fontSize - 3
      opacity: 0.75
    }
  }

  DragArea {
    id: area
    anchors.fill: parent
    dragEnabled: root.module !== null
    cursorShape: root.dragLayer.dragging !== null ? Qt.ClosedHandCursor : (root.module ? Qt.OpenHandCursor : Qt.PointingHandCursor)
    onDragStarted: (x, y) => root.dragLayer.begin({
        "kind": "module-move",
        "type": root.type,
        "column": root.column,
        "cell": root.cell,
        "slot": root.slot,
        "icon": root.dragLayer.moduleIcon(root.type),
        "label": root.dragLayer.moduleLabel(root.type)
      }, area, x, y)
    onDragMoved: (x, y) => root.dragLayer.move(area, x, y)
    onDropped: root.dragLayer.end()
    onDragCanceled: root.dragLayer.cancel()
    onTapped: root.dragLayer.editor.select(root.column, root.cell, root.slot)
  }
}
