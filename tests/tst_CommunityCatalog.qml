import QtQuick
import QtTest
import qs.components.methods

// CommunityCatalog: reading the community setups' index.json (as
// scripts/build_index.py in community-setups writes it), searching it.
TestCase {
  name: "CommunityCatalog"

  readonly property string sha: "a".repeat(64)

  function file(id, name) {
    return {
      "path": "setups/" + id + "/" + name,
      "sha256": sha,
      "size": 10
    };
  }

  function entry(id, extra) {
    return Object.assign({
      "id": id,
      "title": "T " + id,
      "author": "someone",
      "description": "d",
      "tags": ["dark"],
      "tested": ["hyprland"],
      "fonts": ["Inter"],
      "theme": "dracula",
      "configVersion": 60,
      "files": {
        "config": file(id, "config.json"),
        "screenshot": file(id, "screenshot.png"),
        "thumb": file(id, "thumb.webp")
      }
    }, extra ?? {});
  }

  function index(setups) {
    return {
      "format": 1,
      "setups": setups
    };
  }

  function test_parse_reads_a_good_entry() {
    const setups = CommunityCatalog.parse(index([entry("glass")]), 69);
    compare(setups.length, 1);
    compare(setups[0].id, "glass");
    compare(setups[0].compatible, true);
    compare(setups[0].wallpaper, null);
    compare(setups[0].files.config.path, "setups/glass/config.json");
  }

  function test_parse_refuses_other_formats() {
    compare(CommunityCatalog.parse({
      "format": 2,
      "setups": []
    }, 69), null);
    compare(CommunityCatalog.parse([], 69), null);
    compare(CommunityCatalog.parse(null, 69), null);
  }

  function test_parse_marks_newer_configs_incompatible() {
    compare(CommunityCatalog.parse(index([entry("new", {
        "configVersion": 70
      })]), 69)[0].compatible, false);
  }

  function test_parse_drops_malformed_entries() {
    const bad = [entry("Bad_Id"), entry("../up"), entry("nover", {
        "configVersion": "60"
      }), entry("escape", {
        "files": {
          "config": file("other", "config.json"),
          "screenshot": file("escape", "screenshot.png"),
          "thumb": file("escape", "thumb.webp")
        }
      }), entry("dots", {
        "files": {
          "config": file("dots", "../../x.json"),
          "screenshot": file("dots", "screenshot.png"),
          "thumb": file("dots", "thumb.webp")
        }
      }), entry("hash", {
        "files": {
          "config": {
            "path": "setups/hash/config.json",
            "sha256": "nothex"
          },
          "screenshot": file("hash", "screenshot.png"),
          "thumb": file("hash", "thumb.webp")
        }
      }), entry("nothumb", {
        "files": {
          "config": file("nothumb", "config.json"),
          "screenshot": file("nothumb", "screenshot.png")
        }
      }), entry("badtheme", {
        "files": {
          "config": file("badtheme", "config.json"),
          "screenshot": file("badtheme", "screenshot.png"),
          "thumb": file("badtheme", "thumb.webp"),
          "theme": {
            "path": "/etc/passwd",
            "sha256": sha
          }
        }
      })];
    compare(CommunityCatalog.parse(index(bad.concat([entry("good"), entry("good")])), 69).map(s => s.id), ["good"], "only the well-formed one, once");
  }

  function test_parse_keeps_extra_files_and_wallpaper() {
    const withWall = entry("wall", {
      "wallpaper": {
        "license": "CC0-1.0",
        "source": "own"
      },
      "files": {
        "config": file("wall", "config.json"),
        "screenshot": file("wall", "screenshot.png"),
        "thumb": file("wall", "thumb.webp"),
        "wallpaper": file("wall", "wallpaper.jpg"),
        "theme": file("wall", "theme.json")
      }
    });
    const setup = CommunityCatalog.parse(index([withWall]), 69)[0];
    compare(setup.wallpaper.license, "CC0-1.0");
    compare(setup.files.theme.path, "setups/wall/theme.json");
    compare(CommunityCatalog.extension(setup.files.wallpaper), ".jpg");
  }

  function test_parse_filters_fields() {
    const setup = CommunityCatalog.parse(index([entry("f", {
        "tested": ["hyprland", "kwin", 3],
        "page": "javascript:alert(1)"
      })]), 69)[0];
    compare(setup.tested, ["hyprland"]);
    compare(setup.page, "");
  }

  function test_file_url() {
    compare(CommunityCatalog.fileUrl("https://raw.example/catalog/index.json", file("a", "thumb.webp")), "https://raw.example/catalog/setups/a/thumb.webp");
  }

  function test_search() {
    const setups = CommunityCatalog.parse(index([entry("glass", {
        "title": "Glass Harbor",
        "tags": ["dark", "glass"]
      }), entry("paper", {
        "title": "Paper",
        "description": "light and glassy",
        "tags": ["light"]
      })]), 69);
    compare(CommunityCatalog.search(setups, "", []).map(s => s.id), ["glass", "paper"], "nothing typed: all, in order");
    compare(CommunityCatalog.search(setups, "glass", []).map(s => s.id), ["glass", "paper"], "the title's match first");
    compare(CommunityCatalog.search(setups, "glass harbor", []).map(s => s.id), ["glass"], "every word must match");
    compare(CommunityCatalog.search(setups, "", ["light"]).map(s => s.id), ["paper"], "by tag");
    compare(CommunityCatalog.search(setups, "zzz", []), []);
  }

  function test_tags_and_fonts() {
    const setups = CommunityCatalog.parse(index([entry("a", {
        "tags": ["dark", "glass"]
      }), entry("b", {
        "tags": ["dark", "pills"]
      })]), 69);
    compare(CommunityCatalog.tags(setups), ["dark", "glass", "pills"]);
    compare(CommunityCatalog.missingFonts(setups[0], ["inter", "Noto Sans"]), []);
    compare(CommunityCatalog.missingFonts(setups[0], ["Noto Sans"]), ["Inter"]);
    compare(CommunityCatalog.themeName("a"), "community/a");
  }
}
