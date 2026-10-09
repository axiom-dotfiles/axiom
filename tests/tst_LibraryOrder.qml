import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "LibraryOrder"

  readonly property var types: [
    {
      "type": "Volume",
      "label": "Volume",
      "group": "Media"
    },
    {
      "type": "Clock",
      "label": "Clock",
      "group": "Time"
    },
    {
      "type": "Mystery",
      "label": "Mystery"
    },
    {
      "type": "Media",
      "label": "Media Player",
      "group": "Media"
    },
    {
      "type": "Agenda",
      "label": "Agenda",
      "group": "Time"
    }
  ]

  function label(type) {
    return type.label;
  }

  function names(list) {
    return list.map(type => type.type);
  }

  function test_sorted_by_label() {
    compare(names(LibraryOrder.sorted(types, label)), ["Agenda", "Clock", "Media", "Mystery", "Volume"]);
  }

  function test_sorted_by_shown_label() {
    // Sorted by what labelOf gives (a translation), not the type
    const shown = {
      "Agenda": "Zeitplan",
      "Clock": "Uhr"
    };
    compare(names(LibraryOrder.sorted(types.filter(t => t.group === "Time"), t => shown[t.type])), ["Clock", "Agenda"]);
  }

  function test_sorted_leaves_input_alone() {
    const input = types.slice();
    LibraryOrder.sorted(input, label);
    compare(names(input), names(types));
  }

  function test_grouped_in_group_order() {
    const sections = LibraryOrder.grouped(types, ["Time", "Empty", "Media"], label);
    compare(sections.map(s => s.name), ["Time", "Media", ""]);
    compare(names(sections[0].types), ["Agenda", "Clock"]);
    compare(names(sections[1].types), ["Media", "Volume"]);
    compare(names(sections[2].types), ["Mystery"]);
  }

  function test_grouped_unknown_group_goes_last() {
    const sections = LibraryOrder.grouped(types, ["Time"], label);
    compare(sections.map(s => s.name), ["Time", ""]);
    compare(names(sections[1].types), ["Media", "Mystery", "Volume"]);
  }

  function test_sections_flat() {
    const sections = LibraryOrder.sections(types, ["Time", "Media"], label, false);
    compare(sections.length, 1);
    compare(sections[0].name, "");
    compare(names(sections[0].types), ["Agenda", "Clock", "Media", "Mystery", "Volume"]);
  }

  function test_sections_empty() {
    compare(LibraryOrder.sections([], ["Time"], label, false), []);
    compare(LibraryOrder.sections([], ["Time"], label, true), []);
  }
}
