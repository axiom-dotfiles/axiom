# Talking to Hyprland (IPC)

> **Files:** `services/HyprlandIpcManager.qml`, `components/methods/HyprReply.qml`, `services/HyprlandManager.qml`
> **Config:** none
> **Related:** [Config modes](config-modes.md), [Workspaces](workspaces.md), [Monitors](monitors.md)

How the shell reads from and acts on Hyprland, without running `hyprctl`.

### Two routes
- **Quickshell's `Quickshell.Hyprland`** covers monitors, workspaces, toplevels, the event stream (`rawEvent`) and `Hyprland.dispatch()`. Use it whenever it has what's needed.
  - `dispatch()` gives no reply, and sends the string as is: it must be Lua (`hl.dsp.*`).
  - A monitor's or toplevel's `lastIpcObject` only updates after a `refresh*()`; `refreshToplevels()` never removes a closed window.
- **`HyprlandIpcManager`** sends what Quickshell doesn't cover to Hyprland's request socket, as hyprctl does, without a process each: `request(command, cb)`, `json("clients", cb)`, `jsonBatch(["getoption …", "animations"], cb)`, `evalLua(lua, cb)` (`"ok"` or the error).

### Rules
- **Only the `Hyprland*` services use either route.** Everything else asks `HyprlandManager` (window list, options, the cursor, Lua through `runLua`), so supporting another compositor means another service with the same members, not edits across the shell.
- Workspace switching and window focusing go through `HyprlandManager.goToWorkspace` / `stepWorkspace` / `nthWorkspace` / `focusWindow` (AGENTS.md › Services).
- `runLua` queues chunks and runs them one at a time, in order; once the queue drains it refetches the window list and, if asked meanwhile, the options (`refreshOptions`).
- Options axiom follows (gaps, split multiplier, blur, the animations) are read in one batch, at startup, on `configreloaded` and after axiom changes them.
- Commands Hyprland or hypridle run, and shell scripts, still call `hyprctl` (the exit bind, DPMS, `setWallpaper.sh`): they run outside the shell.

### The socket
- Hyprland answers one request per connection, then closes it. Each request gets its own `Socket`, closed by us once `HyprReply.complete` says the reply is all there (JSON once it parses, anything else once there's text): Quickshell warns `PeerClosedError` when Hyprland closes first.
- The parser's `splitMarker` is `""`: with a marker the last piece would be held back until the next marker, which never comes.
- A batch (`[[BATCH]]a;b`) gets its replies joined by `"\n\n\n"`. Don't batch `eval`s: their Lua may hold `;`.
- No reply within 5 s calls back with null (logged).
