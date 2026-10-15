import QtQuick
import QtTest
import qs.components.methods

// HyprReply: when a reply on Hyprland's request socket is complete, and
// splitting a batch's replies.
TestCase {
  name: "HyprReply"

  function test_batch() {
    compare(HyprReply.batch(["j/getoption general:gaps_out", "j/animations"]), "[[BATCH]]j/getoption general:gaps_out;j/animations");
  }

  function test_jsonCompleteOnceItParses() {
    verify(!HyprReply.complete("j/clients", ""));
    verify(!HyprReply.complete("j/clients", "[{\"address\": \"0x1\""), "a piece of a long reply");
    verify(HyprReply.complete("j/clients", "[{\"address\": \"0x1\"}]"));
  }

  function test_textCompleteOnceThere() {
    verify(!HyprReply.complete("eval x = 1", ""));
    verify(HyprReply.complete("eval x = 1", "ok"));
    verify(HyprReply.complete("eval error('x')", "error: [string \"return error('x');\"]:1: x"));
  }

  function test_batchCompleteWithItsLastReply() {
    const request = HyprReply.batch(["j/getoption a", "j/getoption b"]);
    verify(!HyprReply.complete(request, "{\"int\": 1}"), "one of two replies");
    verify(!HyprReply.complete(request, "{\"int\": 1}\n\n\n{\"int\""), "the last one cut off");
    verify(HyprReply.complete(request, "{\"int\": 1}\n\n\n{\"int\": 2}"));
  }

  function test_splitBatch() {
    compare(HyprReply.splitBatch("a\n\n\nb", 3), ["a", "b", ""], "a missing reply is empty");
  }

  function test_parse() {
    compare(HyprReply.parse("{\"x\": 1}"), {
      "x": 1
    });
    compare(HyprReply.parse("error: no such option"), null);
  }
}
