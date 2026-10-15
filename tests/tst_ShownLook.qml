import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "ShownLook"

  readonly property var fixed: ({
      "wallpaper": "a",
      "wallpapers": {
        "DP-1": "a",
        "HDMI-A-1": "b"
      }
    })
  readonly property var variants: ({
      "dark": "night",
      "light": "day"
    })

  function test_fixed() {
    const shown = ShownLook.wallpapers("fixed", fixed, variants, true, {
      "wallpaper": "r",
      "wallpapers": {
        "DP-1": "r"
      }
    });
    compare(shown, fixed, "rotation state is ignored outside rotate mode");
    verify(shown.wallpapers !== fixed.wallpapers, "a copy");
    compare(ShownLook.wallpaperFor(shown, "HDMI-A-1"), "b");
    compare(ShownLook.wallpaperFor(shown, "eDP-1"), "a", "an unlisted monitor shows the primary's");
  }

  function test_variant() {
    const dark = ShownLook.wallpapers("variant", fixed, variants, true, null);
    compare(ShownLook.wallpaperFor(dark, "DP-1"), "night");
    compare(ShownLook.wallpaperFor(dark, "HDMI-A-1"), "night", "on every monitor");
    compare(ShownLook.wallpaperFor(ShownLook.wallpapers("variant", fixed, variants, false, null), "HDMI-A-1"), "day");
    compare(ShownLook.wallpapers("variant", fixed, {
      "dark": "",
      "light": "day"
    }, true, null), fixed, "a variant without one shows the fixed ones");
  }

  function test_rotate() {
    compare(ShownLook.wallpapers("rotate", fixed, variants, true, null), fixed, "before the first rotation");
    const shown = ShownLook.wallpapers("rotate", fixed, variants, true, {
      "wallpaper": "r",
      "wallpapers": {
        "DP-1": "r"
      }
    });
    compare(shown.wallpaper, "r");
    compare(ShownLook.wallpaperFor(shown, "DP-1"), "r");
    compare(ShownLook.wallpaperFor(shown, "HDMI-A-1"), "b", "a monitor not rotated yet keeps its fixed one");
    compare(fixed.wallpapers["DP-1"], "a", "the fixed ones are untouched");
  }

  function test_theme() {
    const override = {
      "for": "nord-dark",
      "name": "nord-light"
    };
    compare(ShownLook.theme("nord-dark", true, override), "nord-light");
    compare(ShownLook.theme("nord-dark", false, override), "nord-dark", "the schedule is off");
    compare(ShownLook.theme("dracula", true, override), "dracula", "another theme was chosen since");
    compare(ShownLook.theme("nord-dark", true, null), "nord-dark");
  }
}
