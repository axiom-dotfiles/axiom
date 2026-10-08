pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable
// Loaded by URL, as in OverlaySlot
import qs.components.content // qmllint disable unused-imports

// A module's detail grown over its grid (ModuleGrid.expand): a card box
// opening out of the tile or strip that asked for it to the whole grid,
// with a back button and the module's name over content/<type>.qml. The
// content sits at its full size from the first frame, revealed by the
// growing box (as a popout's is), so it lays out once. Back, Escape or
// collapse() shrink it into where it came from; `closed` then drops it.
Item {
  id: root

  // { type, properties, from: [x, y, w, h] px in the grid }, or null
  property var request: null
  // Where the grid is shown, handed on to the content
  property var host: ({
      "kind": "overlay"
    })
  // The whole grid in units, the content's slot (so it isn't compact)
  property var slotRect: [0, 0, 4, 4]

  signal closed

  // Grown out to the grid (false while opening from, or shrinking back
  // into, the tile)
  property bool shown: false
  // Animates the box only once it's been put on the tile
  property bool _animate: false
  // The request being shown, kept through the shrink after it's dropped
  property var _shownRequest: null
  // Where the keyboard was before, given back on close
  property var _focusBefore: null

  readonly property var _from: root._shownRequest?.from ?? [0, 0, root.width, root.height]
  readonly property var _info: OverlayConfig.moduleInfo(root._shownRequest?.type ?? "")

  visible: root._shownRequest !== null

  onRequestChanged: {
    if (!root.request)
      return;
    root._animate = false;
    root.shown = false;
    root._shownRequest = root.request;
    Qt.callLater(() => {
      root._animate = true;
      root.shown = true;
      root._focusBefore = root.Window.window?.activeFocusItem ?? null;
      root.forceActiveFocus();
    });
  }

  function collapse() {
    if (!root.shown)
      return;
    root.shown = false;
    done.restart();
    if (root._focusBefore)
      root._focusBefore.forceActiveFocus();
    root._focusBefore = null;
  }

  // Dropped once it's back in the tile
  Timer {
    id: done
    interval: Appearance.animNormal
    onTriggered: {
      root._shownRequest = null;
      root.closed();
    }
  }

  Keys.onEscapePressed: root.collapse()

  // Clicks around the box don't reach the faded modules
  MouseArea {
    anchors.fill: parent
    enabled: root.visible
    onClicked: root.collapse()
  }

  Rectangle {
    id: box
    x: root.shown ? 0 : root._from[0]
    y: root.shown ? 0 : root._from[1]
    width: root.shown ? root.width : root._from[2]
    height: root.shown ? root.height : root._from[3]
    opacity: root.shown ? 1 : 0
    color: Appearance.fill(Theme.background)
    border.color: Theme.border
    border.width: Appearance.borderWidth
    radius: Widget.radius
    clip: true

    Glide on x {
      enabled: root._animate
      duration: Appearance.animNormal
    }
    Glide on y {
      enabled: root._animate
      duration: Appearance.animNormal
    }
    Glide on width {
      enabled: root._animate
      duration: Appearance.animNormal
    }
    Glide on height {
      enabled: root._animate
      duration: Appearance.animNormal
    }
    Glide on opacity {
      enabled: root._animate
    }

    // Takes clicks inside the box, so only those outside collapse it
    MouseArea {
      anchors.fill: parent
    }

    // At the grid's place whatever the box's, so it never moves
    Item {
      x: -box.x
      y: -box.y
      width: root.width
      height: root.height

      RowLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Widget.spacing
        spacing: Widget.spacing

        FlatIconButton {
          iconText: "arrow_back"
          tooltipText: I18n.tr("Back")
          onClicked: root.collapse()
        }
        StyledIcon {
          text: root._info?.icon ?? ""
          textColor: Theme.accent
        }
        StyledText {
          Layout.fillWidth: true
          text: I18n.tr(root._info?.label ?? "")
          elide: Text.ElideRight
          font.bold: true
        }
      }

      Item {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: OverlayConfig.cardPad(false, false)
        anchors.topMargin: 0

        Loader {
          id: loader
          anchors.fill: parent
          active: root._shownRequest !== null
          opacity: root.shown ? 1 : 0
          Glide on opacity {
            duration: Appearance.animNormal
          }

          readonly property string componentPath: root._shownRequest?.type ? Qt.resolvedUrl("../../content/" + root._shownRequest.type + ".qml") : ""
          onComponentPathChanged: {
            if (!loader.componentPath)
              return;
            // Bare: the box above is its card, and pads it
            loader.setSource(loader.componentPath, {
              "properties": root._shownRequest.properties ?? {},
              "slotRect": root.slotRect,
              "embedded": true,
              "host": Object.assign({}, root.host, {
                "bare": true
              })
            });
          }
        }
      }
    }
  }
}
