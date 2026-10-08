import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "TimeZones"

  function test_parseOffset() {
    compare(TimeZones.parseOffset("+0900"), 540);
    compare(TimeZones.parseOffset("-0500"), -300);
    compare(TimeZones.parseOffset("+0530"), 330);
    compare(TimeZones.parseOffset("-09:30"), -570);
    compare(TimeZones.parseOffset("+0000"), 0);
    compare(TimeZones.parseOffset(" +1345\n"), 825, "date's output, trimmed");
    compare(TimeZones.parseOffset("UTC"), null);
    compare(TimeZones.parseOffset(""), null);
    compare(TimeZones.parseOffset(undefined), null);
  }

  // Whatever zone the test runs in, the shifted Date's local fields are
  // the zone's wall clock
  function test_shift() {
    const date = new Date(Date.UTC(2026, 0, 31, 20, 15, 30));
    const tokyo = TimeZones.shift(date, 540);
    compare(tokyo.getHours(), 5);
    compare(tokyo.getMinutes(), 15);
    compare(tokyo.getSeconds(), 30);
    compare(tokyo.getDate(), 1, "past midnight there: the next day");
    compare(tokyo.getMonth(), 1);
    const newYork = TimeZones.shift(date, -300);
    compare(newYork.getHours(), 15);
    compare(newYork.getDate(), 31);
    const india = TimeZones.shift(date, 330);
    compare(india.getHours(), 1);
    compare(india.getMinutes(), 45);
  }

  function test_shift_without_an_offset() {
    const date = new Date(2026, 5, 1, 12, 0);
    compare(TimeZones.shift(date, null), date);
    compare(TimeZones.shift(date, undefined), date);
  }

  function test_msToNextCheck() {
    compare(TimeZones.msToNextCheck(new Date(Date.UTC(2026, 0, 1, 10, 0, 0))), 30 * 60000 + 2000, "on the half hour: the next one");
    compare(TimeZones.msToNextCheck(new Date(Date.UTC(2026, 0, 1, 10, 29, 0))), 60000 + 2000);
    compare(TimeZones.msToNextCheck(new Date(Date.UTC(2026, 0, 1, 10, 45, 0))), 15 * 60000 + 2000);
  }
}
