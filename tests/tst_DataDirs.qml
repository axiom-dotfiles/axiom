import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "DataDirs"

  function test_fallbacks() {
    compare(DataDirs.xdg({
      "HOME": "/home/u"
    }), {
      "config": "/home/u/.config/axiom/",
      "state": "/home/u/.local/state/axiom/",
      "ui": "/home/u/.local/state/axiom/ui/",
      "data": "/home/u/.local/share/axiom/",
      "notes": "/home/u/.local/share/axiom/notes/",
      "generatedThemes": "/home/u/.local/state/axiom/themes/"
    });
  }

  function test_xdgVariables() {
    const dirs = DataDirs.xdg({
      "HOME": "/home/u",
      "XDG_CONFIG_HOME": "/cfg/",
      "XDG_STATE_HOME": "/st",
      "XDG_DATA_HOME": "/data//"
    });
    compare(dirs.config, "/cfg/axiom/", "a trailing slash isn't doubled");
    compare(dirs.state, "/st/axiom/");
    compare(dirs.notes, "/data/axiom/notes/");
  }

  function test_ignoredVariables() {
    const dirs = DataDirs.xdg({
      "HOME": "/home/u/",
      "XDG_CONFIG_HOME": "relative/cfg",
      "XDG_STATE_HOME": "  ",
      "XDG_DATA_HOME": undefined
    });
    compare(dirs.config, "/home/u/.config/axiom/", "a relative XDG path is ignored (the spec)");
    compare(dirs.state, "/home/u/.local/state/axiom/", "a blank one too");
    compare(dirs.data, "/home/u/.local/share/axiom/");
  }

  function test_legacy() {
    const env = {
      "HOME": "/home/u",
      "XDG_STATE_HOME": "/st"
    };
    compare(DataDirs.legacy(env, "/repo"), {
      "config": "/repo/config/user/",
      "state": "/st/axiom/",
      "ui": "/repo/config/state/",
      "data": "/home/u/.local/share/axiom/",
      "notes": "/repo/config/state/notes/",
      "generatedThemes": "/repo/config/themes/generated/"
    }, "state and data were already XDG");
    compare(DataDirs.legacy(env, "/repo/").config, "/repo/config/user/", "with or without a trailing slash");
  }
}
