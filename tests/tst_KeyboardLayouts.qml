import QtQuick
import QtTest
import qs.components.methods

// KeyboardLayouts: a keyboard's layouts from their full names.
TestCase {
  name: "KeyboardLayouts"

  function test_shape() {
    compare(KeyboardLayouts.shape(["English (US)", "German"], 1, "us, de"), {
      "layouts": ["us", "de"],
      "index": 1,
      "keymap": "German"
    });
    // Codes that don't match the layouts are left alone
    compare(KeyboardLayouts.shape(["English (US)", "German"], 0, "us").layouts, ["us", "ge"]);
    compare(KeyboardLayouts.shape(["English (US)"], undefined, "").index, 0);
  }

  function test_code() {
    compare(KeyboardLayouts.code("English (US)"), "us");
    compare(KeyboardLayouts.code("German"), "ge");
    compare(KeyboardLayouts.code("English (Dvorak, intl.)"), "en");
  }
}
