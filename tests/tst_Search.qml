import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "Search"

  function test_score() {
    compare(Search.score("Firefox", "firefox"), 100);
    compare(Search.score("Firefox", "fire"), 80);
    compare(Search.score("Visual Studio Code", "code"), 65, "at a word start");
    compare(Search.score("Thunderbird", "bird"), 50, "inside a word");
    compare(Search.score("Firefox", "ffx"), 22, "letters in order, spread out");
    compare(Search.score("Firefox", "xf"), 0, "letters out of order");
    compare(Search.score("Firefox", "z"), 0, "one letter must match as a substring");
    compare(Search.score("", "a"), 0);
    compare(Search.score("Firefox", ""), 0);
  }

  function test_frecency() {
    const now = Date.UTC(2026, 9, 8);
    const day = 86400000;
    compare(Search.frecency(undefined, now), 0);
    compare(Search.frecency({
      count: 4,
      last: now - day / 2
    }, now), 4);
    compare(Search.frecency({
      count: 10,
      last: now - 3 * day
    }, now), 7);
    compare(Search.frecency({
      count: 10,
      last: now - 10 * day
    }, now), 5);
    compare(Search.frecency({
      count: 10,
      last: now - 90 * day
    }, now), 2.5);
  }

  function test_looksLikeMath() {
    verify(Search.looksLikeMath("2+2"));
    verify(Search.looksLikeMath("(3 × 4) ÷ 2"));
    verify(Search.looksLikeMath("5!"));
    verify(!Search.looksLikeMath("42"), "no operator");
    verify(!Search.looksLikeMath("+-"), "no digit");
    verify(!Search.looksLikeMath("5 km to mi"), "words go through =");
  }
}
