pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Greetd

import qs.config
import qs.components.methods

// The login itself, in the greeter (greeter.qml): who logs in, into which
// session, and the conversation with greetd (Quickshell's Greetd: PAM
// through greetd's IPC). Only the greeter references it, so the user's
// own shell never connects to greetd; its preview leaves every action
// inert. Also the greeter's Hyprland: the monitor layouts and, in managed
// mode, the options the bundle carries (HyprLua.greeterLua), and the
// keyboard layout switch.
QtObject {
  id: root

  readonly property bool available: Greetd.available

  // --- Users and sessions ---

  // Regular accounts (GreeterUsers), by name
  readonly property var users: _users
  property var _users: []
  // Wayland sessions (GreeterSessions), by name
  readonly property var sessions: _sessions
  property var _sessions: []

  // Who logs in ({ name, realName, … }, a typed name included), or null
  readonly property var selectedUser: _selectedUser
  property var _selectedUser: null
  // The session they log into, or null while there are none
  readonly property var selectedSession: _sessions.find(session => session.id === root._selectedSessionId) ?? _sessions[0] ?? null
  property string _selectedSessionId: ""

  // A user's picture (AccountsService's icon), or "" when they have none
  function avatarOf(name) {
    return root._avatars.includes(name) ? "file:///var/lib/AccountsService/icons/" + name : "";
  }
  property var _avatars: []

  function selectUser(name) {
    const user = GreeterUsers.find(root._users, name);
    if (user?.name === root._selectedUser?.name)
      return;
    root.cancel();
    root._selectedUser = user;
    // Their last session, if any
    const last = user ? root._saved.sessions?.[user.name] : undefined;
    if (last && root._sessions.some(session => session.id === last))
      root._selectedSessionId = last;
  }

  function selectSession(id) {
    root._selectedSessionId = id;
  }

  // --- The login ---

  // greetd's current question ("Password:", a one-time code), and whether
  // its answer may show as typed
  readonly property string prompt: _prompt
  property string _prompt: ""
  readonly property bool promptEcho: _promptEcho
  property bool _promptEcho: false
  // What the login checks last said (an info line, a failure)
  readonly property string message: _message
  property bool _messageIsError: false
  readonly property bool messageIsError: _messageIsError
  property string _message: ""
  // Waiting on greetd
  readonly property bool busy: _busy
  property bool _busy: false

  signal failed

  // An answer to the current question: the password, at first. Starts a
  // greetd session for the selected user if none is going
  function submit(response) {
    if (!root._selectedUser || !root.selectedSession || root._busy)
      return;
    root._message = "";
    if (Greetd.state === GreetdState.Inactive) {
      root._pending = response;
      root._busy = true;
      Greetd.createSession(root._selectedUser.name);
      return;
    }
    root._busy = true;
    Greetd.respond(response);
  }

  // Drops a session in progress (the user changed, Escape)
  function cancel() {
    root._pending = null;
    root._prompt = "";
    root._busy = false;
    if (Greetd.state !== GreetdState.Inactive)
      Greetd.cancelSession();
  }

  // The answer waiting for greetd's first question
  property var _pending: null

  property Connections _greetd: Connections {
    target: Greetd

    function onAuthMessage(message, error, responseRequired, echoResponse) {
      if (responseRequired && root._pending !== null) {
        const response = root._pending;
        root._pending = null;
        Greetd.respond(response);
        return;
      }
      root._busy = false;
      if (responseRequired) {
        // A further question (a one-time code): asked in the field
        root._prompt = message;
        root._promptEcho = echoResponse;
      } else {
        root._message = message;
        root._messageIsError = error;
      }
    }

    function onAuthFailure(message) {
      root._pending = null;
      root._prompt = "";
      root._busy = false;
      root._message = message || I18n.tr("Wrong password");
      root._messageIsError = true;
      if (Greetd.state !== GreetdState.Inactive)
        Greetd.cancelSession();
      root.failed();
    }

    function onError(error) {
      console.warn("[GreetdManager] greetd:", error);
      root._pending = null;
      root._prompt = "";
      root._busy = false;
      root._message = error;
      root._messageIsError = true;
      root.failed();
    }

    function onReadyToLaunch() {
      const session = root.selectedSession;
      root._remember(root._selectedUser.name, session.id);
      console.log("[GreetdManager] Starting", session.id, "for", root._selectedUser.name);
      Greetd.launch(session.exec, GreeterSessions.environment(session), true);
    }
  }

  // --- Power ---

  // "suspend" | "reboot" | "poweroff": logind lets the greeter's own
  // session do these
  function power(action) {
    if (["suspend", "reboot", "poweroff"].includes(action))
      Quickshell.execDetached(["systemctl", action]);
  }

  // --- Keyboard layouts ---

  // The keyboard's layouts ("us,de" split) and the active one's name
  readonly property var layouts: _layouts
  property var _layouts: []
  readonly property string activeLayout: _activeLayout
  property string _activeLayout: ""

  function nextLayout() {
    CommandManager.run(["hyprctl", "switchxkblayout", "all", "next"], () => root._readLayouts());
  }

  function _readLayouts() {
    CommandManager.run(["hyprctl", "devices", "-j"], (exitCode, out) => {
      try {
        const keyboard = (JSON.parse(out).keyboards ?? []).find(k => k.main) ?? JSON.parse(out).keyboards?.[0];
        root._layouts = String(keyboard?.layout ?? "").split(",").filter(layout => layout !== "");
        root._activeLayout = keyboard?.active_keymap ?? "";
      } catch (e) {
        console.warn("[GreetdManager] hyprctl devices:", e);
      }
    });
  }

  // --- Remembered choices (the greeter's own state) ---

  property var _state: StateManager.createStateHandler("greeter")
  // { lastUser, sessions: { user: session id } }
  property var _saved: ({})

  function _remember(user, session) {
    const sessions = Object.assign({}, root._saved.sessions ?? {});
    sessions[user] = session;
    root._saved = {
      "lastUser": GreeterConfig.rememberUser ? user : "",
      "sessions": sessions
    };
    root._state.save(root._saved);
  }

  // --- Startup ---

  function _readSessions() {
    const folder = "/usr/share/wayland-sessions";
    CommandManager.run(["find", folder, "-maxdepth", "1", "-name", "*.desktop"], (exitCode, out) => {
      const files = out.split("\n").filter(file => file !== "");
      root._sessions = GreeterSessions.sorted(files.map(file => GreeterSessions.parse(FileManager.read("file://" + file), file.replace(/^.*\//, "").replace(/\.desktop$/, ""))));
      if (root._sessions.length === 0)
        console.warn("[GreetdManager] No sessions in", folder);
    });
  }

  // The monitors and, in managed mode, the bundle's Hyprland options
  function _applyHyprland() {
    const config = ConfigManager.config;
    const managedSchema = ConfigManager.configSchema.properties.Hyprland.properties.managed;
    const managed = config.Hyprland.mode === "managed" ? config.Hyprland.managed : undefined;
    const lua = HyprLua.greeterLua(config.Hyprland.monitors.profiles, managedSchema, managed, name => Theme.resolveColor(name).toString().slice(1, 7));
    HyprlandManager.runLua(lua.join("\n"));
    if (managed?.cursorTheme)
      CommandManager.run(["hyprctl", "setcursor", managed.cursorTheme, String(managed.cursorSize)]);
  }

  Component.onCompleted: {
    if (!Paths.greeter)
      return;
    root._saved = root._state.load({});
    root._users = GreeterUsers.parse(FileManager.read("file:///etc/passwd"), GreeterUsers.uidRange(FileManager.read("file:///etc/login.defs")));
    if (GreeterConfig.rememberUser && root._saved.lastUser)
      root.selectUser(root._saved.lastUser);
    root._readSessions();
    CommandManager.run(["ls", "-1", "/var/lib/AccountsService/icons"], (exitCode, out) => root._avatars = out.split("\n").filter(name => name !== ""));
    // Windowed (looked at from a running session), the Hyprland is the
    // session's own: left alone
    if (Quickshell.env("AXIOM_GREETER_WINDOWED") !== "1")
      root._applyHyprland();
    root._readLayouts();
  }
}
