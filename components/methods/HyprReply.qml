pragma Singleton
import QtQuick

// Requests and replies on Hyprland's request socket (HyprlandIpcManager),
// which answers one request per connection, in hyprctl's wire format: "j/"
// asks for JSON, "[[BATCH]]a;b" runs several and joins their replies with
// blank lines.
QtObject {
  id: root

  // What separates a batch's replies
  readonly property string batchSeparator: "\n\n\n"

  // The request running `requests` (each as for request()) in one go
  function batch(requests) {
    return "[[BATCH]]" + requests.join(";");
  }

  // The requests a batch runs ([] for a single request)
  function _batched(request) {
    return request.startsWith("[[BATCH]]") ? request.slice(9).split(";") : [];
  }

  // Whether `text` is all of the reply to `request`, so the connection can
  // close without waiting for Hyprland to: a JSON request's (a batch's
  // last) once it parses, any other once there's text. Hyprland writes
  // each reply at once, but a long one may come in pieces.
  function complete(request, text) {
    const batched = _batched(request);
    if (batched.length > 0) {
      const replies = text.split(root.batchSeparator);
      if (replies.length < batched.length)
        return false;
      const last = replies[batched.length - 1];
      return batched[batched.length - 1].startsWith("j/") ? parse(last) !== null : last !== "";
    }
    if (request.startsWith("j/"))
      return parse(text) !== null;
    return text !== "";
  }

  // A batch's replies, one per request (missing ones "")
  function splitBatch(text, count) {
    const replies = text.split(root.batchSeparator);
    const result = [];
    for (let i = 0; i < count; i++)
      result.push(replies[i] ?? "");
    return result;
  }

  // A JSON reply as a value, or null when it isn't JSON (Hyprland's errors
  // are plain text)
  function parse(text) {
    try {
      return JSON.parse(text);
    } catch (e) {
      return null;
    }
  }
}
