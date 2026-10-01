pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// The edited page (or edge menu) as it will look: its modules on their
// grid of quarter cards, drawn at the scale that fits, with room around them
// to drop into (left of or above the grid shifts it to make room). Drag a
// module to move it, its corner to resize it; the library's modules drop
// anywhere free. Geometry is scaled by hand (not Item.scale) so text and
// controls stay crisp.
Card {
  id: root

  required property var dragLayer
  // The modules being edited, or null when there's nothing to edit (then
  // `emptyText` shows under the icon)
  required property var modules
  property string title: ""
  property string icon: "dashboard"
  property string emptyText: ""
  // An edge menu's edge ("Left", …), drawn along that side; "" for a page
  property string edge: ""
  // An edge menu's screen around it ({ x, y, w, h } in grid units from
  // the grid's origin, GridPlacement.screenBox), else null: drawn as a
  // dashed outline, with what lies outside it tinted (it'd scroll)
  property var screenBox: null
  // How the result fits, under the title (e.g. per monitor)
  property string fitText: ""
  property bool fitWarning: false
  // Save / Reset for the whole editor's edits
  property bool dirty: false
  property bool canSave: true

  signal save
  signal reset

  readonly property bool editable: root.modules !== null && root.modules !== undefined
  readonly property var list: root.editable ? root.modules : []
  readonly property var bounds: GridPlacement.bounds(root.list)

  // Room around the grid, in grid units: to make space left of / above it,
  // and to grow it right / down
  readonly property int lead: 1
  readonly property int trail: 3
  // The axis the menu's edge runs along (a side menu's rows, else columns)
  readonly property bool alongRows: root.edge === "Left" || root.edge === "Right"
  // With a screen, the grid reaches one unit past it all round
  readonly property bool hasScreen: root.screenBox !== null && root.screenBox !== undefined
  readonly property int leadCols: root.hasScreen ? Math.max(0, Math.ceil(-root.screenBox.x - 0.001)) + 1 : root.lead
  readonly property int leadRows: root.hasScreen ? Math.max(0, Math.ceil(-root.screenBox.y - 0.001)) + 1 : root.lead
  readonly property int gridCols: root.leadCols + (root.hasScreen ? Math.max(root.bounds.cols, Math.ceil(root.screenBox.x + root.screenBox.w - 0.001)) + 1 : Math.max(root.bounds.cols, 8) + root.trail)
  readonly property int gridRows: root.leadRows + (root.hasScreen ? Math.max(root.bounds.rows, Math.ceil(root.screenBox.y + root.screenBox.h - 0.001)) + 1 : Math.max(root.bounds.rows, 4) + root.trail)

  // One grid unit and the gap after it, at the reference card size, then
  // scaled to fit the area
  readonly property real refStep: OverlayConfig.gridUnit + OverlayConfig.cardSpacing
  readonly property real scaleFactor: Math.max(0.05, Math.min(0.6, area.width / (root.gridCols * root.refStep), area.height / (root.gridRows * root.refStep)))
  readonly property real step: root.refStep * root.scaleFactor
  readonly property real gap: OverlayConfig.cardSpacing * root.scaleFactor
  readonly property real unitSize: root.step - root.gap
  // The corners of the lattice's squares and of the modules on it, the
  // same so they line up
  readonly property real cellRadius: Math.min(Widget.radius, root.unitSize / 4)
  // Where grid 0, 0 sits in the area
  readonly property real originX: (area.width - root.gridCols * root.step + root.gap) / 2 + root.leadCols * root.step
  readonly property real originY: (area.height - root.gridRows * root.step + root.gap) / 2 + root.leadRows * root.step
  // The lattice's drawn box, in the area
  readonly property rect latticeBox: Qt.rect(root.originX - root.leadCols * root.step, root.originY - root.leadRows * root.step, root.gridCols * root.step - root.gap, root.gridRows * root.step - root.gap)
  // The screen, in the area's px (its sides midway in the gaps)
  readonly property rect screenRect: root.hasScreen ? Qt.rect(root.originX + root.screenBox.x * root.step - root.gap / 2, root.originY + root.screenBox.y * root.step - root.gap / 2, root.screenBox.w * root.step, root.screenBox.h * root.step) : Qt.rect(0, 0, 0, 0)

  function rectFor(place) {
    return Qt.rect(root.originX + place.x * root.step, root.originY + place.y * root.step, place.w * root.unitSize + (place.w - 1) * root.gap, place.h * root.unitSize + (place.h - 1) * root.gap);
  }

  color: Theme.background
  border.color: Theme.border

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Widget.padding
    spacing: Widget.spacing

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height + Widget.padding
      spacing: Widget.spacing

      StyledIcon {
        text: root.icon
        textColor: Theme.accent
        textSize: Appearance.fontSize + 6
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing

          StyledText {
            text: root.title
            textSize: Appearance.fontSize + 4
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: root.width / 3
          }

          StyledText {
            visible: root.editable
            text: I18n.tr("{0} modules", root.list.length)
            opacity: 0.6
            textSize: Appearance.fontSize - 1
          }

          Item {
            Layout.fillWidth: true
          }
        }

        StyledText {
          visible: root.editable && root.fitText !== ""
          Layout.fillWidth: true
          text: root.fitText
          textColor: root.fitWarning ? Theme.warning : Theme.foreground
          opacity: root.fitWarning ? 1 : 0.6
          textSize: Appearance.fontSize - 2
          elide: Text.ElideRight
        }
      }

      StyledText {
        visible: root.editable
        Layout.maximumWidth: root.width / 3
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: I18n.tr("Drag to move · drag a corner to resize · click to edit")
        opacity: 0.5
        textSize: Appearance.fontSize - 2
      }

      SaveResetActions {
        dirty: root.dirty
        canSave: root.canSave
        onSave: root.save()
        onReset: root.reset()
      }
    }

    Item {
      id: area
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      // Clicking the background drops the selection
      MouseArea {
        anchors.fill: parent
        onClicked: root.dragLayer.editor.clearSelection()
      }

      // Nothing to edit: a tool page, or none at all
      Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, Appearance.fontSize * 30)
        spacing: Widget.spacing
        visible: !root.editable

        StyledIcon {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.icon
          textColor: Theme.accent
          textSize: Appearance.fontSize * 4
          opacity: 0.8
        }
        StyledText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.emptyText
          opacity: 0.7
        }
      }

      // The drop target: the whole area, snapped to the grid
      Item {
        id: gridTarget
        anchors.fill: parent
        visible: root.editable

        readonly property string targetKind: "grid"

        // Where `drag` would go with the pointer at `point` (in the drag
        // layer): a moved module keeps the unit it was grabbed by
        // under the pointer, a new one is centred on it
        function placeAt(point, drag, grab) {
          const p = root.dragLayer.mapToItem(gridTarget, point.x, point.y);
          const col = Math.floor((p.x - root.originX + root.gap / 2) / root.step);
          const row = Math.floor((p.y - root.originY + root.gap / 2) / root.step);
          let w = drag.w ?? 2;
          let h = drag.h ?? 2;
          let grabCol = Math.floor((w - 1) / 2);
          let grabRow = Math.floor((h - 1) / 2);
          if (drag.kind === "module-move") {
            const module = root.list[drag.index];
            if (!module)
              return null;
            w = module.place.w;
            h = module.place.h;
            grabCol = Math.max(0, Math.min(w - 1, Math.floor(grab.x / root.step)));
            grabRow = Math.max(0, Math.min(h - 1, Math.floor(grab.y / root.step)));
          }
          return {
            "x": col - grabCol,
            "y": row - grabRow,
            "w": w,
            "h": h
          };
        }

        Component.onCompleted: root.dragLayer.registerTarget(gridTarget)
        Component.onDestruction: root.dragLayer.unregisterTarget(gridTarget)
      }

      // The unit lattice, one square per grid unit: stronger inside the
      // modules' bounds. One Canvas, as there can be hundreds of squares.
      Canvas {
        id: lattice
        anchors.fill: parent
        visible: root.editable
        readonly property string paintKey: [root.gridCols, root.gridRows, root.step, root.originX, root.originY, root.bounds.cols, root.bounds.rows, root.screenRect.x, root.screenRect.y, root.screenRect.width, root.screenRect.height, root.cellRadius, width, height, Theme.border, Theme.warning].join(",")
        onPaintKeyChanged: lattice.requestPaint()
        onPaint: {
          const ctx = lattice.getContext("2d");
          ctx.reset();
          ctx.strokeStyle = Theme.border;
          ctx.lineWidth = 1;
          ctx.fillStyle = Theme.warning;
          const radius = root.cellRadius;
          for (let row = -root.leadRows; row < root.gridRows - root.leadRows; row++) {
            for (let col = -root.leadCols; col < root.gridCols - root.leadCols; col++) {
              const inside = col >= 0 && row >= 0 && col < root.bounds.cols && row < root.bounds.rows;
              const box = root.screenBox;
              const past = root.hasScreen && (col + 0.5 < box.x || col + 0.5 > box.x + box.w || row + 0.5 < box.y || row + 0.5 > box.y + box.h);
              const x = Math.round(root.originX + col * root.step) + 0.5;
              const y = Math.round(root.originY + row * root.step) + 0.5;
              ctx.beginPath();
              ctx.roundedRect(x, y, root.unitSize - 1, root.unitSize - 1, radius, radius);
              if (past) {
                ctx.globalAlpha = 0.08;
                ctx.fill();
              }
              ctx.globalAlpha = inside ? 0.45 : 0.18;
              ctx.stroke();
            }
          }
          // The screen's outline, past which the menu scrolls
          if (root.hasScreen) {
            const r = root.screenRect;
            ctx.globalAlpha = 0.9;
            ctx.strokeStyle = Theme.warning;
            ctx.lineWidth = 2;
            ctx.setLineDash([6, 4]);
            ctx.beginPath();
            ctx.rect(Math.round(r.x) + 0.5, Math.round(r.y) + 0.5, Math.round(r.width), Math.round(r.height));
            ctx.stroke();
          }
        }
      }

      // An edge menu's screen edge along its side of the grid: all of it
      // faintly, with the menu where it sits on it, and the part the menu
      // covers solid
      Repeater {
        model: root.editable && root.edge !== "" ? (root.hasScreen ? 2 : 1) : 0

        Rectangle {
          id: edgeLine
          required property int index
          // 0: the menu's part, 1: the whole edge
          readonly property bool whole: edgeLine.index === 1
          readonly property rect box: root.rectFor({
            "x": 0,
            "y": 0,
            "w": Math.max(1, root.bounds.cols),
            "h": Math.max(1, root.bounds.rows)
          })
          readonly property real thick: Math.max(3, root.gap / 2)
          readonly property real across: root.edge === "Left" ? box.x - root.gap / 2 - thick / 2 : root.edge === "Right" ? box.x + box.width + root.gap / 2 - thick / 2 : root.edge === "Top" ? box.y - root.gap / 2 - thick / 2 : box.y + box.height + root.gap / 2 - thick / 2
          readonly property real start: edgeLine.whole ? (root.alongRows ? root.screenRect.y : root.screenRect.x) : (root.alongRows ? box.y : box.x)
          readonly property real length: edgeLine.whole ? (root.alongRows ? root.screenRect.height : root.screenRect.width) : (root.alongRows ? box.height : box.width)
          visible: edgeLine.whole || root.list.length > 0
          z: edgeLine.whole ? 0 : 1
          x: root.alongRows ? edgeLine.across : edgeLine.start
          y: root.alongRows ? edgeLine.start : edgeLine.across
          width: root.alongRows ? edgeLine.thick : edgeLine.length
          height: root.alongRows ? edgeLine.length : edgeLine.thick
          radius: edgeLine.thick / 2
          color: Theme.accent
          opacity: edgeLine.whole ? 0.3 : 1
        }
      }

      // The screen's name, under its outline's far corner
      StyledText {
        visible: root.editable && root.hasScreen
        x: Math.max(0, Math.min(area.width - width, root.screenRect.x + root.screenRect.width - width))
        y: Math.max(0, Math.min(area.height - height, root.screenRect.y + root.screenRect.height + 2))
        text: I18n.tr("Screen edge")
        textColor: Theme.warning
        textSize: Appearance.fontSize - 3
      }

      StyledText {
        visible: root.editable && root.list.length === 0 && root.dragLayer.dragging === null
        anchors.centerIn: parent
        width: Math.min(parent.width, Appearance.fontSize * 26)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: I18n.tr("Empty: drag modules here from the library below, or click one to add it.")
        opacity: 0.7
      }

      // Keyed by count: edits update the modules in place
      Repeater {
        model: root.list.length

        CanvasModule {
          id: tile
          readonly property rect r: root.rectFor(tile.module?.place ?? {
            "x": 0,
            "y": 0,
            "w": 1,
            "h": 1
          })
          dragLayer: root.dragLayer
          radius: root.cellRadius
          module: root.list[tile.index] ?? null
          step: root.step
          gap: root.gap
          x: tile.r.x
          y: tile.r.y
          width: tile.r.width
          height: tile.r.height
        }
      }

      // Where the carried module would land
      Rectangle {
        readonly property var place: root.dragLayer.hoverPlace
        readonly property rect r: place ? root.rectFor(place) : Qt.rect(0, 0, 0, 0)
        visible: place !== null
        z: 5
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        radius: root.cellRadius
        color: Qt.alpha(root.dragLayer.hoverValid ? Theme.accent : Theme.error, 0.18)
        border.color: root.dragLayer.hoverValid ? Theme.accent : Theme.error
        border.width: 2
      }
    }
  }
}
