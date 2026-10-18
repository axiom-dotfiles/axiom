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
      "generatedThemes": "/home/u/.local/state/axiom/themes/",
      "communityThemes": "/home/u/.local/share/axiom/themes/",
      "cache": "/home/u/.cache/axiom/"
    });
  }

  function test_xdgVariables() {
    const dirs = DataDirs.xdg({
      "HOME": "/home/u",
      "XDG_CONFIG_HOME": "/cfg/",
      "XDG_STATE_HOME": "/st",
      "XDG_DATA_HOME": "/data//",
      "XDG_CACHE_HOME": "/cache"
    });
    compare(dirs.config, "/cfg/axiom/", "a trailing slash isn't doubled");
    compare(dirs.state, "/st/axiom/");
    compare(dirs.notes, "/data/axiom/notes/");
    compare(dirs.communityThemes, "/data/axiom/themes/");
    compare(dirs.cache, "/cache/axiom/");
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

  function test_searchDirs() {
    compare(DataDirs.searchDirs({
      "HOME": "/home/u"
    }), ["/home/u/.local/share", "/usr/local/share", "/usr/share"], "the spec's defaults");
    compare(DataDirs.searchDirs({
      "HOME": "/home/u",
      "XDG_DATA_HOME": "/data",
      "XDG_DATA_DIRS": "/run/current-system/sw/share/:relative::/nix/profile/share:/data"
    }), ["/data", "/run/current-system/sw/share", "/nix/profile/share"], "in order, relative and empty entries and repeats dropped");
    compare(DataDirs.searchDirs({
      "HOME": "/home/u",
      "XDG_DATA_DIRS": "relative"
    }).slice(1), ["/usr/local/share", "/usr/share"], "nothing usable is the same as unset");
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
      "generatedThemes": "/repo/config/themes/generated/",
      "communityThemes": "/home/u/.local/share/axiom/themes/",
      "cache": "/home/u/.cache/axiom/"
    }, "state and data were already XDG");
    compare(DataDirs.legacy(env, "/repo/").config, "/repo/config/user/", "with or without a trailing slash");
  }
}
