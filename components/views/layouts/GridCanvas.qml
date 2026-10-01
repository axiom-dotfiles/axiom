pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.content.base

// The edited page (or edge menu) as it will look: its modules on their
// grid of half cards, drawn at the scale that fits, with room around them
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

  // Room around the grid, in half units: to make space left of / above it,
  // and to grow it right / down
  readonly property int lead: 2
  readonly property int trail: 3
  readonly property int gridCols: Math.max(root.bounds.cols, 4) + root.lead + root.trail
  readonly property int gridRows: Math.max(root.bounds.rows, 2) + root.lead + root.trail

  // One half unit and the gap after it, at the reference card size, then
  // scaled to fit the area
  readonly property real refStep: OverlayConfig.halfUnit + OverlayConfig.cardSpacing
  readonly property real scaleFactor: Math.max(0.05, Math.min(0.6, area.width / (root.gridCols * root.refStep), area.height / (root.gridRows * root.refStep)))
  readonly property real step: root.refStep * root.scaleFactor
  readonly property real gap: OverlayConfig.cardSpacing * root.scaleFactor
  readonly property real half: root.step - root.gap
  // Where grid 0, 0 sits in the area
  readonly property real originX: (area.width - root.gridCols * root.step + root.gap) / 2 + root.lead * root.step
  readonly property real originY: (area.height - root.gridRows * root.step + root.gap) / 2 + root.lead * root.step

  function rectFor(place) {
    return Qt.rect(root.originX + place.x * root.step, root.originY + place.y * root.step, place.w * root.half + (place.w - 1) * root.gap, place.h * root.half + (place.h - 1) * root.gap);
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
        // layer): a moved module keeps the half unit it was grabbed by
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

      // The half-unit lattice
      Repeater {
        model: root.editable ? root.gridCols * root.gridRows : 0

        Rectangle {
          required property int index
          readonly property int col: index % root.gridCols - root.lead
          readonly property int row: Math.floor(index / root.gridCols) - root.lead
          readonly property bool inside: col >= 0 && row >= 0 && col < root.bounds.cols && row < root.bounds.rows
          x: root.originX + col * root.step
          y: root.originY + row * root.step
          width: root.half
          height: root.half
          radius: Widget.radius / 2
          color: "transparent"
          border.color: Theme.border
          border.width: 1
          opacity: inside ? 0.45 : 0.18
        }
      }

      // An edge menu's edge, along its side of the grid
      Rectangle {
        visible: root.editable && root.edge !== "" && root.list.length > 0
        readonly property rect box: root.rectFor({
          "x": 0,
          "y": 0,
          "w": Math.max(1, root.bounds.cols),
          "h": Math.max(1, root.bounds.rows)
        })
        readonly property real thick: Math.max(3, root.gap / 2)
        x: root.edge === "Left" ? box.x - root.gap / 2 - thick / 2 : root.edge === "Right" ? box.x + box.width + root.gap / 2 - thick / 2 : box.x
        y: root.edge === "Top" ? box.y - root.gap / 2 - thick / 2 : root.edge === "Bottom" ? box.y + box.height + root.gap / 2 - thick / 2 : box.y
        width: root.edge === "Left" || root.edge === "Right" ? thick : box.width
        height: root.edge === "Left" || root.edge === "Right" ? box.height : thick
        radius: thick / 2
        color: Theme.accent
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
        radius: Widget.radius
        color: Qt.alpha(root.dragLayer.hoverValid ? Theme.accent : Theme.error, 0.18)
        border.color: root.dragLayer.hoverValid ? Theme.accent : Theme.error
        border.width: 2
      }
    }
  }
}
