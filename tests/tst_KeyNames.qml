import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "KeyNames"

  function test_keyName() {
    compare(KeyNames.keyName(Qt.Key_A, 0), "A");
    compare(KeyNames.keyName(Qt.Key_5, 0), "5");
    compare(KeyNames.keyName(Qt.Key_F12, 0), "F12");
    compare(KeyNames.keyName(Qt.Key_Space, 0), "space");
    compare(KeyNames.keyName(Qt.Key_Enter, 0), "Return");
    compare(KeyNames.keyName(Qt.Key_Shift, 50), "");
    compare(KeyNames.keyName(0x01ffffff, 191), "code:191");
    compare(KeyNames.keyName(0x01ffffff, 0), "");
  }

  function test_fromEvent_orders_modifiers() {
    compare(KeyNames.fromEvent(Qt.Key_Q, Qt.ShiftModifier | Qt.MetaModifier | Qt.ControlModifier, 0), "SUPER + CTRL + SHIFT + Q");
    compare(KeyNames.fromEvent(Qt.Key_Control, Qt.ControlModifier, 0), "");
  }

  function test_modifierFor() {
    compare(KeyNames.modifierFor(Qt.Key_Super_L), "SUPER");
    compare(KeyNames.modifierFor(Qt.Key_Alt), "ALT");
    compare(KeyNames.modifierFor(Qt.Key_A), "");
  }

  function test_split_normalises_aliases() {
    const parts = KeyNames.split(" mod4 + control+ Mod1 +space ");
    compare(parts.mods, ["SUPER", "CTRL", "ALT"]);
    compare(parts.key, "space");
    compare(KeyNames.split("").key, "");
    compare(KeyNames.split(null).mods, []);
  }

  function test_join_round_trips() {
    const combo = "SUPER + SHIFT + Return";
    const parts = KeyNames.split(combo);
    compare(KeyNames.join(parts.mods, parts.key), combo);
  }
}
