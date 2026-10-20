import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "KeybindFilter"

  function row(label, mods, keys, axiom) {
    return {
      "label": label,
      "combos": [
        {
          "mods": mods,
          "keys": keys
        }
      ],
      "axiom": axiom,
      "user": !axiom
    };
  }

  readonly property var sections: [
    {
      "title": "Apps",
      "undescribed": false,
      "binds": [row("Terminal", ["SUPER"], ["Return"], true), row("Browser", ["SUPER", "SHIFT"], ["B"], false)]
    },
    {
      "title": "Window",
      "undescribed": false,
      "binds": [row("Close", ["SUPER"], ["Q"], false), row("Float", ["SUPER", "SHIFT"], ["F"], true)]
    },
    {
      "title": "",
      "undescribed": false,
      "binds": [row("Lock", ["SUPER"], ["L"], false)]
    },
    {
      "title": "",
      "undescribed": true,
      "binds": [row("", ["ALT"], ["Tab"], false)]
    }
  ]

  function labels(result) {
    return result.map(section => section.title + ":" + section.binds.map(bind => bind.label).join(","));
  }

  function test_no_filter_keeps_everything() {
    const result = KeybindFilter.filter(sections, "", {});
    compare(result.length, 4);
    verify(result[0] === sections[0], "untouched sections are passed through");
  }

  function test_section_keys_tell_other_from_undescribed() {
    compare(KeybindFilter.sectionKey(sections[2]), "");
    verify(KeybindFilter.sectionKey(sections[3]) !== "");
    compare(labels(KeybindFilter.filter(sections, "", {
      "sections": [""]
    })), [":Lock"]);
  }

  function test_chips_in_a_group_are_alternatives() {
    compare(labels(KeybindFilter.filter(sections, "", {
      "sections": ["Apps", "Window"]
    })), ["Apps:Terminal,Browser", "Window:Close,Float"]);
    compare(labels(KeybindFilter.filter(sections, "", {
      "sources": ["axiom", "user"]
    })).length, 4);
  }

  function test_mods_need_every_selected_modifier() {
    compare(labels(KeybindFilter.filter(sections, "", {
      "mods": ["SUPER", "SHIFT"]
    })), ["Apps:Browser", "Window:Float"]);
  }

  function test_groups_and_query_all_apply() {
    compare(labels(KeybindFilter.filter(sections, "", {
      "sections": ["Apps", "Window"],
      "mods": ["SHIFT"],
      "sources": ["axiom"]
    })), ["Window:Float"]);
    compare(labels(KeybindFilter.filter(sections, "q", {
      "sources": ["user"]
    })), ["Window:Close"]);
  }

  function test_title_match_keeps_rows_that_pass_chips() {
    compare(labels(KeybindFilter.filter(sections, "WIND", {})), ["Window:Close,Float"]);
    compare(labels(KeybindFilter.filter(sections, "wind", {
      "sources": ["axiom"]
    })), ["Window:Float"]);
  }

  function test_empty_sections_are_dropped() {
    compare(KeybindFilter.filter(sections, "nothing matches", {}).length, 0);
    compare(labels(KeybindFilter.filter(sections, "", {
      "mods": ["ALT"]
    })), [":"]);
  }

  function test_columns() {
    const section = (title, rows) => ({
          "title": title,
          "binds": new Array(rows).fill({
            "label": "x",
            "combos": []
          })
        });
    const cols = KeybindFilter.columns([section("A", 6), section("B", 2), section("C", 2), section("D", 1)], 2);
    compare(cols.length, 2);
    compare(cols[0].map(s => s.title), ["A"]);
    compare(cols[1].map(s => s.title), ["B", "C", "D"], "the shorter column takes each next section");
    compare(KeybindFilter.columns([], 3).length, 3);
    compare(KeybindFilter.columns([section("A", 1)], 0).length, 1, "at least one column");
    // Each modifier group's header counts a row: A is 1.5 + 2 rows + 2
    // headers = 5.5, B (1.5 + 5 rows, no modifiers) 6.5, so C goes under A
    const grouped = {
      "title": "A",
      "binds": [row("Terminal", ["SUPER"], ["Return"], true), row("Browser", ["SUPER", "SHIFT"], ["B"], true)]
    };
    const cols2 = KeybindFilter.columns([grouped, section("B", 5), section("C", 1)], 2);
    compare(cols2[1].map(s => s.title), ["B"]);
    compare(cols2[0].map(s => s.title), ["A", "C"]);
  }

  function test_ids() {
    const withIds = [
      {
        "title": "Apps",
        "undescribed": false,
        "binds": [Object.assign(row("Terminal", ["SUPER"], ["Return"], true), {
            "ids": ["64:return"]
          }), Object.assign(row("Browser", ["SUPER"], ["B"], true), {
            "ids": ["64:b"]
          })]
      }
    ];
    compare(KeybindFilter.filter(withIds, "", {
      "ids": ["64:b"]
    })[0].binds.map(r => r.label), ["Browser"]);
    compare(KeybindFilter.filter(withIds, "", {
      "ids": ["64:q"]
    }).length, 0);
    compare(KeybindFilter.filter(withIds, "", {
      "ids": null
    })[0].binds.length, 2);
  }
}
