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
}
