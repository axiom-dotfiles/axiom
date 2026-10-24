import QtQuick
import QtTest

// Replays the shared fixtures (tests/fixtures/shared/, listed in its
// index.json) through the JS helpers: each case's output must be its
// expected file byte for byte. The axiom binary's tests replay the same
// cases (docs/dev/backend/README.md › Shared fixtures).
TestCase {
  id: test
  name: "Shared"

  RepoFiles {
    id: files
  }

  Shared {
    id: shared
    testCase: test
  }

  readonly property string dir: "tests/fixtures/shared/"

  function test_cases() {
    if (shared.recording)
      skip("recording");
    const index = files.json(dir + "index.json");
    verify(index.cases.length > 0, "no cases in index.json");
    let replayed = 0;
    const failures = [];
    for (const name of index.cases) {
      const spec = files.json(dir + name + ".json");
      // Ops whose JS side is gone (or never existed) are Go's alone
      if (shared.ops[spec.op] === undefined)
        continue;
      const expected = files.text(dir + name + ".expected.json");
      const actual = shared.canonical(shared.ops[spec.op](shared.resolveArgs(spec.args)));
      replayed++;
      if (actual !== expected)
        failures.push(name + ": " + firstDifference(actual, expected));
    }
    compare(failures, [], failures.length + " of " + replayed + " cases differ");
  }

  // Where two texts first differ, as line numbers and both lines
  function firstDifference(actual, expected) {
    const a = actual.split("\n");
    const e = expected.split("\n");
    for (let i = 0; i < Math.max(a.length, e.length); i++) {
      if (a[i] !== e[i])
        return "line " + (i + 1) + ": got " + JSON.stringify(a[i]) + ", want " + JSON.stringify(e[i]);
    }
    return "differs";
  }
}
