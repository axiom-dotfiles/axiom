pragma Singleton
import QtQuick

// Windows in the order they were used (the window switcher): the
// compositor's windows by focusRank, and stepping through them.
QtObject {
  id: root

  // The windows `keep` accepts, most recently focused first. `activeId`
  // (the focused window, known from events before the window list catches
  // up) goes first whatever its focusRank says, so a quick second switch
  // still swaps back.
  function mru(windows, keep, activeId) {
    const kept = (windows ?? []).filter(win => keep(win));
    kept.sort((a, b) => (a.focusRank ?? Infinity) - (b.focusRank ?? Infinity));
    const active = kept.findIndex(win => win.id === activeId);
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
