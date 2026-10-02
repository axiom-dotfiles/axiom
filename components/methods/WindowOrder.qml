pragma Singleton
import QtQuick

// Windows in the order they were used (the window switcher): hyprctl
// clients by focusHistoryID, and stepping through them.
QtObject {
  id: root

  // The windows `keep` accepts, most recently focused first. `activeAddress`
  // (the focused window, known from events before hyprctl's list catches
  // up) goes first whatever its focusHistoryID says, so a quick second
  // switch still swaps back.
  function mru(windows, keep, activeAddress) {
    const kept = (windows ?? []).filter(win => keep(win));
    kept.sort((a, b) => (a.focusHistoryID ?? Infinity) - (b.focusHistoryID ?? Infinity));
    const active = kept.findIndex(win => win.address === activeAddress);
    if (active > 0)
      kept.unshift(kept.splice(active, 1)[0]);
    return kept;
  }

  // `index` moved `step` places, wrapping around `count`
  function stepIndex(index, step, count) {
    if (count <= 0)
      return 0;
    return ((index + step) % count + count) % count;
  }
}
