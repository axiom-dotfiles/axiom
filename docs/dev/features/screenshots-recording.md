# Screenshots and screen recording

> **Files:** `services/ScreenshotManager.qml`, `shell/Screenshot.qml`, `components/surfaces/screenshot/ScreenshotPickerWindow.qml`, `components/content/ScreenRecord.qml`, `components/bar/widgets/ScreenRecord.qml`
> **Config:** none (choices persist in `config/state/screenshot.json`)
> **Related:** [Keybinds](../hyprland/keybinds.md), [Chat](chat.md) (region attachments), [Utility modules](../overlay/utility-modules.md)

Screenshots and wf-recorder recordings, both in `ScreenshotManager`, with one picker surface for both. Grim and slurp are not used.

Name clash: `KeybindManager.startRecording(index)` is the key recorder on the Keybinds page. It has nothing to do with screen recording.

### Entry points (screenshots)
- The `screenshot` bind action, with an argument `region` / `window` / `screen`.
- IPC `screenshot`: `take <kind>` and `cancel`.
- Launcher `/screenshot`.
- The Screenshot card.
- The chat's region attachments use `pick(path, callback)`. It saves to `path` and calls back instead of copying (see [Chat](chat.md)).

### The picker
- While `picking`, `shell/Screenshot` shows `surfaces/screenshot/ScreenshotPickerWindow`:
  - one frozen `ScreencopyView` frame per screen;
  - layer rule `axiom-screenshot` with `no_anim`;
  - the window under the cursor is highlighted from the start (`HyprlandManager.withCursorPos`).
- Kinds:
  - **`region`:** drag a region, or click a window; clicking off any window takes the screen.
  - **`window`:** click a window.
  - **`screen`:** grabs at once, on one screen.
- **Cropping:** a `ShaderEffectSource` + `grabToImage`, at the buffer's resolution.

### After a capture
- **Saving:** to `<Pictures>/Screenshots`. With `copyOnly` it is only a runtime file.
- **Copying:** to the clipboard with wl-copy.
- Then one of:
  - **A notification** with an "Edit in Satty/Swappy" button. This is a waiting `notify-send -A`; only the latest one stays live.
  - **Opened in satty/swappy straight away** with `annotate`: the picker's "Edit in …" switch, the E key, or holding Shift on release.
- **Watchdog:** a single 3 s watchdog in the service fails any capture that gets no frame, so nothing can wedge it.
  - A picker reports its frame with `frameArrived()`.
  - An immediate `screen` capture must report back too.

### Recording
Recording lives in the service, not in the card, because the overlay destroys the card when it closes.

**Pick-based (`toggleRecording(dir)`):**
- Opens the same picker with kind `record`. That kind has no save or annotate controls.
- R, or the picker's Screenshot / Record switch (`setRecordMode`), flips an open picker between screenshot and record.
- The pick goes to `record(area, screenName)`:
  - a region is passed as global logical `-g`;
  - a whole screen as `-o <screen>`.

**Direct (`startRecording(directory, { mode, audio })`):**
- `mode` is `"pick"` or `"screen"`.
- `screen` records the focused monitor at once, after the overlay or launcher has gone.
- `audio` is `"none"`, `"system"` or `"mic"`:
  - **`system`** is `--audio=$(pactl get-default-sink).monitor`. It runs through `sh -c 'exec wf-recorder …'` so SIGINT still reaches wf-recorder.
  - **`mic`** is the default source.
  - pactl is optional (`hasSystemAudio`, `DependencyManager.found.pactl`, checked by the ScreenRecord card). Without it the card dims System, and a `system` request records no sound.
- `recordAudio` (the ScreenRecord card's choice) is saved with `copyOnly` in `config/state/screenshot.json`.

**Running and stopping:**
- wf-recorder runs until `stopRecording()`, which sends SIGINT to its own process. `pkill` is used only for a recorder left over from before a reload.
- On exit it notifies with the saved file (a click opens it) or with the failure.
- While it runs, `recordingElapsed` ticks for the `ScreenRecord` bar widget. That widget is hidden otherwise; a click on it stops the recording.
- The Privacy widget's screen indicator shows the recording. wf-recorder uses screencopy, so Pipewire never sees it.

**Recording entry points:**
- IPC `screenRecord`: `toggle` / `enable` / `disable` / `status`.
- The `screenRecord` bind action (with a call).
- Launcher `/record`.
- The Screenshot card's Record tile.
- The `ScreenRecord` overlay module: region or screen, the sound, and recent recordings.

### Recent recordings
- `refreshRecordings(directory)` lists the newest 12 `Recording_*.mp4` in a folder into `recordings`:
  - shape: `{ folder: [{ path, name, time, size }] }`;
  - one `find` at a time, from a queue, so cards on different folders each keep their own list;
  - read with `recordingsIn(directory)`;
  - listed again whenever a recording is saved in that folder.
- `deleteRecording` moves a recording to the trash, then lists its folder again.
