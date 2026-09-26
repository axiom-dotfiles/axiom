import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "Utils"

  function test_visualWidth_counts_wide_chars_twice() {
    compare(Utils.visualWidth("abc"), 3);
    compare(Utils.visualWidth("日本"), 4);
    compare(Utils.visualWidth("😀"), 1);
  }

  function test_truncate() {
    compare(Utils.truncate("short", 10), "short");
    compare(Utils.truncate("abcdefgh", 6), "abc...");
    compare(Utils.truncate("日本語テキスト", 7, "…"), "日本語…");
  }

  function test_contrast() {
    verify(Utils.isColorDark("#101010"));
    verify(!Utils.isColorDark("#f0f0f0"));
    compare(Utils.getContrastColor("#000000"), "#FFFFFF");
    compare(Utils.getContrastColor("#ffffff"), "#000000");
  }

  function test_monthGrid() {
    // September 2026 starts on a Tuesday
    const sunday = Utils.monthGrid(2026, 8, 0, new Date(2026, 8, 26).toDateString());
    compare(sunday.length, 42);
    compare([sunday[0].day, sunday[0].month, sunday[0].inMonth], [30, 7, false]);
    compare([sunday[2].day, sunday[2].inMonth], [1, true]);
    compare(sunday.filter(d => d.isToday).map(d => d.day), [26]);
    const monday = Utils.monthGrid(2026, 8, 1, "");
    compare(monday[1].day, 1);
    // A month starting on the first day starts the grid
    compare(Utils.monthGrid(2026, 1, 0, "")[0].day, 1);
  }
}
