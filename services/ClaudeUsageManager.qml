pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Claude plan usage (the numbers Claude Code's /usage shows) for one or more
// Claude Code accounts, each a CLAUDE_CONFIG_DIR. Read from
// api.anthropic.com/api/oauth/usage (undocumented, so parsed defensively)
// with the OAuth token in the dir's .credentials.json. The credentials are
// only ever read: an expired token marks the account `expired`, keeping its
// last numbers, until Claude Code refreshes it (the file is watched).
// The endpoint rate limits hard, so each account is fetched at most once per
// interval (tracked across restarts in $XDG_STATE_HOME/axiom/claude-usage.json)
// and a failure backs off exponentially, honouring Retry-After on a 429.
// Widgets register with acquire(owner, { accounts: [{label, configDir}],
// intervalMinutes }) and drop it with release(owner).
QtObject {
  id: root

  // { <expanded configDir>: { label, dir, org, plan, status, error,
  //   fetchedAt, session, weekly, weeklyOpus, weeklySonnet, extra,
  //   breakdown, retryAt, failures, rateLimited } };
  //   status: pending | ok | expired | error | missing.
  // A window is { percent, resetsAt } or null.
  property var states: ({})
  readonly property bool fetching: _curl.running

  function acquire(owner, request) {
    _registry.acquire(owner, {
      "interval": Math.max(1, request?.intervalMinutes ?? 5) * 60000,
      "accounts": (request?.accounts ?? []).filter(a => a?.configDir).map(a => ({
            "label": a.label ?? "",
            "dir": root.expand(a.configDir)
          }))
    });
  }

  function release(owner) {
    _registry.release(owner);
  }

  // Refetches every account now, except those still rate limited
  function refresh() {
    const now = Date.now();
    root._dirs.filter(dir => !(root.states[dir]?.rateLimited && now < root.states[dir].retryAt)).forEach(dir => root._enqueue(dir));
  }

  function stateFor(configDir) {
    return root.states[root.expand(configDir)] ?? null;
  }

  // "~/.claude-team/" -> "/home/<user>/.claude-team"
  function expand(dir) {
    return String(dir ?? "").trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/\/+$/, "");
  }

  // -- Private --
  property ConsumerRegistry _registry: ConsumerRegistry {}
  readonly property var _requests: _registry.requests
  readonly property bool _active: _registry.active
  readonly property int _interval: _active ? Math.min(..._requests.map(r => r.interval)) : 300000

  // The union of every requested dir, as a string so the watchers below only
  // rebuild when the set really changes
  readonly property string _dirsKey: {
    const dirs = [];
    _requests.forEach(r => r.accounts.forEach(a => {
        if (!dirs.includes(a.dir))
          dirs.push(a.dir);
      }));
    return dirs.join("\n");
  }
  readonly property var _dirs: _dirsKey === "" ? [] : _dirsKey.split("\n")

  property var _queue: []
  property string _current: ""

  on_DirsKeyChanged: if (_active)
    _settle.restart()

  function _labelFor(dir) {
    for (const r of root._requests) {
      const a = r.accounts.find(x => x.dir === dir && x.label !== "");
      if (a)
        return a.label;
    }
    return dir.split("/").pop();
  }

  function _update(dir, changes) {
    const next = Object.assign({}, root.states);
    next[dir] = Object.assign({
      "label": root._labelFor(dir),
      "dir": dir,
      "org": "",
      "plan": "",
      "status": "pending",
      "error": "",
      "fetchedAt": 0,
      "session": null,
      "weekly": null,
      "weeklyOpus": null,
      "weeklySonnet": null,
      "extra": null,
      "breakdown": [],
      "retryAt": 0,
      "failures": 0,
      "rateLimited": false
    }, root.states[dir] ?? {}, changes);
    root.states = next;
    root._saveTimer.restart();
  }

  function _enqueue(dir) {
    if (dir === root._current || root._queue.includes(dir))
      return;
    root._queue = root._queue.concat([dir]);
    root._next();
  }

  // Only the accounts not fetched within the interval and not backing off
  // (after a restart, the saved numbers are still fresh)
  function _isDue(dir, now) {
    const s = root.states[dir];
    return !s || (now >= (s.retryAt ?? 0) && now - (s.fetchedAt ?? 0) >= root._interval * 0.9);
  }

  function _refreshDue() {
    const now = Date.now();
    root._dirs.filter(dir => root._isDue(dir, now)).forEach(dir => root._enqueue(dir));
  }

  // Doubles per consecutive failure, up to an hour; a 429 waits at least
  // five minutes and never less than its Retry-After
  function _backoff(dir, rateLimited, retryAfterSeconds) {
    const failures = (root.states[dir]?.failures ?? 0) + 1;
    const base = rateLimited ? Math.max(root._interval, 300000) : root._interval;
    const delay = Math.max(Math.min(base * Math.pow(2, failures - 1), 3600000), retryAfterSeconds * 1000);
    return {
      "failures": failures,
      "rateLimited": rateLimited,
      "retryAt": Date.now() + delay
    };
  }

  function _readJson(path) {
    const text = FileManager.read(path);
    if (text === null)
      return null;
    try {
      return JSON.parse(text);
    } catch (e) {
      return null;
    }
  }

  // One account at a time
  function _next() {
    if (_curl.running || root._queue.length === 0)
      return;
    const dir = root._queue[0];
    root._queue = root._queue.slice(1);

    const creds = root._readJson(dir + "/.credentials.json")?.claudeAiOauth;
    const account = root.states[dir]?.org ? null : root._readJson(dir + "/.claude.json")?.oauthAccount;
    const info = {
      "label": root._labelFor(dir),
      "plan": creds?.subscriptionType ?? root.states[dir]?.plan ?? ""
    };
    if (account)
      info.org = account.organizationName ?? "";
    if (!creds?.accessToken) {
      root._update(dir, Object.assign(info, {
        "status": "missing",
        "error": "No Claude login in " + dir
      }));
      root._next();
      return;
    }
    if ((creds.expiresAt ?? 0) > 0 && creds.expiresAt < Date.now()) {
      root._update(dir, Object.assign(info, {
        "status": "expired",
        "error": ""
      }));
      root._next();
      return;
    }
    root._update(dir, info);
    root._current = dir;
    // The token goes to curl on stdin, never on its command line
    root._config = ["url = \"https://api.anthropic.com/api/oauth/usage\"", "header = " + root._quote("Authorization: Bearer " + creds.accessToken), "header = \"anthropic-beta: oauth-2025-04-20\"", "header = \"Accept: application/json\"", "max-time = 15", ""].join("\n");
    _curl.stdinEnabled = true;
    _curl.running = true;
  }

  property string _config: ""
  readonly property string _statusMark: "\u001eAXIOM_HTTP "

  function _quote(value) {
    return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
  }

  function _window(w) {
    return w && typeof w.utilization === "number" ? {
      "percent": Math.round(w.utilization),
      "resetsAt": w.resets_at ?? ""
    } : null;
  }

  function _limit(json, kind) {
    const l = (json.limits ?? []).find(x => x?.kind === kind && typeof x.percent === "number");
    return l ? {
      "percent": Math.round(l.percent),
      "resetsAt": l.resets_at ?? ""
    } : null;
  }

  function _parse(json) {
    const extra = json.extra_usage;
    return {
      "session": root._window(json.five_hour) ?? root._limit(json, "session"),
      "weekly": root._window(json.seven_day) ?? root._limit(json, "weekly_all"),
      "weeklyOpus": root._window(json.seven_day_opus),
      "weeklySonnet": root._window(json.seven_day_sonnet),
      "extra": extra?.is_enabled ? {
        "used": extra.used_credits ?? 0,
        "limit": extra.monthly_limit ?? 0,
        "percent": Math.round(extra.utilization ?? 0),
        "currency": extra.currency ?? ""
      } : null,
      "breakdown": (json.seven_day_breakdown?.rows ?? []).filter(r => (r?.percent ?? 0) > 0).map(r => ({
            "name": r.display_name ?? r.key ?? "",
            "percent": Math.round(r.percent)
          }))
    };
  }

  function _onExited(exitCode) {
    const dir = root._current;
    root._current = "";
    const lines = _out.text.split("\n");
    const markAt = lines.findIndex(l => l.startsWith(root._statusMark));
    const mark = markAt >= 0 ? lines[markAt].substring(root._statusMark.length).split(" ") : [];
    const status = parseInt(mark[0]) || 0;
    const retryAfter = parseInt(mark[1]) || 0; // seconds; an HTTP date is ignored
    const body = (markAt >= 0 ? lines.slice(0, markAt) : lines).join("\n");
    let json = null;
    try {
      json = JSON.parse(body);
    } catch (e) {}

    if (status === 401 || json?.error?.type === "authentication_error") {
      root._update(dir, {
        "status": "expired",
        "error": ""
      });
    } else if (status >= 200 && status < 300 && json) {
      root._update(dir, Object.assign(root._parse(json), {
        "status": "ok",
        "error": "",
        "fetchedAt": Date.now(),
        "retryAt": 0,
        "failures": 0,
        "rateLimited": false
      }));
    } else {
      const error = json?.error?.message ?? (status ? `HTTP ${status}` : (_err.text.trim().replace(/^curl: \(\d+\)\s*/, "") || `curl exited with ${exitCode}`));
      const backoff = root._backoff(dir, status === 429, retryAfter);
      console.log(`[ClaudeUsageManager] ${dir}: ${error} (retrying in ${Math.round((backoff.retryAt - Date.now()) / 60000)} min)`);
      root._update(dir, Object.assign(backoff, {
        "status": "error",
        "error": error
      }));
    }
    root._next();
  }

  property Timer _settle: Timer {
    interval: 500
    onTriggered: root._refreshDue()
  }

  // Checks each minute which accounts are due, so backoffs end on time
  property Timer _poll: Timer {
    interval: 60000
    repeat: true
    running: root._active
    onTriggered: root._refreshDue()
  }

  on_ActiveChanged: if (_active)
    _settle.restart()

  property Process _curl: Process {
    command: ["curl", "-sS", "-K", "-", "-w", "\n" + root._statusMark + "%{http_code} %header{retry-after}\n"]
    stdout: StdioCollector {
      id: _out
    }
    stderr: StdioCollector {
      id: _err
    }
    onStarted: {
      write(root._config);
      root._config = "";
      stdinEnabled = false; // closes stdin: the end of curl's config
    }
    onExited: exitCode => root._onExited(exitCode)
  }

  // Claude Code rewrites .credentials.json when it refreshes a token (and
  // sometimes when it hasn't): refetch straight away only an account whose
  // login had lapsed, since fresh numbers stay fresh with a new token
  property Instantiator _watchers: Instantiator {
    model: root._active ? root._dirs : []
    delegate: FileView {
      id: watcher
      required property string modelData
      path: modelData + "/.credentials.json"
      watchChanges: true
      printErrors: false
      onFileChanged: {
        watcher.reload();
        const status = root.states[watcher.modelData]?.status ?? "";
        if (status === "expired" || status === "missing")
          root._enqueue(watcher.modelData);
      }
    }
  }

  // Saved to disk, not a PersistentProperties, so a restart knows when each
  // account was last fetched and doesn't refetch them all at once
  readonly property string _statePath: Paths.userStatePath + "claude-usage.json"

  property Timer _saveTimer: Timer {
    interval: 1000
    onTriggered: root._stateFile.setText(JSON.stringify(root.states, null, 2))
  }

  property FileView _stateFile: FileView {
    path: root._statePath
    printErrors: false
    blockWrites: true
    atomicWrites: true
    onSaveFailed: error => console.warn("[ClaudeUsageManager] Could not save usage:", FileViewError.toString(error))
  }

  Component.onCompleted: {
    try {
      root.states = Object.assign(JSON.parse(FileManager.read("file://" + root._statePath) ?? "{}"), root.states);
    } catch (e) {}
  }

  Component.onDestruction: {
    if (root._saveTimer.running)
      root._stateFile.setText(JSON.stringify(root.states, null, 2));
  }
}
