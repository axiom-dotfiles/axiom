pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.services
import qs.config
// Imported (though loaded by URL) so qs scans the content types
import qs.components.content // qmllint disable unused-imports

/**
 * Popout wrapper for bar widgets
 * Handles positioning, animation, and content loading for popouts that emerge from the bar.
 * Open/close/queue state and dismiss timing live in PopoutWrapperBase — this
 * file only adds what's specific to bar popouts: which content type to
 * load, where to position it, and how to animate it in/out.
 */
PopoutWrapperBase {
  id: root

  required property ShellScreen screen
  required property var barConfig
  required property QtObject panel

  property alias popupWindow: mainPopup
  // Content box in popupWindow coordinates (see AttachedSurface.boxRect)
  readonly property rect boxRect: surface.boxRect

  // The content-type name travels inside currentData.name (see
  // PopoutAnchor.qml) rather than as a separate argument, so this file
  // never needs to override openPopout/safeOpenPopout from the base.
  readonly property string currentName: currentData?.name ?? ""
  // Which side the tray's submenus open to
  readonly property bool openToLeft: root.barConfig.right || mainPopup.isOnRightHalfOfScreen

  // content/<name>.qml, loaded by URL like bar widgets and overlay modules:
  // a new popout is just a file there plus a PopoutAnchor naming it
  function _loadContent() {
    if (loader.active && root.currentName !== "")
      loader.setSource(Qt.resolvedUrl("../../content/" + root.currentName + ".qml"), {
        "wrapper": root
      });
    else if (!loader.active)
      // Cleared, so reactivating doesn't first rebuild the previous popout
      loader.source = "";
  }
  onCurrentNameChanged: _loadContent()

  currentItem: loader.item ?? null

  // Content with a text field up asks for the keyboard (Panel's
  // wantsKeyboardFocus): a focus grab over the popout and its bar, which a
  // click outside clears (the content's focusLost())
  readonly property bool wantsKeyboardFocus: mainPopup.visible && (root.currentItem?.wantsKeyboardFocus ?? false)

  HyprlandFocusGrab {
    windows: [mainPopup, root.panel]
    active: root.wantsKeyboardFocus
    onCleared: root.currentItem?.focusLost?.()
  }

  // Gap between bar and main content (connector thickness)
  property int connectorGap: Appearance.borderRadius * 2

  // The bar's BarContainer. Its layoutUpdated signal re-anchors an open
  // popout, so it stays attached to a widget that moves or resizes.
  property var layoutSource: null

  // Where the anchor widget currently is, in bar-window coordinates. Read
  // live from currentData.anchorItem; the anchorX/anchorY snapshot in the
  // payload is only the fallback for callers that don't pass an item.
  property rect anchorRect: Qt.rect(0, 0, 0, 0)

  function updateAnchorRect() {
    const data = root.currentData;
    if (!data)
      return;
    const item = data.anchorItem;
    if (item) {
      try {
        const pos = item.mapToItem(null, 0, 0);
        root.anchorRect = Qt.rect(pos.x, pos.y, item.width, item.height);
        return;
      } catch (e) {
        // Anchor was destroyed (e.g. the bar rebuilt on a config reload)
      }
    }
    root.anchorRect = Qt.rect(data.anchorX ?? 0, data.anchorY ?? 0, data.anchorWidth ?? 0, data.anchorHeight ?? 0);
  }

  onCurrentDataChanged: updateAnchorRect()

  // On a pill bar: its pills ({ start, length, joinStart, joinEnd } along
  // the bar), and the one the anchor sits in, if any
  readonly property var pills: root.barConfig.pills ? (root.layoutSource?.pillRects ?? []) : []
  readonly property var anchorPill: {
    const rects = root.pills;
    const center = root.barConfig.vertical ? root.anchorRect.y + root.anchorRect.height / 2 : root.anchorRect.x + root.anchorRect.width / 2;
    for (let i = 0; i < rects.length; i++) {
      if (center >= rects[i].start && center <= rects[i].start + rects[i].length)
        return {
          "index": i,
          "start": rects[i].start,
          "length": rects[i].length,
          "joinStart": rects[i].joinStart,
          "joinEnd": rects[i].joinEnd
        };
    }
    return null;
  }
  // A popout not wholly within its pill merges around it: it grows from
  // the bar's outer edge, its box deeper by the pill so the content clears
  // it, with the pill left showing through a notch. Every other pill it
  // reaches along the bar shows through a notch of its own. Where a pill
  // carries on past the box, that side stands on its far stroke instead.
  readonly property bool mergeWithPill: anchorPill !== null && (mainPopup.boxStart < anchorPill.start || mainPopup.boxEnd > anchorPill.start + anchorPill.length)
  // The pills a merged popout's surface overlaps, the anchor's included
  readonly property var mergedPills: {
    if (!mergeWithPill)
      return [];
    const from = mainPopup.alongPos, to = mainPopup.alongPos + surface.implicitLength;
    return root.pills.filter(p => p.start < to && p.start + p.length > from);
  }
  // Where a side wall's fillet lands: on a pill when one carries on at
  // least a fillet's width past that side, else down on the edge
  readonly property real pillFoot: root.barConfig.pillDepth - Appearance.borderWidth
  readonly property real startFoot: mergeWithPill && !mainPopup.joinStart && root.pills.some(p => p.start <= mainPopup.boxStart - Appearance.borderRadius && p.start + p.length >= mainPopup.boxStart) ? pillFoot : 0
  readonly property real endFoot: mergeWithPill && !mainPopup.joinEnd && root.pills.some(p => p.start <= mainPopup.boxEnd && p.start + p.length >= mainPopup.boxEnd + Appearance.borderRadius) ? pillFoot : 0
  // A merged box whose side wall falls just short of another pill's stroke
  // would draw its wall and fillet a few pixels off that stroke, a double
  // line with a sliver of wallpaper between. How far to shift a box at
  // `start` (at most a connector gap) so the wall lies on the stroke and
  // stands on the pill (see startFoot/endFoot); 0 when none is that close.
  function pillSnap(start) {
    const own = root.anchorPill;
    const end = start + mainPopup.boxLength;
    if (own === null || (start >= own.start && end <= own.start + own.length))
      return 0;
    const bw = Appearance.borderWidth, r = Appearance.borderRadius;
    for (const p of root.pills) {
      const toEnd = p.start + bw - end;
      if (toEnd > 0 && toEnd <= root.connectorGap && p.start + p.length >= end + toEnd + r)
        return toEnd;
      const toStart = start - (p.start + p.length - bw);
      if (toStart > 0 && toStart <= root.connectorGap && p.start <= start - toStart - r)
        return -toStart;
    }
    return 0;
  }
  // An unmerged popout stands on its pill's far stroke. When its box sits
  // just inside the pill's end, its fillet would run past the straight
  // part of that stroke, so the pill is stretched (for as long as the
  // popout shows) to carry it: { index, start, end } along the bar
  readonly property var pillStretch: {
    const p = root.anchorPill;
    if (!root.occupied || p === null || root.mergeWithPill)
      return null;
    const start = p.joinStart ? p.start : Math.min(p.start, mainPopup.alongPos - Appearance.borderRadius);
    const end = p.joinEnd ? p.start + p.length : Math.max(p.start + p.length, mainPopup.alongPos + surface.implicitLength + Appearance.borderRadius);
    if (start === p.start && end === p.start + p.length)
      return null;
    return {
      "index": p.index,
      "start": start,
      "end": end
    };
  }
  Binding {
    target: root.layoutSource
    property: "pillStretch"
    value: root.pillStretch
    when: root.layoutSource !== null
  }
  // How far past the pill the merged popout's content starts: its far
  // stroke, where an unmerged popout attaches, with the border on or off
  readonly property real pillClearance: mergeWithPill ? root.pillFoot : 0
  // Where the popout attaches, measured from the bar's outer edge: the
  // outer edge itself when merged, a pill's far stroke, the bar's own
  // inner stroke (solid, border off), or the bar's inner edge (where the
  // border strip's stroke starts)
  readonly property real attachAt: mergeWithPill ? 0 : anchorPill !== null ? pillFoot : root.barConfig.extent - (root.barConfig.innerStroke ? Appearance.borderWidth : 0)
  // How far inside a pill's ends the notch stops: its stroke, plus a pixel
  // so the stroke's anti-aliased edge stays covered too
  readonly property real notchInset: Appearance.borderWidth + 1
  // The bar window's thickness (more than the bar's extent with pills)
  readonly property real panelThickness: root.panel?.thickness ?? root.barConfig.extent

  Connections {
    target: root.layoutSource
    // Positions settle through bindings after the signal, so read them once
    // they have. A pinned popout stays where it opened.
    function onLayoutUpdated() {
      if (root.occupied && !root.currentData?.pinned)
        Qt.callLater(root.updateAnchorRect);
    }
  }

  // Clear the anchor widget's popoutOpen flag on dismiss, so hovering it
  // again is allowed to open a fresh popout. Safety net for however this
  // popout ends up destroyed lives alongside it.
  onAboutToDismiss: {
    if (currentData?.anchorItem) {
      currentData.anchorItem.popoutOpen = false;
    }
  }

  Component.onDestruction: {
    if (currentData?.anchorItem) {
      currentData.anchorItem.popoutOpen = false;
    }
    ShellManager.unregisterGrabPartner(mainPopup);
  }

  // The overlay's focus grab lets input through to the popout (see
  // ShellManager.grabPartners)
  Component.onCompleted: ShellManager.registerGrabPartner(mainPopup, root.screen?.name)
  onScreenChanged: ShellManager.registerGrabPartner(mainPopup, root.screen?.name)

  PopupWindow {
    id: mainPopup
    visible: root.occupied && loader.status === Loader.Ready
    color: "transparent"

    // Content dimensions
    readonly property int contentWidth: root.currentItem?.implicitWidth ?? 200
    readonly property int contentHeight: root.currentItem?.implicitHeight ?? 100
    readonly property bool isOnRightHalfOfScreen: root.anchorRect.x > (root.screen.width / 2)

    // Along-bar clamp range, in bar-window coordinates. The perpendicular
    // screen borders may sit inside the bar window (bar mapped first) or
    // outside it, so derive where their inner edge falls from how much of
    // the screen the window spans. The surface (fillets included) keeps a
    // screen margin clear of that edge, so the fillets never run into the
    // border's inner corner — the same gap EdgePopout leaves.
    readonly property real panelLength: {
      const mapped = root.barConfig.vertical ? root.panel.height : root.panel.width;
      return mapped > 0 ? mapped : (root.barConfig.vertical ? root.screen.height : root.screen.width);
    }
    readonly property real frameWidth: Appearance.screenBorder ? Appearance.screenMargin : 0
    // Integrated edge menus on the perpendicular edges sit outside
    // everything else, taking their space off one end only
    readonly property real menuZones: root.barConfig.vertical ? EdgeMenuManager.zoneOn(root.screen?.name, "top") + EdgeMenuManager.zoneOn(root.screen?.name, "bottom") : EdgeMenuManager.zoneOn(root.screen?.name, "left") + EdgeMenuManager.zoneOn(root.screen?.name, "right")
    readonly property real borderInset: frameWidth - ((root.barConfig.vertical ? root.screen.height : root.screen.width) - panelLength - menuZones) / 2
    readonly property real minAlong: borderInset + Appearance.screenMargin
    readonly property real maxAlong: panelLength - borderInset - Appearance.screenMargin
    // Outer edges of the perpendicular border strokes (the screen edges
    // with the border off), where a popout pushed to an end joins
    readonly property real strokeStart: borderInset - (Appearance.screenBorder ? Appearance.borderWidth : 0)
    readonly property real strokeEnd: panelLength - strokeStart

    // Along the bar, in bar-window coordinates: the box centred on the
    // anchor, and the surface around it with a fillet margin each side.
    // One that would be pushed back from an end instead joins it: flush on
    // the perpendicular stroke, merging into that edge.
    readonly property real boxLength: (root.barConfig.vertical ? mainPopup.contentHeight : mainPopup.contentWidth) + surface.contentInset * 2
    readonly property real filletMargin: root.connectorGap - Appearance.borderWidth
    readonly property real alignedBoxStart: {
      if (!root.currentData)
        return 0;
      const start = root.barConfig.vertical ? root.anchorRect.y : root.anchorRect.x;
      const length = root.barConfig.vertical ? root.anchorRect.height : root.anchorRect.width;
      return start + (length - mainPopup.boxLength) / 2;
    }
    readonly property bool joinStart: alignedBoxStart - filletMargin < minAlong
    readonly property bool joinEnd: !joinStart && alignedBoxStart + boxLength + filletMargin > maxAlong
    readonly property real boxStart: {
      if (joinStart)
        return strokeStart;
      if (joinEnd)
        return strokeEnd - boxLength;
      const lo = minAlong + filletMargin, hi = maxAlong - filletMargin - boxLength;
      const clamped = Math.max(lo, Math.min(alignedBoxStart, hi));
      return Math.max(lo, Math.min(clamped + root.pillSnap(clamped), hi));
    }
    readonly property real boxEnd: boxStart + boxLength
    // Where the popup (the surface) starts along the bar
    // (the surface's own margin: none on a joined or straight side)
    readonly property real alongPos: boxStart - surface.startMargin

    // On a transparent bar a popout is a detached box, unless it's pushed
    // to an end: then there's no bar to take its bar side, so it attaches
    // to that perpendicular edge instead, joining it on both sides
    readonly property bool detached: root.barConfig.background === "transparent"
    readonly property bool cornerAttach: detached && (joinStart || joinEnd)
    readonly property int surfaceEdge: {
      if (!cornerAttach)
        return root.barConfig.location;
      if (root.barConfig.vertical)
        return joinStart ? Bar.Top : Bar.Bottom;
      return joinStart ? Bar.Left : Bar.Right;
    }
    // Where a detached box sits across the bar (its top-left, in
    // bar-window coordinates): the connector gap past the bar's inner edge
    readonly property real boxAcross: {
      const near = root.attachAt + root.connectorGap / 2;
      if (root.barConfig.left || root.barConfig.top)
        return near;
      return root.panelThickness - near - (root.barConfig.vertical ? surface.boxWidth : surface.boxHeight);
    }

    // The merged pills stay hoverable and clickable through the notches
    mask: Region {
      item: surface
      regions: notchRegions.instances
    }

    // Size comes from the shared attached shape: the content box wraps
    // the content plus the surface's inset on every side.
    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    anchor {
      window: root.currentAnchor
      // Placement is worked out here (clamped along the bar, flush on its
      // edge), so the compositor mustn't slide it: flush against the screen
      // edge it would nudge the popup inwards
      adjustment: PopupAdjustment.None

      rect {
        x: {
          if (!root.currentData)
            return 0;
          if (mainPopup.cornerAttach)
            return root.barConfig.vertical ? mainPopup.boxAcross - surface.startMargin : (mainPopup.joinStart ? mainPopup.strokeStart : mainPopup.strokeEnd - mainPopup.implicitWidth);

          if (root.barConfig.left) {
            return root.attachAt;
          } else if (root.barConfig.right) {
            // Mirror of the left case: measured from the bar's outer edge,
            // not relative to the anchor (tray icons are narrower than modules)
            return root.panelThickness - root.attachAt - mainPopup.implicitWidth;
          } else {
            return mainPopup.alongPos;
          }
        }

        y: {
          if (!root.currentData)
            return 0;
          if (mainPopup.cornerAttach)
            return root.barConfig.vertical ? (mainPopup.joinStart ? mainPopup.strokeStart : mainPopup.strokeEnd - mainPopup.implicitHeight) : mainPopup.boxAcross - surface.startMargin;

          if (root.barConfig.top) {
            return root.attachAt;
          } else if (root.barConfig.bottom) {
            return root.panelThickness - root.attachAt - mainPopup.implicitHeight;
          } else {
            return mainPopup.alongPos;
          }
        }

        width: 1
        height: 1
      }
    }

    AttachedSurface {
      id: surface
      anchors.fill: parent

      edge: mainPopup.surfaceEdge
      active: root.occupied && !root.isClosing
      connectorGap: root.connectorGap
      boxWidth: mainPopup.contentWidth + contentInset * 2 + (root.barConfig.vertical ? root.pillClearance : 0)
      boxHeight: mainPopup.contentHeight + contentInset * 2 + (root.barConfig.vertical ? 0 : root.pillClearance)

      // A transparent bar has nothing to join onto (see cornerAttach)
      detached: mainPopup.detached && !mainPopup.cornerAttach
      joinStart: !mainPopup.cornerAttach && mainPopup.joinStart
      joinEnd: !mainPopup.cornerAttach && mainPopup.joinEnd
      // Without the border, a popout merged around a pill runs straight off
      // the screen edge, and one pushed to an end straight off that one
      straight: (root.mergeWithPill || mainPopup.cornerAttach) && !Appearance.screenBorder
      straightJoins: !Appearance.screenBorder
      startFoot: root.startFoot
      endFoot: root.endFoot

      // The pills' interiors, left showing; the popout covers their
      // strokes where they overlap, so they read as one shape
      notches: root.mergedPills.map(p => {
        const from = p.start + (p.joinStart ? 0 : root.notchInset);
        const to = p.start + p.length - (p.joinEnd ? 0 : root.notchInset);
        return {
          "start": from - mainPopup.alongPos,
          "length": Math.max(0, to - from),
          "roundStart": !p.joinStart && from > mainPopup.alongPos,
          "roundEnd": !p.joinEnd && to < mainPopup.alongPos + implicitLength
        };
      })
      notchDepth: root.pillFoot - 1
      readonly property real implicitLength: root.barConfig.vertical ? implicitHeight : implicitWidth

      Variants {
        id: notchRegions
        model: surface.notchRects

        Region {
          required property rect modelData
          intersection: Intersection.Subtract
          x: modelData.x
          y: modelData.y
          width: modelData.width
          height: modelData.height
        }
      }

      Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: surface.contentInset
        // Merged around a pill, the content starts past it
        anchors.leftMargin: surface.contentInset + (root.barConfig.left ? root.pillClearance : 0)
        anchors.rightMargin: surface.contentInset + (root.barConfig.right ? root.pillClearance : 0)
        anchors.topMargin: surface.contentInset + (root.barConfig.top ? root.pillClearance : 0)
        anchors.bottomMargin: surface.contentInset + (root.barConfig.bottom ? root.pillClearance : 0)

        active: root.occupied
        asynchronous: false

        onActiveChanged: root._loadContent()

        onLoaded: {
          if (item) {
            if (root.currentData) {
              for (let key in root.currentData) {
                if (item.hasOwnProperty(key)) {
                  // Content may derive one itself (readonly, e.g.
                  // WorkspaceGrid's monitor): skip it rather than abort
                  try {
                    item[key] = root.currentData[key];
                  } catch (e) {}
                }
              }
            }
          }
          root.updateDismissTimer();
        }
      }
    }
  }
}
