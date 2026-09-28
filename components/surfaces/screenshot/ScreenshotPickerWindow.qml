pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import qs.components.reusable
import qs.config
import qs.services

// One screen's screenshot picker: the screen frozen (one ScreencopyView
// frame), dimmed except for what a click or release would capture, with
// the window under the cursor highlighted. `region`: drag a region, or
// click for the window under the cursor (the whole screen where there's
// none), Enter for the screen. `window`: click a window. Esc or
// right-click cancels; Shift on release, or E, opens it in the annotator.
// An immediate `screen` capture shows the same frame with nothing over it
// and grabs as soon as it arrives. The capture is cropped from the frame
// at the screen's own resolution.
PanelWindow {
  id: root

  readonly property var request: ScreenshotManager.request
  readonly property bool interactive: request?.kind === "region" || request?.kind === "window"
  // Only whole windows: no dragging, and a click off a window does nothing
  readonly property bool windowsOnly: request?.kind === "window"
  readonly property bool focusedScreen: screen?.name === (Hyprland.focusedMonitor?.name ?? "")
  // Buffer pixels per logical pixel
  readonly property real pixelRatio: frame.sourceSize.width > 0 && root.width > 0 ? frame.sourceSize.width / root.width : (screen?.devicePixelRatio ?? 1)
  readonly property rect fullRect: Qt.rect(0, 0, root.width, root.height)

  // The window under the cursor ({ x, y, width, height }, local), or null
  property var hoveredWindow: null
  property bool dragging: false
  property point dragStart: Qt.point(0, 0)
  property point dragEnd: Qt.point(0, 0)
  property bool grabbing: false

  readonly property rect dragRect: Qt.rect(Math.min(dragStart.x, dragEnd.x), Math.min(dragStart.y, dragEnd.y), Math.abs(dragEnd.x - dragStart.x), Math.abs(dragEnd.y - dragStart.y))
  // What a release would capture
  readonly property rect selection: dragging ? dragRect : hoveredWindow ? Qt.rect(hoveredWindow.x, hoveredWindow.y, hoveredWindow.width, hoveredWindow.height) : windowsOnly ? Qt.rect(0, 0, 0, 0) : fullRect

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "axiom-screenshot"
  WlrLayershell.keyboardFocus: root.interactive && root.focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // This screen's windows, topmost first (fullscreen, then floating, then
  // most recently focused), as local boxes clipped to the screen (by the
  // screen's size: the window has none yet when this runs)
  function _windows() {
    const monitor = Hyprland.monitorFor(root.screen);
    const shown = [monitor?.activeWorkspace?.id, monitor?.lastIpcObject?.specialWorkspace?.id].filter(id => id !== undefined && id !== 0);
    return HyprlandManager.windowList.filter(w => w.at && w.size && !w.hidden && w.mapped !== false && shown.includes(w.workspace?.id)).sort((a, b) => (b.fullscreen > 0) - (a.fullscreen > 0) || b.floating - a.floating || a.focusHistoryID - b.focusHistoryID).map(w => _clip(w.at[0] - root.screen.x, w.at[1] - root.screen.y, w.size[0], w.size[1])).filter(box => box.width > 0 && box.height > 0);
  }

  function _clip(x, y, width, height) {
    const left = Math.max(0, x);
    const top = Math.max(0, y);
    return {
      "x": left,
      "y": top,
      "width": Math.min(root.screen.width, x + width) - left,
      "height": Math.min(root.screen.height, y + height) - top
    };
  }

  // Refreshed as the picker opens: nothing moves while it's up
  property var windows: []

  function _windowAt(x, y) {
    return root.windows.find(w => x >= w.x && x < w.x + w.width && y >= w.y && y < w.y + w.height) ?? null;
  }

  // Crops `area` (local logical pixels) out of the frame and hands it over
  function capture(area) {
    if (root.grabbing)
      return;
    const rect = Qt.rect(Math.round(area.x), Math.round(area.y), Math.round(area.width), Math.round(area.height));
    if (rect.width < 1 || rect.height < 1) {
      ScreenshotManager.cancel();
      return;
    }
    root.grabbing = true;
    const size = Qt.size(Math.round(rect.width * root.pixelRatio), Math.round(rect.height * root.pixelRatio));
    cropper.width = rect.width;
    cropper.height = rect.height;
    crop.sourceRect = rect;
    crop.textureSize = size;
    if (!cropper.grabToImage(result => ScreenshotManager.finish(result), size))
      ScreenshotManager.finish(null);
  }

  // The frame arrives once; an immediate capture takes it straight away
  function _onFrame() {
    if (!frame.hasContent || root.interactive || root.request?.screen !== root.screen?.name)
      return;
    // After the frame's first render, so the crop has something to sample
    Qt.callLater(() => root.capture(root.fullRect));
  }

  Component.onCompleted: {
    if (!root.interactive)
      return;
    root.windows = root._windows();
    // Highlight what's under the cursor before it moves (the pointer only
    // reports a position here once it does)
    HyprlandManager.withCursorPos(pos => {
      if (pos && !root.dragging && root.hoveredWindow === null)
        root.hoveredWindow = root._windowAt(pos.x - root.screen.x, pos.y - root.screen.y);
    });
  }

  // Under the frame (never seen), rendered only for the grab
  Item {
    id: cropper
    z: -1

    ShaderEffectSource {
      id: crop
      anchors.fill: parent
      sourceItem: frame
      hideSource: false
      smooth: true
    }
  }

  ScreencopyView {
    id: frame
    anchors.fill: parent
    captureSource: root.screen
    live: false
    paintCursor: false
    onHasContentChanged: root._onFrame()
  }

  // A picker that never gets its frame (no screencopy support) gives up
  Timer {
    running: root.interactive && root.focusedScreen && !frame.hasContent
    interval: 3000
    onTriggered: ScreenshotManager.fail(I18n.tr("The compositor sent no picture of the screen."))
  }

  Item {
    id: chrome
    anchors.fill: parent
    visible: root.interactive && frame.hasContent && !root.grabbing
    focus: true

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape)
        ScreenshotManager.cancel();
      else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !root.windowsOnly)
        root.capture(root.fullRect);
      else if (event.key === Qt.Key_C && !ScreenshotManager.forCaller)
        ScreenshotManager.setCopyOnly(!ScreenshotManager.copyOnly);
      else if (event.key === Qt.Key_E && ScreenshotManager.annotator !== "" && !ScreenshotManager.forCaller)
        ScreenshotManager.annotate = !ScreenshotManager.annotate;
      else
        return;
      event.accepted = true;
    }

    // Dim everything but the selection
    Repeater {
      model: [Qt.rect(0, 0, root.width, root.selection.y), Qt.rect(0, root.selection.y + root.selection.height, root.width, root.height - root.selection.y - root.selection.height), Qt.rect(0, root.selection.y, root.selection.x, root.selection.height), Qt.rect(root.selection.x + root.selection.width, root.selection.y, root.width - root.selection.x - root.selection.width, root.selection.height)]

      Rectangle {
        required property rect modelData
        x: modelData.x
        y: modelData.y
        width: Math.max(0, modelData.width)
        height: Math.max(0, modelData.height)
        color: Qt.rgba(0, 0, 0, 0.45)
      }
    }

    Rectangle {
      x: root.selection.x
      y: root.selection.y
      width: root.selection.width
      height: root.selection.height
      color: root.dragging ? "transparent" : Qt.alpha(Theme.accent, 0.12)
      border.color: Theme.accent
      border.width: Math.max(2, Appearance.borderWidth)
      visible: root.dragging || root.hoveredWindow !== null
    }

    // Size in the picture's own pixels
    Rectangle {
      readonly property bool below: root.selection.y + root.selection.height + height + 6 < root.height
      x: Math.min(root.width - width, Math.max(0, root.selection.x))
      y: below ? root.selection.y + root.selection.height + 6 : Math.max(0, root.selection.y - height - 6)
      width: sizeText.implicitWidth + 12
      height: sizeText.implicitHeight + 6
      radius: Appearance.borderRadius / 2
      color: Theme.background
      visible: root.dragging || root.hoveredWindow !== null

      StyledText {
        id: sizeText
        anchors.centerIn: parent
        text: `${Math.round(root.selection.width * root.pixelRatio)} × ${Math.round(root.selection.height * root.pixelRatio)}`
        textSize: Appearance.fontSize - 3
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.CrossCursor

      onPositionChanged: mouse => {
        if (pressed && (mouse.buttons & Qt.LeftButton) && !root.windowsOnly) {
          root.dragEnd = Qt.point(mouse.x, mouse.y);
          if (!root.dragging && Math.hypot(mouse.x - root.dragStart.x, mouse.y - root.dragStart.y) >= 6)
            root.dragging = true;
        } else {
          root.hoveredWindow = root._windowAt(mouse.x, mouse.y);
        }
      }
      onPressed: mouse => {
        if (mouse.button === Qt.RightButton) {
          ScreenshotManager.cancel();
          return;
        }
        root.dragStart = Qt.point(mouse.x, mouse.y);
        root.dragEnd = root.dragStart;
      }
      onReleased: mouse => {
        if (mouse.button !== Qt.LeftButton)
          return;
        if (mouse.modifiers & Qt.ShiftModifier && ScreenshotManager.annotator !== "" && !ScreenshotManager.forCaller)
          ScreenshotManager.annotate = true;
        // Copied: a rect read from a property re-reads it on use, and the
        // selection falls back to the window or screen once not dragging
        const sel = root.selection;
        const area = Qt.rect(sel.x, sel.y, sel.width, sel.height);
        root.dragging = false;
        if (area.width > 0 && area.height > 0)
          root.capture(area);
      }
    }

    // Controls, out of the way while dragging
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      width: hints.implicitWidth + 24
      height: hints.implicitHeight + 16
      radius: Appearance.borderRadius
      color: Theme.background
      border.color: Theme.border
      border.width: Appearance.borderWidth
      visible: root.focusedScreen && !root.dragging

      // Clicks between the buttons aren't captures
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
      }

      Row {
        id: hints
        anchors.centerIn: parent
        spacing: Widget.spacing * 2

        StyledTextButton {
          anchors.verticalCenter: parent.verticalCenter
          visible: !ScreenshotManager.forCaller
          iconText: ScreenshotManager.copyOnly ? "content_copy" : "save"
          text: ScreenshotManager.copyOnly ? I18n.tr("Copy only") : I18n.tr("Save and copy")
          onClicked: ScreenshotManager.setCopyOnly(!ScreenshotManager.copyOnly)
        }

        StyledTextButton {
          anchors.verticalCenter: parent.verticalCenter
          visible: ScreenshotManager.annotator !== "" && !ScreenshotManager.forCaller
          iconText: "edit"
          text: I18n.tr("Annotate")
          backgroundColor: ScreenshotManager.annotate ? Theme.accent : Theme.backgroundHighlight
          textColor: ScreenshotManager.annotate ? Theme.background : Theme.foreground
          onClicked: ScreenshotManager.annotate = !ScreenshotManager.annotate
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          visible: !root.windowsOnly
          key: I18n.tr("Drag")
          label: I18n.tr("region")
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          key: I18n.tr("Click")
          label: root.windowsOnly ? I18n.tr("window") : I18n.tr("window (screen off a window)")
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          visible: !ScreenshotManager.forCaller && !root.windowsOnly
          key: "↵"
          label: I18n.tr("screen")
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          visible: !ScreenshotManager.forCaller
          key: "C"
          label: I18n.tr("copy only")
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          visible: ScreenshotManager.annotator !== "" && !ScreenshotManager.forCaller
          key: "E"
          label: I18n.tr("annotate")
        }

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          key: "Esc"
          label: I18n.tr("cancel")
        }
      }
    }
  }
}
