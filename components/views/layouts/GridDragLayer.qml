pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// i18n: keys from the schema (module and view labels)
// The layouts editor's whole area: a DragLayer whose ghost is drawn above
// every panel, so a module can be carried from the library onto the
// canvas, a page or menu up or down its list.
//
// Payloads: { kind, icon, label, ... }, kind one of
//   "module-add" { type, w, h }   from the library
//   "module-move" { index }       a module on the canvas
//   "page-move" { index }         a page row
//   "tool-move" { index }         a tool page row
//   "menu-move" { index }         an edge menu row
// Targets: items with `targetKind` "grid" (placeAt(point, drag, grab)
// → { x, y, w, h }) or "list" (EntryListTarget: takes(drag), indexAt,
// dropRequested(drag, index)). Module edits go to `editor` (a GridEditor); a
// list handles its own drops.
DragLayer {
  id: root

  required property GridEditor editor

  readonly property string draggingKind: root.dragging?.kind ?? ""
  readonly property bool carryingModule: root.draggingKind === "module-add" || root.draggingKind === "module-move"

  // Where in the carried item it was picked up (in its own pixels), so a
  // moved module keeps its place under the pointer
  property point grab: Qt.point(0, 0)
  // The pointer, in this item
  property point pointer: Qt.point(0, 0)
  // Where a module dropped now would go ({ x, y, w, h }), else null
  readonly property var hoverPlace: root.carryingModule && root.hoverTarget?.targetKind === "grid" ? root.hoverTarget.placeAt(root.pointer, root.dragging, root.grab) : null
  // Whether dropping on the target under the pointer would do anything
  readonly property bool hoverValid: root.hoverTarget !== null && root.dragging !== null && root.canDrop(root.dragging, root.hoverPlace)

  function moduleIcon(type) {
    return OverlayConfig.moduleInfo(type)?.icon ?? "extension";
  }

  function moduleLabel(type) {
    const info = OverlayConfig.moduleInfo(type);
    return info ? I18n.tr(info.label) : (type || I18n.tr("Unknown"));
  }

  accepts: (target, drag) => {
    switch (target.targetKind) {
    case "grid":
      return drag.kind === "module-add" || drag.kind === "module-move";
    case "list":
      return target.takes(drag);
    }
    return false;
  }

  // Whether `drag` would land at `place` (a module where it fits)
  function canDrop(drag, place) {
    if (drag.kind === "module-add")
      return place !== null && root.editor.canAdd(drag.type, place);
    if (drag.kind === "module-move")
      return place !== null && root.editor.canMove(drag.index, place.x, place.y);
    return true;
  }

  onStarted: (payload, item, x, y) => root.grab = Qt.point(x, y)

  onMoved: point => {
    root.pointer = point;
    ghost.x = point.x - ghost.height / 2;
    ghost.y = point.y - ghost.height / 2;
  }

  // Does whatever the target takes
  onDropped: (drag, target, index) => {
    if (target.targetKind === "list") {
      target.dropRequested(drag, index);
      return;
    }
    const place = target.placeAt(root.pointer, drag, root.grab);
    if (!root.canDrop(drag, place))
      return;
    if (drag.kind === "module-add")
      root.editor.addModule(drag.type, place);
    else
      root.editor.moveModule(drag.index, place.x, place.y);
  }

  // What's being carried, as a pill under the pointer (the canvas draws
  // where it would land)
  Rectangle {
    id: ghost
    visible: root.dragging !== null
    z: 10
    width: ghostRow.implicitWidth + Widget.padding * 2
    height: Widget.height + Widget.padding / 2
    radius: Widget.radius
    color: root.hoverTarget && !root.hoverValid ? Theme.error : Theme.accent
    opacity: 0.92

    RowLayout {
      id: ghostRow
      anchors.centerIn: parent
      spacing: Widget.spacing

      StyledIcon {
        text: root.dragging?.icon ?? ""
        textColor: Theme.background
        textSize: Appearance.fontSize + 2
      }
      StyledText {
        text: root.hoverTarget && !root.hoverValid ? I18n.tr("Doesn't fit here") : (root.dragging?.label ?? "")
        textColor: Theme.background
        font.bold: true
      }
    }
  }
}
