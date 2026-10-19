import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "KeyMap"

  function test_rowsAreEvenlyWide() {
    for (const row of KeyMap.rows)
      compare(row.reduce((sum, k) => sum + k.width, 0), 15);
  }

  function test_keysAreUnique() {
    const seen = {};
    for (const key of KeyMap.allKeys) {
      verify(seen[key.toLowerCase()] === undefined, key);
      seen[key.toLowerCase()] = true;
    }
  }

  function test_occupancy() {
    const binds = [
      {
        "key": "SUPER + Q",
        "action": "terminal"
      },
      {
        "key": "SUPER + W",
        "action": "browser",
        "paused": true
      },
      {
        "key": "SUPER + SHIFT + Q",
        "action": "closeWindow"
      },
      {
        "key": "SUPER + E",
        "action": "fileManager"
      }
    ];
    const user = {};
    user[BindKeys.keyId("SUPER + R")] = 1;
    user[BindKeys.keyId("SUPER + E")] = 1;
    const map = KeyMap.occupancy(binds, user, ["SUPER"], ["q", "w", "e", "r", "t"]);
    compare(map.q.source, "axiom");
    compare(map.q.index, 0);
    compare(map.w.source, "paused");
    compare(map.w.index, 1);
    compare(map.e.source, "both");
    compare(map.r.source, "user");
    compare(map.t.source, "free");
    compare(map.t.index, -1);
    // Another set of modifiers is another set of keys
    const shifted = KeyMap.occupancy(binds, user, ["SUPER", "SHIFT"], ["q", "w"]);
    compare(shifted.q.index, 2);
    compare(shifted.w.source, "free");
  }

  function test_pausedYieldsToActive() {
    const binds = [
      {
        "key": "SUPER + A",
        "paused": true
      },
      {
        "key": "SUPER + A"
      }
    ];
    const map = KeyMap.occupancy(binds, {}, ["SUPER"], ["a"]);
    compare(map.a.source, "axiom");
    compare(map.a.index, 1);
  }
}
