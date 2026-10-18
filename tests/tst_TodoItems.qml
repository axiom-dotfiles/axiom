import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "TodoItems"

  function list() {
    let items = [];
    items = TodoItems.add(items, "  Write tests ", 100, "a");
    items = TodoItems.add(items, "Ship it", 200, "b");
    items = TodoItems.add(items, "Celebrate", 300, "c");
    return items;
  }

  function test_add() {
    const items = list();
    compare(items.map(i => [i.uid, i.summary, i.order, i.created]), [["a", "Write tests", 0, 100], ["b", "Ship it", 1, 200], ["c", "Celebrate", 2, 300]]);
    compare(TodoItems.add(items, "   ", 400, "d"), items, "an empty summary adds nothing");
    compare(TodoItems.openCount(items), 3);
  }

  function test_toggle() {
    const items = TodoItems.toggle(list(), "b", 500);
    compare(TodoItems.find(items, "b").done, true);
    compare(TodoItems.find(items, "b").completed, 500);
    compare(TodoItems.openCount(items), 2);
    // Setting done again keeps when it was finished
    compare(TodoItems.find(TodoItems.toggle(items, "b", 900, true), "b").completed, 500);
    const reopened = TodoItems.toggle(items, "b", 600);
    compare([TodoItems.find(reopened, "b").done, TodoItems.find(reopened, "b").completed], [false, 0]);
  }

  // Nothing changing hands back the same list, so the manager writes nothing
  function test_no_change_is_the_same_list() {
    const items = TodoItems.toggle(list(), "b", 500);
    verify(TodoItems.toggle(items, "b", 900, true) === items, "already done");
    verify(TodoItems.toggle(items, "zz", 900) === items, "unknown uid");
    verify(TodoItems.rename(items, "a", TodoItems.find(items, "a").summary) === items, "same summary");
    verify(TodoItems.rename(items, "zz", "x") === items, "rename unknown");
    verify(TodoItems.remove(items, "zz") === items, "remove unknown");
    const open = list();
    verify(TodoItems.clearCompleted(open) === open, "nothing done");
  }

  function test_rename_remove_move() {
    let items = TodoItems.rename(list(), "a", " Write more tests ");
    compare(TodoItems.find(items, "a").summary, "Write more tests");
    compare(TodoItems.rename(items, "a", ""), items, "an empty summary keeps the old one");
    items = TodoItems.remove(items, "a");
    compare(items.map(i => [i.uid, i.order]), [["b", 0], ["c", 1]]);
    items = TodoItems.move(list(), "c", 0);
    compare(items.map(i => i.uid), ["c", "a", "b"]);
    compare(TodoItems.move(list(), "a", 99).map(i => i.uid), ["b", "c", "a"], "clamped");
    compare(items.map(i => i.order), [0, 1, 2]);
  }

  function test_shown_and_clear() {
    let items = TodoItems.toggle(list(), "a", 500);
    items = TodoItems.toggle(items, "c", 700);
    compare(TodoItems.shown(items, false).map(i => i.uid), ["b"]);
    compare(TodoItems.shown(items, true).map(i => i.uid), ["b", "c", "a"], "the last finished first");
    compare(TodoItems.clearCompleted(items).map(i => [i.uid, i.order]), [["b", 0]]);
  }

  function test_normalize() {
    const items = TodoItems.normalize([
      {
        "uid": "x",
        "summary": " Later ",
        "order": 5,
        "done": true,
        "completed": 10
      },
      {
        "uid": "y",
        "summary": "First",
        "order": 1,
        "completed": 20
      },
      {
        "uid": "x",
        "summary": "Duplicate"
      },
      {
        "summary": "No uid"
      },
      {
        "uid": "z",
        "summary": "   "
      },
      "junk"]);
    compare(items, [
      {
        "uid": "y",
        "summary": "First",
        "done": false,
        "created": 0,
        "completed": 0,
        "due": 0,
        "order": 0
      },
      {
        "uid": "x",
        "summary": "Later",
        "done": true,
        "created": 0,
        "completed": 10,
        "due": 0,
        "order": 1
      }
    ]);
    compare(TodoItems.normalize(null), []);
  }
}
