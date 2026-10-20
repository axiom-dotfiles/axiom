import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "KeyNames"

  function test_modifierLabel() {
    compare(KeyNames.modifierLabel("SUPER"), "Super");
    compare(KeyNames.modifierLabel("CTRL"), "Ctrl");
    compare(KeyNames.modifierLabel("MOD3"), "Mod3");
  }

  function test_modifierGlyph() {
    compare(KeyNames.modifierGlyph("SHIFT"), "⇧");
    compare(KeyNames.modifierGlyph("CTRL"), "⌃");
    compare(KeyNames.modifierGlyph("SUPER"), "", "drawn as an icon");
    compare(KeyNames.modifierGlyph("MOD3"), "");
  }

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

  function test_fromWheel() {
    compare(KeyNames.fromWheel(0, -120, Qt.MetaModifier, []), "SUPER + mouse_down");
    compare(KeyNames.fromWheel(0, 120, Qt.NoModifier, ["SUPER"]), "SUPER + mouse_up");
    compare(KeyNames.fromWheel(120, 0, Qt.ShiftModifier | Qt.MetaModifier, []), "SUPER + SHIFT + mouse_left");
    compare(KeyNames.fromWheel(0, 0, Qt.MetaModifier, []), "");
  }

  function test_tapModifier() {
    compare(KeyNames.tapModifier("Super_L"), "SUPER");
    compare(KeyNames.tapModifier("SUPER + SUPER_R"), "SUPER", "written with its own modifier");
    compare(KeyNames.tapModifier("control_r"), "CTRL");
    compare(KeyNames.tapModifier("CTRL + Super_L"), "", "held with another modifier");
    compare(KeyNames.tapModifier("SUPER + Q"), "");
    compare(KeyNames.tapModifier(""), "");
  }

  function test_tapName() {
    compare(KeyNames.tapName(Qt.Key_Super_L, 133), "Super_L");
    compare(KeyNames.tapName(Qt.Key_Super_R, 134), "Super_R");
    compare(KeyNames.tapName(Qt.Key_Control, 105), "Control_R", "the keycode tells the side");
    compare(KeyNames.tapName(Qt.Key_Alt, 0), "Alt_L", "no keycode: the left one");
    compare(KeyNames.tapName(Qt.Key_Shift, 133), "Shift_L", "a keycode of another modifier is ignored");
    compare(KeyNames.tapName(Qt.Key_A, 38), "");
  }
}
