pragma Singleton
import QtQuick

// The pomodoro timer's rules, for PomodoroManager. A state is { phase
// ("work" | "short" | "long"), running, endsAt (epoch ms while running),
// pausedRemaining (ms left while paused, 0 for the whole phase), completed
// (focus sessions finished since the last reset) }; settings are
// PomodoroConfig.settings. Every function returns a new state.
QtObject {
  id: root

  readonly property var idle: ({
      "phase": "work",
      "running": false,
      "endsAt": 0,
      "pausedRemaining": 0,
      "completed": 0
    })

  // `state` (from a file: anything) as a valid state
  function normalize(state) {
    const s = state && typeof state === "object" ? state : {};
    const phase = ["work", "short", "long"].includes(s.phase) ? s.phase : "work";
    const running = s.running === true && typeof s.endsAt === "number" && s.endsAt > 0;
    return {
      "phase": phase,
      "running": running,
      "endsAt": running ? s.endsAt : 0,
      "pausedRemaining": !running && typeof s.pausedRemaining === "number" && s.pausedRemaining > 0 ? s.pausedRemaining : 0,
      "completed": typeof s.completed === "number" && s.completed > 0 ? Math.floor(s.completed) : 0
    };
  }

  function duration(phase, settings) {
    const minutes = phase === "short" ? settings.shortBreakMinutes : phase === "long" ? settings.longBreakMinutes : settings.workMinutes;
    return Math.max(1, minutes) * 60000;
  }

  // Ms left: to endsAt while running, else what a pause left or the phase
  function remaining(state, now, settings) {
    if (state.running)
      return Math.max(0, state.endsAt - now);
    return state.pausedRemaining > 0 ? state.pausedRemaining : root.duration(state.phase, settings);
  }

  // 0 at the phase's start, 1 at its end
  function progress(state, now, settings) {
    const total = root.duration(state.phase, settings);
    return Math.max(0, Math.min(1, 1 - root.remaining(state, now, settings) / total));
  }

  // Neither running nor paused part way
  function isIdle(state) {
    return !state.running && state.pausedRemaining === 0;
  }

  function isBreak(state) {
    return state.phase !== "work";
  }

  function start(state, now, settings) {
    if (state.running)
      return state;
    return Object.assign({}, state, {
      "running": true,
      "endsAt": now + root.remaining(state, now, settings),
      "pausedRemaining": 0
    });
  }

  function pause(state, now) {
    if (!state.running)
      return state;
    return Object.assign({}, state, {
      "running": false,
      "endsAt": 0,
      "pausedRemaining": Math.max(1, state.endsAt - now)
    });
  }

  // The phase after this one (a finished focus session counts, and every
  // longBreakEvery-th is followed by a long break), started at `now` when
  // `autoStart` says so for the phase it comes to: { work, breaks }
  function advance(state, now, settings, autoStart) {
    const completed = state.phase === "work" ? state.completed + 1 : state.completed;
    const phase = state.phase !== "work" ? "work" : completed % Math.max(1, settings.longBreakEvery) === 0 ? "long" : "short";
    const run = phase === "work" ? autoStart.work === true : autoStart.breaks === true;
    return {
      "phase": phase,
      "running": run,
      "endsAt": run ? now + root.duration(phase, settings) : 0,
      "pausedRemaining": 0,
      "completed": completed
    };
  }

  // Back to a focus session not yet started; the count goes too with `all`
  function reset(state, all) {
    return Object.assign({}, root.idle, {
      "completed": all ? 0 : state.completed
    });
  }

  // "mm:ss", or "h:mm:ss" from an hour, rounding up so 0:00 is the end
  function format(ms) {
    const total = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(total / 3600);
    const m = Math.floor(total % 3600 / 60);
    const s = total % 60;
    const pad = n => (n < 10 ? "0" : "") + n;
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
  }
}
