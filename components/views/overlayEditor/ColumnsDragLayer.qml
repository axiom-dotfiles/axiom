pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// i18n: keys from the schema (module, view and layout labels)
// A columns editor's whole area (overlay editor, edge menu editor): a
// DragLayer whose ghost is drawn above every panel, so a module can be
// carried from the library onto the canvas, a cell between columns, a
// page up the list.
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
DragLayer {
  id: root

  required property ColumnsEditor editor

  signal pageMoved(int from, int to)

  // Whether dropping on the target under the pointer would do anything
  readonly property bool hoverValid: root.hoverTarget !== null && root.dragging !== null && root.canDrop(root.hoverTarget, root.dragging)

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
  // I18n.tr("Horiz 1x2") I18n.tr("Horiz 2x1") I18n.tr("Half Wide")
  // I18n.tr("Half Tall")
  function layoutLabel(layout) {
    return I18n.tr(Utils.spaceWords(layout));
  }

  // A slot wins over a gap, a gap over a column
  priority: target => target.targetKind === "slot" ? 3 : target.targetKind === "gap" ? 2 : 1
  accepts: (target, drag) => {
    switch (target.targetKind) {
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

  // Whether `drag` would land on `target` (a module fits its slot)
  function canDrop(target, drag) {
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

  onMoved: point => {
    ghost.x = point.x - ghost.height / 2;
    ghost.y = point.y - ghost.height / 2;
  }

  // Does whatever the target takes
  onDropped: (drag, target, index) => {
    if (!root.canDrop(target, drag))
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

  // What's being carried, as a pill under the pointer
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
