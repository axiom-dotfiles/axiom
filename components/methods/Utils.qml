pragma Singleton
import QtQuick

// Pure helpers: deep copies, free ids, usage counts, curl config values, text width
// and truncation, colors, calendar grids, byte sizes and rates. No file access, processes or
// services (those live in services/).
QtObject {
  id: root

  // A deep copy of plain JSON data (null for undefined): a new object for
  // bindings, or a draft that can be mutated in place
  function clone(value) {
    return JSON.parse(JSON.stringify(value ?? null));
  }

  // `base` if `taken` doesn't hold it, else its stem (a trailing
  // `separator` + number dropped) numbered from 2: a copy of "dock2" is
  // "dock3", not "dock22"
  function freeId(base, taken, separator = "") {
    if (!taken.includes(base))
      return base;
    const stem = base.replace(new RegExp(separator + "\\d+$"), "");
    let n = 2;
    while (taken.includes(stem + separator + n))
      n++;
    return stem + separator + n;
  }

  // `usage` ({ key: { count, last } }) with one more use of `key` at `now`
  // (ms), as a new object so bindings on it update
  function recordUse(usage, key, now) {
    const entry = usage?.[key] ?? {
      "count": 0,
      "last": 0
    };
    const updated = Object.assign({}, usage);
    updated[key] = {
      "count": entry.count + 1,
      "last": now
    };
    return updated;
  }

  // A value for a curl config file (`curl -K`): double-quoted, with \, "
  // and newlines escaped, so it can't end its line and start another option
  function curlConfigValue(value) {
    return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\r/g, "\\r").replace(/\n/g, "\\n") + "\"";
  }

  function charWidth(codePoint) {
    return ((codePoint >= 0x1100 && codePoint <= 0x115F) || codePoint === 0x2329 || codePoint === 0x232A || (codePoint >= 0x2E80 && codePoint <= 0xA4CF && codePoint !== 0x303F) || (codePoint >= 0xAC00 && codePoint <= 0xD7A3) || (codePoint >= 0xF900 && codePoint <= 0xFAFF) || (codePoint >= 0xFE30 && codePoint <= 0xFE6F) || (codePoint >= 0xFF00 && codePoint <= 0xFF60) || (codePoint >= 0xFFE0 && codePoint <= 0xFFE6) || (codePoint >= 0x20000 && codePoint <= 0x3FFFD)) ? 2 : 1;
  }

  function visualWidth(text) {
    let width = 0;
    for (const ch of text)
      width += charWidth(ch.codePointAt(0));
    return width;
  }

  function truncate(text, maxLength, ellipsis = "...") {
    const fullWidth = visualWidth(text);
    if (fullWidth <= maxLength)
      return text;

    const ellipsisWidth = visualWidth(ellipsis);
    const budget = maxLength - ellipsisWidth;

    let width = 0;
    let result = "";
    for (const ch of text) {
      const w = charWidth(ch.codePointAt(0));
      if (width + w > budget)
        break;
      result += ch;
      width += w;
    }
    return result + ellipsis;
  }

  readonly property real bytesPerGiB: 1073741824

  // A transfer rate as [value, unit]: "B/s" to "GB/s", one decimal under
  // 10 (past bytes), e.g. [1.5, "MB/s"], [512, "KB/s"]
  function rateParts(bytesPerSecond) {
    const units = ["B/s", "KB/s", "MB/s", "GB/s"];
    let value = Math.max(0, bytesPerSecond || 0);
    let i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return [value < 10 && i > 0 ? Number(value.toFixed(1)) : Math.round(value), units[i]];
  }

  // "1.5 MB/s"
  function formatRate(bytesPerSecond) {
    return root.rateParts(bytesPerSecond).join(" ");
  }

  // A disk size: whole GiB ("512G"), or TiB with one decimal from 1000 GiB
  // ("1.8T")
  function formatSize(bytes) {
    const gib = bytes / root.bytesPerGiB;
    return gib >= 1000 ? `${(gib / 1024).toFixed(1)}T` : `${Math.round(gib)}G`;
  }

  // A colour to animate to or from: a fully transparent `c` becomes the
  // first visible one of `fallbacks` at alpha 0, since fading through
  // "transparent" (transparent black) flashes dark mid-animation
  function fadeable(c, ...fallbacks) {
    if (Qt.color(c).a > 0)
      return c;
    const visible = fallbacks.find(f => Qt.color(f).a > 0);
    return visible !== undefined ? Qt.alpha(visible, 0) : c;
  }

  // Check if color is dark
  function isColorDark(color) {
    const c = Qt.color(color);
    const luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return luminance < 0.5;
  }

  // Get contrasting text color for background
  function getContrastColor(backgroundColor) {
    return isColorDark(backgroundColor) ? "#FFFFFF" : "#000000";
  }

  // The 6 weeks (42 days) shown for a month, starting on `firstDay` (0 =
  // Sunday, as Date.getDay()): [{ day, month, year, inMonth, isToday }].
  // `today` is a date string (Date.toDateString()), so callers can bind
  // it to something that only changes once a day.
  function monthGrid(year, month, firstDay, today) {
    const first = new Date(year, month, 1);
    const start = new Date(year, month, 1 - ((first.getDay() - firstDay + 7) % 7));
    const days = [];
    for (let i = 0; i < 42; i++) {
      const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
      days.push({
        "day": d.getDate(),
        "month": d.getMonth(),
        "year": d.getFullYear(),
        "inMonth": d.getMonth() === month,
        "isToday": d.toDateString() === today
      });
    }
    return days;
  }
}
