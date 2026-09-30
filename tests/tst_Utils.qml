import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "Utils"

  function test_clone() {
    const original = {
      "a": [1,
        {
          "b": 2
        }
      ]
    };
    const copy = Utils.clone(original);
    compare(copy, original);
    copy.a[1].b = 3;
    compare(original.a[1].b, 2);
    compare(Utils.clone(undefined), null);
  }

  function test_recordUse() {
    const first = Utils.recordUse({}, "x", 100);
    compare(first, {
      "x": {
        "count": 1,
        "last": 100
      }
    });
    const second = Utils.recordUse(first, "x", 200);
    compare(second.x, {
      "count": 2,
      "last": 200
    });
    // A new object; the old one is untouched
    compare(first.x.count, 1);
    compare(Utils.recordUse(null, "y", 5).y.count, 1);
  }

  function test_curlConfigValue() {
    compare(Utils.curlConfigValue("plain"), "\"plain\"");
    compare(Utils.curlConfigValue("a\"b\\c"), "\"a\\\"b\\\\c\"");
    compare(Utils.curlConfigValue("line\nurl = evil"), "\"line\\nurl = evil\"");
    compare(Utils.curlConfigValue("cr\r"), "\"cr\\r\"");
  }

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

  function test_rates() {
    compare(Utils.rateParts(0), [0, "B/s"]);
    compare(Utils.rateParts(900), [900, "B/s"]);
    compare(Utils.rateParts(1536), [1.5, "KB/s"]);
    compare(Utils.rateParts(512 * 1024), [512, "KB/s"]);
    compare(Utils.rateParts(3 * 1024 * 1024 * 1024 * 1024), [3072, "GB/s"]);
    compare(Utils.formatRate(1.5 * 1024 * 1024), "1.5 MB/s");
    compare(Utils.formatRate(undefined), "0 B/s");
  }

  function test_formatSize() {
    compare(Utils.formatSize(512 * Utils.bytesPerGiB), "512G");
    compare(Utils.formatSize(1843 * Utils.bytesPerGiB), "1.8T");
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
