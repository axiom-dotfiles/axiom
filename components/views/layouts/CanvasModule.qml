pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// One module on the layouts canvas: its icon and name (plus a hint for
// modules whose look depends on their properties). Click to edit it, drag
// it to move it (onto a module of its size: they swap), drag its corner
// to resize it. Positioned and sized by GridCanvas.
Rectangle {
  id: root

  required property var dragLayer
  required property int index
  // { type, properties, place }
  property var module: null
  // One grid unit plus its gap, and the gap, at the canvas's scale
  required property real step
  required property real gap

  readonly property GridEditor editor: root.dragLayer.editor
  readonly property string type: root.module?.type ?? ""
  readonly property var place: root.module?.place ?? {
    "x": 0,
    "y": 0,
    "w": 1,
    "h": 1
  }
  readonly property bool selected: root.editor.selected === root.index
  // Doesn't fit its own size (blocks Save)
  readonly property bool misfit: root.type !== "" && !OverlayConfig.fits(root.type, GridPlacement.rectOf(root.place))
  readonly property bool carried: root.dragLayer.draggingKind === "module-move" && root.dragLayer.dragging.index === root.index
  readonly property bool small: root.width < Appearance.fontSize * 7 || root.height < Appearance.fontSize * 4

  readonly property bool isSwatch: root.type === "ColorSwatch"
  readonly property color fill: root.isSwatch ? Theme.resolveColor(root.module.properties?.color) : Theme.backgroundAlt
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

  // The size being dragged to with the corner handle ([w, h]), else null
  property var resizing: null
  readonly property bool resizeValid: root.resizing !== null && root.editor.canResize(root.index, root.resizing[0], root.resizing[1])

  z: root.selected || root.resizing ? 2 : 1
  radius: Widget.radius
  color: root.fill
  border.color: root.misfit ? Theme.error : root.selected ? Theme.accent : Theme.border
  border.width: root.selected || root.misfit ? Math.max(Appearance.borderWidth, 2) : Appearance.borderWidth
  opacity: root.carried ? 0.3 : 1

  Behavior on opacity {
    NumberAnimation {
      duration: Appearance.animFast
    }
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - 8
    spacing: 2

    StyledIcon {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.dragLayer.moduleIcon(root.type)
      textColor: root.isSwatch ? root.ink : Theme.accent
      textSize: root.small ? Appearance.fontSize + 2 : Appearance.fontSize + 8
    }

    StyledText {
      width: parent.width
      visible: !root.small
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
      text: root.misfit ? I18n.tr("doesn't fit this size") : root.detail
      textColor: root.misfit ? Theme.error : root.ink
      textSize: Appearance.fontSize - 3
      opacity: 0.75
    }
  }

  DragArea {
    id: area
    anchors.fill: parent
    cursorShape: root.dragLayer.dragging !== null ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    dragLayer: root.dragLayer
    payload: ({
        "kind": "module-move",
        "index": root.index,
        "type": root.type,
        "icon": root.dragLayer.moduleIcon(root.type),
        "label": root.dragLayer.moduleLabel(root.type)
      })
    onTapped: root.editor.select(root.index)
  }

  // The size the corner is being dragged to
  Rectangle {
    visible: root.resizing !== null
    x: 0
    y: 0
    width: root.resizing ? root.resizing[0] * root.step - root.gap : 0
    height: root.resizing ? root.resizing[1] * root.step - root.gap : 0
    radius: root.radius
    color: Qt.alpha(root.resizeValid ? Theme.accent : Theme.error, 0.18)
    border.color: root.resizeValid ? Theme.accent : Theme.error
    border.width: 2
  }

  // The resize handle, in the bottom right corner
  Rectangle {
    id: handle
    readonly property real size: Math.max(10, Math.min(root.width, root.height) / 5)
    visible: root.dragLayer.dragging === null && (area.containsMouse || handleArea.containsMouse || root.selected || root.resizing !== null)
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 2
    width: handle.size
    height: handle.size
    radius: Widget.radius / 2
    color: handleArea.containsMouse || root.resizing ? Theme.accent : Theme.backgroundHighlight
    border.color: Theme.accent
    border.width: 1

    StyledIcon {
      anchors.centerIn: parent
      text: "open_in_full"
      rotation: 90
      textSize: Math.max(8, handle.size * 0.6)
      textColor: handleArea.containsMouse || root.resizing ? Theme.background : Theme.accent
    }

    MouseArea {
      id: handleArea
      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true
      preventStealing: true
      cursorShape: Qt.SizeFDiagCursor

      onPressed: {
        root.editor.select(root.index);
        root.resizing = [root.place.w, root.place.h];
      }
      onPositionChanged: mouse => {
        if (!pressed)
          return;
        const p = handleArea.mapToItem(root, mouse.x, mouse.y);
        root.resizing = [Math.max(1, Math.round((p.x + root.gap) / root.step)), Math.max(1, Math.round((p.y + root.gap) / root.step))];
      }
      onReleased: {
        const size = root.resizing;
        root.resizing = null;
        if (size)
          root.editor.resizeModule(root.index, size[0], size[1]);
      }
      onCanceled: root.resizing = null
    }
  }
}
