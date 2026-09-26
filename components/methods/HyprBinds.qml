pragma Singleton
import QtQuick

// Binds against what Hyprland reports (`hyprctl binds -j` entries): a key's
// id as Hyprland lists it, which of axiom's binds the runtime layer applies
// and which it skips because the user's config already binds that key, and
// how many binds on each key are the user's own.
QtObject {
  id: root

  readonly property var _modBits: ({
      "SHIFT": 1,
      "CAPS": 2,
      "LOCK": 2,
      "CTRL": 4,
      "CONTROL": 4,
      "ALT": 8,
      "MOD1": 8,
      "MOD2": 16,
      "MOD3": 32,
      "SUPER": 64,
      "WIN": 64,
      "LOGO": 64,
      "MOD4": 64,
      "META": 64,
      "MOD5": 128
    })

  // "SUPER + SHIFT + SPACE" as hyprctl binds lists it ("64:space"), or ""
  function keyId(key) {
    const parts = String(key ?? "").split("+").map(part => part.trim()).filter(part => part !== "");
    if (parts.length === 0)
      return "";
    let mask = 0;
    for (const mod of parts.slice(0, -1)) {
      const bit = _modBits[mod.toUpperCase()];
      if (bit === undefined)
        return "";
      mask |= bit;
    }
    return mask + ":" + parts[parts.length - 1].toLowerCase();
  }

  // A hyprctl binds entry's id, in keyId's form (a keycode bind as code:N)
  function entryId(entry) {
    const key = entry.key || (entry.keycode ? "code:" + entry.keycode : "");
    return entry.modmask + ":" + String(key).toLowerCase();
  }

  /**
   * What the runtime layer does with `binds` (axiom's, each with a `key`)
   * given Hyprland's `entries`: { apply: [bind], skipped: [key],
   * unreadable: [key] }. A key an entry outside a submap already holds is
   * skipped, so the user's own config wins; so is one keyId can't read.
   * Call it with Hyprland's binds as they are without axiom's.
   */
  function runtimeBinds(binds, entries) {
    const taken = {};
    for (const entry of entries ?? [])
      if (!entry.submap)
        taken[entryId(entry)] = true;
    const result = {
      "apply": [],
      "skipped": [],
      "unreadable": []
    };
    for (const bind of binds ?? []) {
      const id = keyId(bind.key);
      if (id === "")
        result.unreadable.push(String(bind.key ?? ""));
      else if (taken[id])
        result.skipped.push(String(bind.key).trim());
      else
        result.apply.push(bind);
    }
    return result;
  }

  /**
   * How many binds on each key id are the user's: every entry outside a
   * submap, less one for each of axiom's `applied` binds (its own binds
   * show up among the entries too).
   */
  function userKeyCounts(entries, applied) {
    const counts = {};
    for (const entry of entries ?? []) {
      if (entry.submap)
        continue;
      const id = entryId(entry);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (const bind of applied ?? []) {
      const id = keyId(bind.key);
      if (id !== "" && counts[id])
        counts[id]--;
    }
    return counts;
  }
}
