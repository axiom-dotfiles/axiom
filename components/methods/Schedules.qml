pragma Singleton
import QtQuick

// Pure helpers for what changes on its own: daily time windows ("HH:MM",
// 24-hour; the light/dark schedule, night light) and picking the next
// wallpaper of a rotation. No file access, processes or services.
QtObject {
  id: root

  // "07:30" -> 450, or -1 when it isn't a time
  function minutes(text) {
    const match = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(String(text ?? "").trim());
    return match ? Number(match[1]) * 60 + Number(match[2]) : -1;
  }

  function minutesOf(date) {
    return date.getHours() * 60 + date.getMinutes();
  }

  // Whether `now` (minutes since midnight) is in [start, end), a window that
  // may run past midnight ("20:00"-"07:00"). An empty window (start = end)
  // or an unreadable time is never in.
  function inWindow(now, start, end) {
    const from = minutes(start);
    const to = minutes(end);
    if (from < 0 || to < 0 || from === to)
      return false;
    return from < to ? now >= from && now < to : now >= from || now < to;
  }

  // The next wallpaper of a rotation from `list` (URLs, in name order):
  // "sequential" takes the one after `current` (the first when it isn't
  // listed); "random" any other than `current`, preferring ones not in
  // `taken` (already given to another monitor). `random` is a number in
  // [0, 1), Math.random() in use. "" for an empty list.
  function nextWallpaper(list, current, order, taken, random) {
    if (list.length === 0)
      return "";
    if (order === "sequential")
      return list[(list.indexOf(current) + 1) % list.length];
    const others = list.filter(url => url !== current);
    const fresh = others.filter(url => !(taken ?? []).includes(url));
    const pool = fresh.length > 0 ? fresh : others.length > 0 ? others : list;
    return pool[Math.min(pool.length - 1, Math.floor(random * pool.length))];
  }
}
