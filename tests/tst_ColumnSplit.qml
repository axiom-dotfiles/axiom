import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "ColumnSplit"

  function test_empty() {
    compare(ColumnSplit.split([], 10), 0);
    compare(ColumnSplit.tops([], 0, 10), []);
    compare(ColumnSplit.height([], 0, 10), 0);
  }

  function test_one() {
    compare(ColumnSplit.split([100], 10), 1, "a lone card goes left");
    compare(ColumnSplit.height([100], 1, 10), 100);
  }

  function test_equal() {
    compare(ColumnSplit.split([50, 50], 10), 1);
    compare(ColumnSplit.split([50, 50, 50, 50], 10), 2);
    compare(ColumnSplit.split([50, 50, 50], 10), 2, "a tie leaves the left column fuller");
  }

  function test_huge() {
    compare(ColumnSplit.split([500, 50, 50, 50], 10), 1, "a huge first card has the left column to itself");
    compare(ColumnSplit.split([50, 50, 50, 500], 10), 3, "a huge last card has the right column to itself");
  }

  function test_gap() {
    // Without gaps 60 | 30 + 30 would tie; with them the right column is
    // 70, so both on the left (130) loses to 60 | 70
    compare(ColumnSplit.split([60, 30, 30], 10), 1);
    compare(ColumnSplit.height([60, 30, 30], 1, 10), 70);
  }

  function test_tops() {
    compare(ColumnSplit.tops([40, 60, 20, 30], 2, 10), [0, 50, 0, 30]);
    compare(ColumnSplit.tops([40, 60], 0, 10), [0, 50], "all on the right");
    compare(ColumnSplit.height([40, 60, 20, 30], 2, 10), 110);
  }
}
