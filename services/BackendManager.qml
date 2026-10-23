pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.components.methods

// The shell's connection to the axiom binary, its parent (`axiom run`,
// docs/dev/backend/README.md): JSON-RPC over the socket the binary names
// in $AXIOM_SOCKET. It says hello (the protocol and the schema read),
// relays what the binary pushes (notified), sends calls (queued until the
// hello is answered) and answers the binary's own calls (handle). It
// reconnects when the binary re-execs. Below every other service: it
// reads the environment only, so ConfigManager can stand on it.
// Started without $AXIOM_SOCKET (the shell run by hand, not by axiom), it
// stays inactive.
QtObject {
  id: root

  readonly property string socketPath: Quickshell.env("AXIOM_SOCKET") ?? ""
  readonly property bool active: socketPath !== ""
  // Connected and greeted: calls go out at once
  readonly property bool ready: _hello !== null
  // The binary's daemon.hello answer ({ protocol, version, schemaHash,
  // state, dirs, compatible, reason, … }), null until it came
  readonly property var hello: _hello
  // Set by the binary when it was built for other shell files: config
  // stays read-only and a notice says why
  readonly property string incompatible: Quickshell.env("AXIOM_INCOMPATIBLE") ?? ""

  // A hello was answered (after the first connect and every reconnect)
  signal greeted

  // Calls fn(params) whenever the binary pushes method (config.changed,
  // config.state, schema.changed, …). Not a signal: a parsed object passed
  // through one comes back with its arrays as Qt lists (Array.isArray false)
  function listen(method, fn) {
    const list = root._listeners[method] ?? [];
    list.push(fn);
    root._listeners[method] = list;
  }

  // Calls method; done(error, result) with error null or { kind, message,
  // issues }. Waits for the hello when not connected yet.
  function call(method, params, done) {
    if (!root.active) {
      done?.({
        "kind": "unavailable",
        "message": "axiom isn't running this shell"
      }, null);
      return;
    }
    const id = root._nextId++;
    root._pending[id] = done ?? null;
    const line = JsonRpc.request(id, method, params);
    if (root.ready)
      root._send(line);
    else
      root._queue.push(line);
  }

  // Sends a notification (no reply)
  function notify(method, params) {
    if (!root.active)
      return;
    const line = JsonRpc.notification(method, params);
    if (root.ready)
      root._send(line);
    else
      root._queue.push(line);
  }

  // Answers the binary's calls of method with fn(params): a result, or a
  // thrown { kind, message }
  function handle(method, fn) {
    root._handlers[method] = fn;
  }

  property var _hello: null
  property int _nextId: 1
  property var _pending: ({})
  property var _queue: []
  property var _handlers: ({
      "ipc.call": params => root._callTarget(params)
    })
  property var _listeners: ({})
  // The shell's IPC targets (IpcTarget), several per name where each
  // screen has its own and only the enabled one answers
  property var _targets: []

  // IpcTarget's registration: the names go to axiom (which reads their
  // functions from `qs ipc show`), calls come back as ipc.call
  function addTarget(target) {
    root._targets.push(target);
    targetsChanged();
  }

  function removeTarget(target) {
    root._targets = root._targets.filter(t => t !== target);
    targetsChanged();
  }

  function targetsChanged() {
    if (root.active && !root._registerQueued) {
      root._registerQueued = true;
      Qt.callLater(root._register);
    }
  }

  property bool _registerQueued: false

  function _register() {
    root._registerQueued = false;
    const names = root._targets.filter(t => t.enabled).map(t => t.target);
    root.call("ipc.register", {
      "targets": names.filter((n, i) => names.indexOf(n) === i).map(name => ({
            "name": name,
            "enabled": true
          }))
    }, null);
  }

  function _callTarget(params) {
    const target = root._targets.find(t => t.target === params.target && t.enabled);
    if (!target)
      throw {
        "kind": "not_found",
        "message": "no enabled target " + params.target
      };
    const fn = target[params.function];
    if (typeof fn !== "function")
      throw {
        "kind": "not_found",
        "message": params.target + " has no function " + params.function
      };
    const result = fn.apply(target, params.args ?? []);
    return result === undefined ? null : result;
  }
  property int _retry: 0

  readonly property int _protocol: {
    const text = FileManager.read(Qt.resolvedUrl("../config/json/backend.json"));
    try {
      return JSON.parse(text).protocol;
    } catch (e) {
      return 0;
    }
  }
  // The schema's identity, as the binary built it: the shell read this file
  readonly property string _schemaHash: {
    const path = Quickshell.env("AXIOM_SCHEMA") ?? "";
    const text = path ? FileManager.read("file://" + path) : null;
    return text ? Qt.md5(text) : "";
  }

  function _send(line) {
    _socket.write(line);
    _socket.flush();
  }

  function _greet() {
    const id = root._nextId++;
    root._pending[id] = (error, result) => {
      if (error) {
        console.error("[BackendManager] axiom refused the hello:", error.message);
        return;
      }
      root._retry = 0;
      root._hello = result;
      const queued = root._queue;
      root._queue = [];
      queued.forEach(line => root._send(line));
      // A new connection: axiom knows nothing of the targets yet
      root._register();
      root.greeted();
    };
    root._send(JsonRpc.request(id, "daemon.hello", {
      "protocol": root._protocol,
      "client": "shell",
      "schemaHash": root._schemaHash,
      "subscribe": true,
      "pid": Quickshell.processId
    }));
  }

  function _onLine(line) {
    const m = JsonRpc.parse(line);
    switch (m.kind) {
    case "response":
      {
        const done = root._pending[m.id];
        delete root._pending[m.id];
        done?.(m.error ?? null, m.error ? null : m.result);
        break;
      }
    case "notification":
      (root._listeners[m.method] ?? []).forEach(fn => fn(m.params ?? {}));
      break;
    case "request":
      root._answer(m);
      break;
    default:
      console.warn("[BackendManager] unreadable message from axiom:", m.reason);
    }
  }

  function _answer(m) {
    const fn = root._handlers[m.method];
    if (!fn) {
      root._send(JsonRpc.error(m.id, "not_found", "the shell has no " + m.method));
      return;
    }
    try {
      root._send(JsonRpc.result(m.id, fn(m.params ?? {})));
    } catch (e) {
      root._send(JsonRpc.error(m.id, e?.kind ?? "internal", String(e?.message ?? e)));
    }
  }

  // Calls in flight when the connection went fail; the hello is said again
  function _dropped() {
    root._hello = null;
    const pending = root._pending;
    root._pending = {};
    for (const id in pending) {
      // Through a const: V4 crashes compiling an optional call on a
      // computed member (docs/dev/core/qml-pitfalls.md)
      const done = pending[id];
      if (done)
        done({
          "kind": "unavailable",
          "message": "the connection to axiom closed"
        }, null);
    }
    if (root.active)
      _reconnect.start();
  }

  property Socket _socket: Socket {
    path: root.socketPath
    connected: root.active
    parser: SplitParser {
      onRead: line => root._onLine(line)
    }
    onConnectionStateChanged: {
      if (connected)
        root._greet();
      else
        root._dropped();
    }
    onError: error => {
      if (!connected && root.active)
        _reconnect.start();
    }
  }

  // A re-exec or restart of the binary: try again, a little slower each
  // time, up to every 5 s
  property Timer _reconnect: Timer {
    interval: Math.min(5000, 200 * Math.pow(2, root._retry))
    onTriggered: {
      root._retry++;
      root._socket.connected = true;
    }
  }
}
