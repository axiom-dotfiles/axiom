import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "StopwatchClock"

  readonly property int minute: 60000

  function test_stopwatch() {
    let s = StopwatchClock.idleStopwatch;
    verify(StopwatchClock.stopwatchIdle(s));
    s = StopwatchClock.startStopwatch(s, 1000);
    compare(StopwatchClock.elapsed(s, 4000), 3000);
    s = StopwatchClock.lap(s, 3000);
    s = StopwatchClock.pauseStopwatch(s, 6000);
    compare(StopwatchClock.elapsed(s, 99000), 5000, "paused time doesn't count");
    compare(StopwatchClock.lap(s, 7000), s, "no laps while paused");
    s = StopwatchClock.startStopwatch(s, 10000);
    s = StopwatchClock.lap(s, 12000);
    compare(StopwatchClock.elapsed(s, 12000), 7000);
    compare(StopwatchClock.lapRows(s), [
      {
        "number": 2,
        "split": 5000,
        "total": 7000
      },
      {
        "number": 1,
        "split": 2000,
        "total": 2000
      }
    ]);
    compare(StopwatchClock.normalizeStopwatch({
      "running": true,
      "startedAt": 0,
      "laps": [5, -1, "x"]
    }), Object.assign({}, StopwatchClock.idleStopwatch, {
      "laps": [5]
    }));
  }

  function test_timer() {
    let t = StopwatchClock.startTimer(StopwatchClock.idleTimer, 5 * minute, 0, "tea");
    compare([t.running, t.endsAt, t.label], [true, 5 * minute, "tea"]);
    compare(StopwatchClock.remaining(t, minute), 4 * minute);
    compare(StopwatchClock.timerProgress(t, minute), 0.2);
    t = StopwatchClock.pauseTimer(t, 2 * minute);
    compare(StopwatchClock.remaining(t, 50 * minute), 3 * minute);
    t = StopwatchClock.addTime(t, minute);
    compare([t.remaining, t.duration], [4 * minute, 6 * minute]);
    t = StopwatchClock.resumeTimer(t, 10 * minute);
    compare(t.endsAt, 14 * minute);
    compare(StopwatchClock.remaining(t, 20 * minute), 0, "never negative");
    t = StopwatchClock.resetTimer(t);
    verify(StopwatchClock.timerIdle(t));
    compare([t.duration, t.label, StopwatchClock.remaining(t, 0)], [6 * minute, "tea", 6 * minute]);
    compare(StopwatchClock.startTimer(t, 0, 0), t, "no duration, no timer");
  }

  function test_parse() {
    const ms = text => StopwatchClock.parse(text).ms;
    compare(ms("5m"), 5 * minute);
    compare(ms("90s"), 90000);
    compare(ms("1h30m"), 90 * minute);
    compare(ms("1h 30m 10s"), 90 * minute + 10000);
    compare(ms("1.5 min"), 90000);
    compare(ms("25"), 25 * minute, "a plain number is minutes");
    compare(ms("1:30"), 90000);
    compare(ms("1:02:03"), 3723000);
    compare(StopwatchClock.parse("10m tea"), {
      "ms": 10 * minute,
      "label": "tea"
    });
    compare(StopwatchClock.parse("3 pasta water"), {
      "ms": 3 * minute,
      "label": "pasta water"
    });
    compare(ms("tea"), 0);
    compare(ms(""), 0);
  }

  function test_format() {
    compare(StopwatchClock.format(65400, false, false), "01:05");
    compare(StopwatchClock.format(65400, true, false), "01:05.4");
    compare(StopwatchClock.format(64100, false, true), "01:05", "a countdown rounds up");
    compare(StopwatchClock.format(3723000, false, false), "1:02:03");
    compare(StopwatchClock.format(-1, false, true), "00:00");
  }
}
