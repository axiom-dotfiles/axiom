import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "ChatMarkdown"

  function kinds(text) {
    return ChatMarkdown.segments(text).map(s => s.kind + (s.open ? "(open)" : ""));
  }

  function test_prose_only() {
    const out = ChatMarkdown.segments("\n\nHello *there*\n\n");
    compare(out.length, 1);
    compare(out[0].text, "Hello *there*");
  }

  function test_code_between_prose() {
    const out = ChatMarkdown.segments("Before\n```js\nlet x = 1;\n```\nAfter");
    compare(kinds("Before\n```js\nlet x = 1;\n```\nAfter"), ["md", "code", "md"]);
    compare(out[1].lang, "js");
    compare(out[1].text, "let x = 1;");
  }

  function test_streaming_open_fence() {
    compare(kinds("Text\n```py\nprint(1)"), ["md", "code(open)"]);
    // An open fence with nothing in it yet draws nothing
    compare(kinds("Text\n```py\n"), ["md"]);
  }

  function test_fences_must_match() {
    const out = ChatMarkdown.segments("~~~\n```\nstill code\n~~~");
    compare(out.length, 1);
    compare(out[0].text, "```\nstill code");
    // A longer opening fence needs a closing one at least as long
    compare(kinds("````\n```\n````"), ["code"]);
  }

  function test_markdown_fence_nests() {
    const out = ChatMarkdown.segments("```markdown\n# Title\n```sh\nls\n```\nend\n```");
    compare(out.length, 1);
    compare(out[0].lang, "markdown");
    compare(out[0].text, "# Title\n```sh\nls\n```\nend");
  }

  function test_empty() {
    compare(ChatMarkdown.segments(undefined), []);
    compare(ChatMarkdown.segments("   "), []);
  }
}
