pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

/**
 * Shared state machine for any "popout wrapper": open/close/reopen
 * queueing, and centralized dismiss-on-hover-loss timing.
 *
 * Concrete wrappers (BarPopouts, TraySubmenuWrapper, EdgePopout,
 * FloatingOSD, IntegratedEdgeMenu) use this as their root type and add
 * their own window, positioning, and content Loader as children, binding
 * `currentItem` to their Loader's item.
 *
 * Deliberately generic on (anchor, data) — no fixed signature per
 * subclass. If a subclass needs extra routing info (e.g. BarPopouts'
 * popout name), it travels as a field inside `data` rather than as an
 * extra positional argument, so this base never needs overriding.
 */
Item {
  id: root

  property var currentData: null
  property var currentAnchor: null
  property bool occupied: false
  property bool isClosing: false

  // Bind this in the subclass to your Loader's item, e.g.:
  //   currentItem: loader.item ?? null
  property Item currentItem: null

  property var pendingOpenData: null
  property var pendingOpenAnchor: null
  property bool hasPendingOpen: false

  // ---- Centralized dismiss logic ----
  // Content just exposes `hovered` (optionally folding in its own extra
  // "keep me alive" conditions, e.g. an active drag or an open submenu).
  // Timing and dismissal live here, once, for every popout type.
  // `keepAlive` lets a wrapper add hover sources of its own (e.g. an edge
  // trigger strip) without the content having to know about them.
  // dismissDelay/autoDismiss default to the content's values but can be
  // overridden by the wrapper.
  // The widget that opened the popout (`anchorItem` in the payload) counts
  // too, so the popout stays up while the pointer is still on it.
  property bool keepAlive: false
  readonly property bool anchorHovered: currentData?.anchorItem?.hovered ?? false
  readonly property bool contentHovered: (currentItem?.hovered ?? false) || anchorHovered || keepAlive
  property int dismissDelay: currentItem?.dismissDelay ?? PopoutConfig.dismissDelay
  property bool autoDismiss: currentItem?.autoDismiss ?? true

  onContentHoveredChanged: updateDismissTimer()

  // A popup that maps over its anchor (one merged around a pill covers the
  // bar, with the pill showing through a notch in its input mask) takes the
  // pointer before its mask applies. Once it does, the pointer is back over
  // the bar, but Hyprland sends the bar no enter until it moves, so nothing
  // reads as hovered and the popout would close under a still pointer. So
  // a popout with an anchor notes the cursor when hover is lost, and before
  // dismissing checks it: if it hasn't moved, hover was lost under it, not
  // by leaving, and the popout stays until the next hover change (or the
  // cursor moving, checked every parkCheckInterval).
  property var _lostCursor: null
  readonly property int parkCheckInterval: 1000

  function _noteLostCursor() {
    _lostCursor = null;
    const data = currentData;
    if (!data?.anchorItem)
      return;
    HyprlandManager.withCursorPos(pos => {
      if (root.currentData === data && !root.contentHovered)
        root._lostCursor = pos;
    });
  }

  function _tryDismiss() {
    if (!occupied || isClosing || contentHovered)
      return;
    const lost = _lostCursor;
    if (lost === null) {
      requestDismiss();
      return;
    }
    const data = currentData;
    HyprlandManager.withCursorPos(pos => {
      // Reopened, closed or hovered again meanwhile
      if (root.currentData !== data || !root.occupied || root.isClosing || root.contentHovered)
        return;
      if (pos !== null && pos.x === lost.x && pos.y === lost.y)
        parkTimer.restart();
      else
        root.requestDismiss();
    });
  }

  function updateDismissTimer() {
    // Nothing to dismiss while closed (content can stay loaded and hover
    // sources can change without the popout being open)
    if (!occupied || !autoDismiss) {
      dismissTimer.stop();
      parkTimer.stop();
      return;
    }
    parkTimer.stop();
    if (contentHovered) {
      dismissTimer.stop();
    } else {
      dismissTimer.restart();
      _noteLostCursor();
    }
  }

  // Subclasses that need to do something extra on dismiss (e.g. clearing
  // an anchor widget's popoutOpen flag) should connect via:
  //   onAboutToDismiss: { ... }
  signal aboutToDismiss

  function requestDismiss() {
    parkTimer.stop();
    aboutToDismiss();
    closePopout();
  }
  // ---- end centralized dismiss logic ----

  function closePopout() {
    if (isClosing)
      return;
    isClosing = true;
    closeDelayTimer.restart();
  }

  function openPopout(anchor, data) {
    if (isClosing)
      return;
    // Drop any stale countdown from whatever was here before. This must
    // come first: setting `occupied` loads the content synchronously, and
    // stopping afterwards cancelled the countdown its onLoaded started,
    // leaving a popout the pointer never entered open forever.
    dismissTimer.stop();
    parkTimer.stop();
    _lostCursor = null;
    currentAnchor = anchor;
    currentData = data;
    occupied = true;
    updateDismissTimer();
  }

  function safeOpenPopout(anchor, data) {
    if (occupied && !isClosing) {
      pendingOpenData = data;
      pendingOpenAnchor = anchor;
      hasPendingOpen = true;
      requestDismiss();
    } else if (!occupied && !isClosing) {
      openPopout(anchor, data);
    } else {
      pendingOpenData = data;
      pendingOpenAnchor = anchor;
      hasPendingOpen = true;
    }
  }

  Timer {
    id: dismissTimer
    interval: root.dismissDelay
    repeat: false
    onTriggered: root._tryDismiss()
  }

  Timer {
    id: parkTimer
    interval: root.parkCheckInterval
    repeat: false
    onTriggered: root._tryDismiss()
  }

  Timer {
    id: closeDelayTimer
    interval: Appearance.animNormal
    repeat: false
    onTriggered: {
      root.occupied = false;
      root.isClosing = false;
      root.currentAnchor = null;
      root.currentData = null;
      root._lostCursor = null;

      if (root.hasPendingOpen) {
        root.hasPendingOpen = false;
        const data = root.pendingOpenData;
        const anchor = root.pendingOpenAnchor;
        root.pendingOpenData = null;
        root.pendingOpenAnchor = null;
        root.openPopout(anchor, data);
      }
    }
  }
}
