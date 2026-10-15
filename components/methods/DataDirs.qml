pragma Singleton
import QtQuick

// Where axiom keeps what it writes (XDG base directories), and where it
// kept it inside the repo before (the legacy layout, until moved over).
// Every path ends in a slash. ConfigManager resolves these; Paths hands
// them out.
QtObject {
  id: root

  // An XDG base directory: the variable when it's an absolute path (the
  // spec ignores relative ones), else HOME's fallback; no trailing slash
  function _base(env, name, fallback) {
    const value = String(env[name] ?? "").trim();
    if (value.startsWith("/"))
      return value.replace(/(.)\/+$/, "$1");
    return String(env.HOME ?? "").replace(/\/+$/, "") + "/" + fallback;
  }

  // The XDG layout for `env` ({ HOME, XDG_CONFIG_HOME, XDG_STATE_HOME,
  // XDG_DATA_HOME }): { config, state, ui, data, notes, generatedThemes }.
  // `state` is axiom's own state folder (secrets, chats, generated configs),
  // `ui` the small JSON state files, `notes` the default notes folder
  function xdg(env) {
    const config = root._base(env, "XDG_CONFIG_HOME", ".config") + "/axiom/";
    const state = root._base(env, "XDG_STATE_HOME", ".local/state") + "/axiom/";
    const data = root._base(env, "XDG_DATA_HOME", ".local/share") + "/axiom/";
    return {
      "config": config,
      "state": state,
      "ui": state + "ui/",
      "data": data,
      "notes": data + "notes/",
      "generatedThemes": state + "themes/"
    };
  }

  // The layout from before the move, the same shape as xdg(): config,
  // UI state, notes and generated themes inside the repo at `shellDir`
  // (state and data were already XDG)
  function legacy(env, shellDir) {
    const repo = String(shellDir).replace(/\/*$/, "/");
    const current = root.xdg(env);
    return {
      "config": repo + "config/user/",
      "state": current.state,
      "ui": repo + "config/state/",
      "data": current.data,
      "notes": repo + "config/state/notes/",
      "generatedThemes": repo + "config/themes/generated/"
    };
  }

  // The file whose presence in the legacy config folder says its contents
  // were copied over (scripts/migrate_xdg.sh writes it last)
  readonly property string movedMarker: "MOVED.md"
}
