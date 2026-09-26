pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// i18n: keys from the schema (module, view and layout labels)
// An editor page's whole area (overlay editor, edge menu editor). Owns the one drag in progress and its
// ghost, drawn above every panel so a module can be carried from the
// library onto the canvas, a cell between columns, a page up the list.
// Drop targets register themselves; draggables report their pointer here.
//
// Payloads: { kind, icon, label, ... }, kind one of
//   "module-add" { type }                  from the library
//   "module-move" { type, column, cell, slot }  a module on the canvas
//   "cell-add" { layout }                  from the library
//   "cell-move" { layout, column, cell }   a cell's grip
//   "column-move" { column }               a column's grip
//   "page-move" { index }                  a page row
// Targets: items with `targetKind` "slot" (column, cell, slot, rect),
// "column" (column, indexAt), "gap" (index) or "pages" (indexAt).
// Every edit goes to `editor` (a ColumnsEditor); page rows are the page's
// own business, so a "pages" drop is only reported (pageMoved).
Item {
  id: root

  required property ColumnsEditor editor

  signal pageMoved(int from, int to)

  default property alias content: contentItem.data

  property var dragging: null
  // The target under the pointer, the index a drop would insert at, and
  // whether dropping there would do anything
  property Item hoverTarget: null
  property int hoverIndex: -1
  property bool hoverValid: false

  property var _targets: []

  readonly property string draggingKind: root.dragging?.kind ?? ""
  readonly property bool carryingModule: root.draggingKind === "module-add" || root.draggingKind === "module-move"
  readonly property bool carryingCell: root.draggingKind === "cell-add" || root.draggingKind === "cell-move"
  // Anything a column gap takes
  readonly property bool carryingStructure: root.carryingModule || root.carryingCell || root.draggingKind === "column-move"

  function moduleIcon(type) {
    return OverlayConfig.moduleInfo(type)?.icon ?? "extension";
  }

  function moduleLabel(type) {
    const info = OverlayConfig.moduleInfo(type);
    return info ? I18n.tr(info.label) : (type || I18n.tr("Unknown"));
  }

  // Layout names spaced for display. Keys: I18n.tr("Single") I18n.tr("Tall")
  // I18n.tr("Wide") I18n.tr("Large") I18n.tr("Grid 2x2") I18n.tr("Vert 1x1")
  // I18n.tr("Vert 1x2") I18n.tr("Vert 2x1") I18n.tr("Horiz 1x1")
  // I18n.tr("Horiz 1x2") I18n.tr("Horiz 2x1")
  function layoutLabel(layout) {
    const spaced = (layout ?? "").replace(/([a-zA-Z]{2,})(\d)/g, "$1 $2");
    return I18n.tr(spaced);
  }

  function registerTarget(target) {
    root._targets = root._targets.concat([target]);
  }

  function unregisterTarget(target) {
    root._targets = root._targets.filter(t => t !== target);
    if (root.hoverTarget === target)
      root.hoverTarget = null;
  }

  function _priority(kind) {
    return kind === "slot" ? 3 : kind === "gap" ? 2 : 1;
  }

  function _accepts(kind, drag) {
    switch (kind) {
    case "slot":
      return drag.kind === "module-add" || drag.kind === "module-move";
    case "column":
      return root.carryingModule || root.carryingCell;
    case "gap":
      return root.carryingStructure;
    case "pages":
      return drag.kind === "page-move";
    }
    return false;
  }

  function _valid(target, drag) {
    if (target.targetKind !== "slot")
      return true;
    const to = {
      "column": target.column,
      "cell": target.cell,
      "slot": target.slot
    };
    if (drag.kind === "module-add")
      return OverlayConfig.fits(drag.type, target.rect);
    return root.editor.canMoveModule(drag, to);
  }

  // Starts carrying `payload`, picked up at (x, y) in `item`
  function begin(payload, item, x, y) {
    root.dragging = payload;
    root.move(item, x, y);
  }

  // The pointer is at (x, y) in `item`
  function move(item, x, y) {
    const p = item.mapToItem(root, x, y);
    ghost.x = p.x - ghost.height / 2;
    ghost.y = p.y - ghost.height / 2;
    let best = null;
    for (const target of root._targets) {
      if (!target.visible || !root._accepts(target.targetKind, root.dragging))
        continue;
      const q = root.mapToItem(target, p.x, p.y);
      if (q.x < 0 || q.y < 0 || q.x >= target.width || q.y >= target.height)
        continue;
      if (!best || root._priority(target.targetKind) > root._priority(best.targetKind))
        best = target;
    }
    root.hoverTarget = best;
    root.hoverIndex = best && best.indexAt ? best.indexAt(p) : -1;
    root.hoverValid = best !== null && root._valid(best, root.dragging);
  }

  // Dropped: does whatever the target under the pointer takes
  function end() {
    const drag = root.dragging;
    const target = root.hoverTarget;
    const index = root.hoverIndex;
    const valid = root.hoverValid;
    root.cancel();
    if (!drag || !target || !valid)
      return;
    const kind = target.targetKind;
    if (kind === "pages") {
      root.pageMoved(drag.index, index);
      return;
    }
    if (kind === "slot") {
      if (drag.kind === "module-add")
        root.editor.placeModule(drag.type, target.column, target.cell, target.slot);
      else
        root.editor.moveModule(drag, {
          "column": target.column,
          "cell": target.cell,
          "slot": target.slot
        });
      return;
    }
    const place = kind === "gap" ? {
      "kind": "gap",
      "index": target.index
    } : {
      "kind": "column",
      "column": target.column,
      "index": index
    };
    switch (drag.kind) {
    case "module-add":
      root.editor.addModuleCell(drag.type, place);
      break;
    case "module-move":
      root.editor.extractModule(drag, place);
      break;
    case "cell-add":
      root.editor.addCell(place, drag.layout);
      break;
    case "cell-move":
      root.editor.moveCell(drag.column, drag.cell, place);
      break;
    case "column-move":
      root.editor.moveColumn(drag.column, target.index);
      break;
    }
  }

  function cancel() {
    root.dragging = null;
    root.hoverTarget = null;
    root.hoverIndex = -1;
    root.hoverValid = false;
  }

  Item {
    id: contentItem
    anchors.fill: parent
  }

  // What's being carried, as a pill under the pointer
  Rectangle {
    id: ghost
    visible: root.dragging !== null
    z: 10
    width: ghostRow.implicitWidth + Widget.padding * 2
    height: Widget.height + Widget.padding / 2
    radius: Appearance.borderRadius
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
