pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.components.methods

/*
 * LauncherManager turns the launcher's search text into result rows and
 * runs them. The first character picks what's searched:
 *   /  shell commands (LauncherCommands)   =  calculator (qalc)
 *   >  run a shell command                 ?  web search
 * and anything else searches apps and open windows, with a calculator row
 * when the text is math and a web search row last. Every row is
 *   { kind, image, glyph, title, usage, subtitle, hint, complete, run(shift) }
 * where image is an icon path or url, glyph a Material Symbols name, complete the
 * text Tab puts in the search field, and run() returns true to close the
 * launcher, false to keep it open, or a string to search for instead.
 * App launches are counted (with their last time) for frecency sorting.
 */
QtObject {
  id: root

  // --- Public Properties ---
  property var results: []
  // What the search text is: "apps" | "commands" | "calc" | "run" | "web"
  property string mode: "apps"
  // The results are the frequent apps shown before anything is typed
  property bool frequent: false
  // The text results was built from
  property string text: ""
  // { id: { count, last } }
  property var usage: ({})
  // { id: last launch time }, for Favourites
  readonly property var launchTimes: Object.keys(usage).reduce((times, id) => {
    times[id] = usage[id].last;
    return times;
  }, {})

  // --- Public Methods ---

  function query(text) {
    root.text = text;
    const raw = text.replace(/^\s+/, "");
    const prefix = raw.charAt(0);
    const rest = raw.slice(1);
    root.frequent = false;

    if (prefix === "/" && LauncherConfig.commands)
      return _set("commands", _commandRows(rest));
    if (prefix === "=" && LauncherConfig.calculator)
      return _set("calc", _calcRows(rest.trim()));
    if (prefix === ">" && LauncherConfig.runCommands)
      return _set("run", [_runRow(rest.trim())]);
    if (prefix === "?" && LauncherConfig.webSearch)
      return _set("web", [_webRow(rest.trim())]);
    if (prefix === "@" && LauncherConfig.chat)
      return _set("chat", [_chatRow(rest.trim())]);

    const q = raw.trim();
    if (q === "") {
      _requestCalc("");
      root.frequent = LauncherConfig.showRecent;
      return _set("apps", root.frequent ? _frequentRows() : []);
    }
    const math = LauncherConfig.calculator && _looksLikeMath(q);
    _requestCalc(math ? q : "");
    let rows = [];
    if (math && _calcReady(q))
      rows.push(_calcRow(q));
    rows = rows.concat(_searchRows(q));
    if (LauncherConfig.webSearch)
      rows.push(_webRow(q));
    _set("apps", rows);
  }

  // Runs results[index]; see the row's run()
  function activate(index, shift) {
    const row = results[index];
    return row ? row.run(!!shift) : false;
  }

  // The text Tab puts in the search field for results[index], or ""
  function completion(index) {
    return results[index]?.complete ?? "";
  }

  function clear() {
    root._armed = "";
    query("");
  }

  function launchApp(appEntry) {
    if (!appEntry)
      return false;
    try {
      const entry = usage[appEntry.id] ?? {
        count: 0,
        last: 0
      };
      const updated = Object.assign({}, usage);
      updated[appEntry.id] = {
        count: entry.count + 1,
        last: Date.now()
      };
      usage = updated;
      _stateHandler.save(usage);

      // DesktopEntry.execute() ignores Terminal=true
      if (appEntry.runInTerminal)
        Quickshell.execDetached([LauncherConfig.terminal, "-e"].concat(appEntry.command));
      else
        appEntry.execute();
      return true;
    } catch (e) {
      console.warn("[LauncherManager] Failed to launch app:", e);
      return false;
    }
  }

  // 0-100: how well `text` matches the lowercased query `q`. Exact, prefix,
  // word start and substring matches rank above a fuzzy subsequence.
  function score(text, q) {
    if (!text || !q)
      return 0;
    const t = text.toLowerCase();
    if (t === q)
      return 100;
    if (t.startsWith(q))
      return 80;
    const at = t.indexOf(q);
    if (at > 0)
      return /[\s\-_./]/.test(t.charAt(at - 1)) ? 65 : 50;
    if (q.length < 2)
      return 0;
    let matched = 0, first = -1, last = 0;
    for (let i = 0; i < t.length && matched < q.length; i++) {
      if (t[i] === q[matched]) {
        if (first < 0)
          first = i;
        last = i;
        matched++;
      }
    }
    if (matched < q.length)
      return 0;
    return Math.max(5, 30 - 2 * (last - first + 1 - q.length));
  }

  // --- Apps & windows ---

  readonly property int _searchLimit: 50

  function _apps() {
    const hidden = LauncherConfig.hiddenApps.map(id => id.replace(/\.desktop$/, ""));
    return DesktopEntries.applications.values.filter(app => !app.noDisplay && !hidden.includes(app.id));
  }

  // How often and how lately an app was launched
  function _frecency(id) {
    const entry = usage[id];
    if (!entry)
      return 0;
    const days = (Date.now() - entry.last) / 86400000;
    return entry.count * (days < 1 ? 1 : days < 7 ? 0.7 : days < 30 ? 0.5 : 0.25);
  }

  function _appRow(app) {
    return {
      kind: "app",
      image: Quickshell.iconPath(app.icon, "application-x-executable"),
      title: app.name,
      subtitle: app.genericName || app.comment || "",
      hint: app.runInTerminal ? I18n.tr("Terminal") : "",
      run: () => root.launchApp(app)
    };
  }

  function _windowRow(win) {
    return {
      kind: "window",
      image: IconResolver.resolveWindowIcon(win.class, win.title),
      title: win.title || win.class,
      subtitle: I18n.tr("{0} · workspace {1}", win.class, win.workspace?.name ?? ""),
      hint: I18n.tr("Window"),
      run: () => {
        HyprlandManager.focusWindow(win.address);
        return true;
      }
    };
  }

  function _searchRows(q) {
    q = q.toLowerCase();
    const scored = [];
    for (const app of _apps()) {
      const keyword = Math.max(0, ...app.keywords.map(k => root.score(k, q)).filter(s => s >= 50));
      const s = Math.max(root.score(app.name, q), 0.75 * root.score(app.genericName, q), 0.6 * keyword);
      if (s > 0)
        scored.push({
          s: s + Math.min(25, 8 * Math.log2(1 + _frecency(app.id))),
          name: app.name,
          row: () => _appRow(app)
        });
    }
    if (LauncherConfig.windows) {
      for (const win of HyprlandManager.windowList) {
        if (!win.mapped || win.hidden)
          continue;
        // No fuzzy matches: titles are long enough to match most anything
        const s = Math.max(0.9 * root.score(win.title, q), 0.8 * root.score(win.class, q));
        if (s >= 40)
          scored.push({
            s: s - 5,
            name: win.title,
            row: () => _windowRow(win)
          });
      }
    }
    scored.sort((a, b) => b.s - a.s || a.name.localeCompare(b.name));
    return scored.slice(0, _searchLimit).map(m => m.row());
  }

  function _frequentRows() {
    return _apps().filter(app => usage[app.id]).sort((a, b) => _frecency(b.id) - _frecency(a.id) || a.name.localeCompare(b.name)).slice(0, LauncherConfig.maxResults).map(app => _appRow(app));
  }

  // --- Commands ---

  property LauncherCommands _commands: LauncherCommands {}
  // A command waiting for its confirming second Enter
  property string _armed: ""

  property Timer _disarm: Timer {
    interval: 3000
    onTriggered: {
      root._armed = "";
      root._refresh();
    }
  }

  // Re-reads the rows after a command that keeps the launcher open, once
  // its (often asynchronous) state change has landed
  property Timer _refreshLater: Timer {
    interval: 250
    onTriggered: root._refresh()
  }

  function _refresh() {
    query(root.text);
  }

  function _infoRow(title, subtitle) {
    return {
      kind: "info",
      glyph: "info",
      title: title,
      subtitle: subtitle ?? "",
      run: () => false
    };
  }

  function _commandRows(body) {
    const commands = _commands.list.filter(c => !c.available || c.available());
    const space = body.indexOf(" ");
    if (space < 0) {
      const q = body.toLowerCase();
      const matches = commands.map((c, i) => ({
            c: c,
            i: i,
            s: q === "" ? 1 : Math.max(root.score(c.name, q), ...c.aliases.map(a => 0.9 * root.score(a, q)))
          })).filter(m => m.s > 0);
      matches.sort((a, b) => b.s - a.s || a.i - b.i);
      return matches.length > 0 ? matches.map(m => _commandRow(m.c, "")) : [_infoRow(I18n.tr("No command \"{0}\"", body), I18n.tr("Type / to list every command"))];
    }

    const name = body.slice(0, space).toLowerCase();
    const arg = body.slice(space + 1);
    const command = commands.find(c => c.name === name || c.aliases.includes(name));
    if (!command)
      return [_infoRow(I18n.tr("No command \"{0}\"", name), I18n.tr("Type / to list every command"))];
    if (!command.options)
      return [_commandRow(command, arg)];

    const q = arg.trim().toLowerCase();
    const options = command.options(arg).map((o, i) => ({
          o: o,
          i: i,
          s: q === "" ? 1 : root.score(o.title, q)
        })).filter(m => m.s > 0);
    options.sort((a, b) => b.s - a.s || a.i - b.i);
    let rows = [];
    if (!command.needsArg && q === "")
      rows.push(_commandRow(command, ""));
    rows = rows.concat(options.map(m => _optionRow(command, m.o)));
    if (options.length === 0 && q !== "")
      rows.push(command.needsArg ? _infoRow(I18n.tr("No matches"), command.description()) : _commandRow(command, arg));
    return rows;
  }

  function _commandRow(command, arg) {
    const takesArg = !!(command.options || command.usage);
    const armed = root._armed === command.name;
    return {
      kind: "command",
      glyph: command.glyph,
      title: "/" + command.name + (arg.trim() ? " " + arg.trim() : ""),
      usage: arg.trim() ? "" : command.usage ?? "",
      subtitle: command.description(),
      hint: armed ? I18n.tr("Press Enter again to confirm") : command.status?.() ?? "",
      armed: armed,
      complete: "/" + command.name + (takesArg ? " " : ""),
      run: () => command.needsArg && arg.trim() === "" ? "/" + command.name + " " : root._runCommand(command, arg, undefined)
    };
  }

  function _optionRow(command, option) {
    return {
      kind: "option",
      glyph: option.image ? "" : option.glyph || command.glyph,
      image: option.image ?? "",
      title: option.title,
      subtitle: option.subtitle ?? "",
      complete: "/" + command.name + " " + option.title,
      run: () => root._runCommand(command, option.title, option.value)
    };
  }

  function _runCommand(command, arg, value) {
    if (command.confirm && root._armed !== command.name) {
      root._armed = command.name;
      _disarm.restart();
      _refresh();
      return false;
    }
    root._armed = "";
    const result = command.run(arg, value);
    if (typeof result === "string")
      return result;
    if (result === false) {
      _refresh();
      _refreshLater.restart();
      return false;
    }
    return true;
  }

  // --- Calculator ---

  property bool _qalc: false
  // The expression wanted, and the last one qalc answered
  property string _calcExpr: ""
  property string _calcDoneExpr: ""
  property string _calcResult: ""

  function _looksLikeMath(q) {
    return /^[\d\s.,+\-*/^%()!×÷]+$/.test(q) && /\d/.test(q) && /[+\-*/^%!×÷]/.test(q);
  }

  function _calcReady(expr) {
    return root._calcDoneExpr === expr && root._calcResult !== "";
  }

  function _requestCalc(expr) {
    if (expr === root._calcExpr)
      return;
    root._calcExpr = expr;
    if (expr !== "" && root._qalc)
      _calcDebounce.restart();
  }

  function _calcRow(expr) {
    const result = root._calcResult;
    return {
      kind: "calc",
      glyph: "calculate",
      title: result,
      subtitle: expr,
      hint: I18n.tr("Enter to copy"),
      complete: "=" + result,
      run: () => {
        Quickshell.execDetached(["wl-copy", "--", result]);
        return true;
      }
    };
  }

  function _calcRows(expr) {
    if (!root._qalc)
      return [_infoRow(I18n.tr("The calculator needs qalc"), I18n.tr("Install libqalculate"))];
    _requestCalc(expr);
    if (expr === "")
      return [_infoRow(I18n.tr("Type an expression"), I18n.tr("Math, units and currencies, e.g. 5 km to mi"))];
    if (_calcReady(expr))
      return [_calcRow(expr)];
    return [_infoRow(expr, root._calcProcess.running || _calcDebounce.running ? I18n.tr("Calculating…") : I18n.tr("No result"))];
  }

  property Timer _calcDebounce: Timer {
    interval: 120
    onTriggered: root._startCalc()
  }

  function _startCalc() {
    if (root._calcExpr === "")
      return;
    if (_calcProcess.running) {
      _calcProcess.pending = true;
      return;
    }
    _calcProcess.expr = root._calcExpr;
    _calcProcess.command = ["qalc", "-t", "--", root._calcExpr];
    _calcProcess.running = true;
  }

  property Process _calcProcess: Process {
    property string expr: ""
    property bool pending: false
    stdout: StdioCollector {
      id: calcOut
    }
    onExited: {
      // qalc echoes what it can't evaluate
      const out = calcOut.text.trim().split("\n").pop().trim();
      const plain = s => s.replace(/\s/g, "").replace(/−/g, "-");
      root._calcResult = out !== "" && plain(out) !== plain(expr) ? out : "";
      root._calcDoneExpr = expr;
      if (pending || expr !== root._calcExpr) {
        pending = false;
        root._startCalc();
      } else {
        root._refresh();
      }
    }
  }

  property Process _qalcCheck: Process {
    command: ["sh", "-c", "command -v qalc"]
    onExited: exitCode => root._qalc = exitCode === 0
  }

  // --- Run & web ---

  function _runRow(command) {
    const terminal = LauncherConfig.terminal;
    return {
      kind: "run",
      glyph: "terminal",
      title: command || I18n.tr("Type a command"),
      subtitle: I18n.tr("Enter runs it, Shift+Enter runs it in {0}", terminal),
      run: shift => {
        if (command === "")
          return false;
        if (shift)
          Quickshell.execDetached([terminal, "-e", "sh", "-c", command + "; exec \"${SHELL:-sh}\""]);
        else
          Quickshell.execDetached(["sh", "-c", command]);
        return true;
      }
    };
  }

  // Asks the overlay's chat, in a new conversation with the default preset
  function _chatRow(q) {
    const preset = ChatConfig.preset(ChatConfig.defaultPreset);
    return {
      kind: "chat",
      glyph: preset.icon || "smart_toy",
      title: q ? I18n.tr("Ask {0}: \"{1}\"", preset.name, q) : I18n.tr("Type a question for the chat"),
      subtitle: ChatConfig.provider(preset.provider)?.name ?? "",
      run: () => {
        if (q === "")
          return false;
        // After the launcher has closed, so the overlay gets the keyboard
        Qt.callLater(() => ChatManager.ask(q));
        return true;
      }
    };
  }

  function _webRow(q) {
    const engine = LauncherConfig.searchEngine;
    const host = (engine.match(/^\w+:\/\/([^/]+)/)?.[1] ?? engine).replace(/^www\./, "");
    return {
      kind: "web",
      glyph: "web",
      title: q ? I18n.tr("Search the web for \"{0}\"", q) : I18n.tr("Type something to search for"),
      subtitle: host,
      run: () => {
        if (q === "")
          return false;
        Qt.openUrlExternally(engine.includes("{}") ? engine.replace("{}", encodeURIComponent(q)) : engine + encodeURIComponent(q));
        return true;
      }
    };
  }

  // --- Private ---

  property var _stateHandler: StateManager.createStateHandler("launcher")

  function _set(mode, rows) {
    root.mode = mode;
    root.results = rows;
  }

  Component.onCompleted: {
    // Older state held just { id: last launch time }
    const saved = _stateHandler.load({});
    usage = Object.keys(saved).reduce((all, id) => {
      const entry = saved[id];
      all[id] = typeof entry === "number" ? {
        count: 1,
        last: entry
      } : entry;
      return all;
    }, {});
    _qalcCheck.running = true;
  }
}
