# Todo and pomodoro

> **Files:** `services/TodoManager.qml`, `services/PomodoroManager.qml`, `components/methods/TodoItems.qml`, `components/methods/PomodoroCycle.qml`, `config/TodoConfig.qml`, `config/PomodoroConfig.qml`, `components/bar/widgets/Todo.qml`, `components/bar/widgets/Pomodoro.qml`, `components/content/Todo.qml`, `components/content/Pomodoro.qml`, `components/content/Focus.qml`, `components/content/parts/TodoList.qml`, `components/content/parts/PomodoroDial.qml`
> **Config:** `Todo.*` (reader `TodoConfig`), `Pomodoro.*` (reader `PomodoroConfig`)
> **Related:** [Calendar](calendar.md), [Notifications](notifications.md), [Launcher](launcher.md), [Writing modules](../overlay/writing-modules.md)

One todo list and one pomodoro timer, each shown by a bar widget, its popout and an overlay module, plus the Focus module holding both and today's events.

### Todo list
- **Storage:** `$XDG_DATA_HOME/axiom/todo.json` (`TodoManager.path`): `{ version: 1, items }`. It's user content, not config: never exported, imported or snapshotted.
  - Written atomically on every change (a `FileView`; the data folder is made on the first failed write) and watched, so an edit from elsewhere shows at once. An unreadable file is reported and the list shown stays.
  - Never read or written in the greeter.
- **Items** (`TodoItems`, pure, `tst_TodoItems`): `{ uid, summary, done, created, completed, due, order }`. Every change returns a new list.
  - The fields are a CalDAV VTODO's (UID, SUMMARY, STATUS, CREATED, COMPLETED, DUE), so syncing a task list later maps them one to one. Not done: `calendar_sync.py` reads only VEVENTs, and two-way task sync (servers differ, offline edits, subtasks, repeating tasks) is its own job.
  - `due` is kept but nothing sets it yet.
- **Shown:** `TodoManager.shownItems`: open items in order, then (with `Todo.showCompleted`) the done ones, the last finished first.
- **UI:** `TodoList` (add field, rows: click ticks off or reopens; rename, work on it, delete on hover). The `Todo` widget shows the open count; its popout and module are `content/Todo.qml` (header with Clear completed).
- **Entry points:** IPC `todo` (`add`, `toggle <text>`, `list`, `count`, `clearCompleted`); launcher `/todo [text]` (with text, a row adding it; the open items matching, picked to tick off).
- Not done yet: reordering by drag (`TodoManager.move` exists).

### Pomodoro timer
- **State** (`PomodoroCycle`, pure, `tst_PomodoroCycle`): `{ phase (work | short | long), running, endsAt, pausedRemaining, completed }`. An absolute `endsAt`, so the time left is worked out, never counted down.
  - Every `longBreakEvery`-th finished focus session is followed by a long break.
  - `Pomodoro.autoStartBreaks` / `autoStartWork` say whether the next phase starts by itself.
- **Kept:** in a `PersistentProperties` (a QML reload) and StateManager `pomodoro` (a restart), with the todo it's for (`todoUid`).
- **The end:** one single-shot timer to `endsAt`, at most an hour at a time, running with nothing showing the timer (the service is created from `shell.qml`'s `_services`). At the end it advances and, with `Pomodoro.notify`, sends a notification (`desktopEntry` `axiom-pomodoro`; a click opens a page or edge menu with a Pomodoro or Focus module: `openTimer`). A phase that ended over 5 minutes before axiom noticed (it wasn't running) advances without one.
- **The display:** `now` ticks once a second only while running and something has `acquire(owner)`d it (the widget, the modules).
- **UI:** `PomodoroDial` (ring, phase, a dot per session to the long break, stop / start-pause / skip, task picker). The `Pomodoro` widget: time left while not idle, colored by phase; left click toggles, right skips, middle stops. Its popout and module are `content/Pomodoro.qml`.
- **Entry points:** IPC `pomodoro` (`start`, `pause`, `toggle`, `skip`, `stop`, `reset`, `status`); launcher `/pomodoro [start|pause|skip|stop]`.

### Focus module
- `content/Focus.qml`: the dial (no task picker: the list's "work on this" picks it), the todo list, and today's events (`DayPane`, acquiring `CalendarManager`), side by side when wide. `showTimer` / `showTodos` / `showAgenda`.

### Settings
- `Todo` and `Pomodoro` are Modules sections, scope `personal`: shared by every widget and module, carried by an export only with personal parts.
