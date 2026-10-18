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

  function test_runs() {
    compare(ColumnSplit.runs([]), []);
    compare(ColumnSplit.runs([false, false, true, false, false]).map(run => [run.from, run.to, run.wide]), [[0, 2, false], [2, 3, true], [3, 5, false]]);
    compare(ColumnSplit.runs([false]).map(run => run.wide), [true], "a lone card takes the whole width");
    compare(ColumnSplit.runs([true, false, true]).map(run => run.wide), [true, true, true], "so does one alone between wide ones");
  }

  function test_place_all_narrow() {
    const wide = [false, false, false, false];
    const splits = ColumnSplit.splits([40, 60, 20, 30], wide, 10);
    compare(splits, [ColumnSplit.split([40, 60, 20, 30], 10)]);
    const placed = ColumnSplit.place([40, 60, 20, 30], wide, [2], 10);
    compare(placed.cards, [
      {
        "column": 0,
        "y": 0
      },
      {
        "column": 0,
        "y": 50
      },
      {
        "column": 1,
        "y": 0
      },
      {
        "column": 1,
        "y": 30
      }
    ]);
    compare(placed.height, ColumnSplit.height([40, 60, 20, 30], 2, 10));
  }

  function test_place_wide() {
    // wide, then two narrow side by side, then wide
    const wide = [true, false, false, true];
    compare(ColumnSplit.splits([100, 50, 70, 30], wide, 10), [1, 1, 1]);
    const placed = ColumnSplit.place([100, 50, 70, 30], wide, [1, 1, 1], 10);
    compare(placed.cards.map(card => [card.column, card.y]), [[-1, 0], [0, 110], [1, 110], [-1, 190]], "a wide card starts below the taller column");
    compare(placed.height, 220);
  }

  function test_place_lone() {
    const placed = ColumnSplit.place([100, 40, 60], [true, false, true], [1, 1, 1], 10);
    compare(placed.cards.map(card => [card.column, card.y]), [[-1, 0], [-1, 110], [-1, 160]]);
    compare(ColumnSplit.place([80], [false], [1], 10).cards[0].column, -1, "a lone card takes the whole width");
    compare(ColumnSplit.place([], [], [], 10).height, 0);
  }
}
