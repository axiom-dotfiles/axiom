pragma Singleton

import QtQuick

// Pure main-axis layout for a bar (BarContainer) and its sections
// (WidgetGroup). A bar has five sections, [left, leftCenter, center,
// rightCenter, right]; a widget's measure is { pref, min, priority }.
QtObject {
  id: root

  // Length of the given sizes laid end to end, `spacing` between them.
  // Zero sizes (hidden widgets, or ones with nothing to show) take no
  // spacing, as they take no room when laid out.
  function span(sizes, spacing) {
    const shown = sizes.filter(s => s > 0);
    return shown.reduce((sum, s) => sum + s, 0) + Math.max(0, shown.length - 1) * spacing;
  }

  // Returns [{offset, extent}] for each section along the main axis, from
  // their preferred and minimum lengths. `margin` is kept clear at both ends
  // and `gap` between adjacent non-empty sections. With `lockCenter`, the
  // center section always sits dead center at its full size and each side
  // fits itself into the room left on its own half; otherwise the center
  // slides towards the roomier side when crowded.
  function layoutSections(pref, min, length, margin, gap, lockCenter) {
    const sum = values => values.reduce((a, b) => a + b, 0);
    const gapsFor = sections => gap * sections.filter(i => pref[i] > 0).length;
    // Preferred sizes if they fit, else squeezed towards the minimums,
    // else the minimums scaled down to whatever room there is
    const fit = (p, m, room) => {
      room = Math.max(0, room);
      const sumPref = sum(p);
      const sumMin = sum(m);
      if (sumPref <= room)
        return p.slice();
      if (sumMin <= room) {
        const squeeze = (sumPref - room) / (sumPref - sumMin);
        return p.map((v, i) => v - (v - m[i]) * squeeze);
      }
      return m.map(v => sumMin > 0 ? v * room / sumMin : 0);
    };

    let size, centerStart;
    if (lockCenter) {
      const c = Math.min(pref[2], Math.max(0, length - 2 * margin));
      centerStart = (length - c) / 2;
      const [l, lc] = fit([pref[0], pref[1]], [min[0], min[1]], centerStart - margin - gapsFor([0, 1]));
      const [rc, r] = fit([pref[3], pref[4]], [min[3], min[4]], centerStart - margin - gapsFor([3, 4]));
      size = [l, lc, c, rc, r];
    } else {
      size = fit(pref, min, length - 2 * margin - gapsFor([0, 1, 3, 4]));
      const [l, lc, c, rc, r] = size;
      const lo = margin + (l > 0 ? l + gap : 0) + (lc > 0 ? lc + gap : 0);
      const hi = length - margin - (r > 0 ? r + gap : 0) - (rc > 0 ? rc + gap : 0) - c;
      centerStart = Math.max(lo, Math.min((length - c) / 2, hi));
    }

    const [l, lc, c, rc, r] = size;
    const before = lc > 0 ? lc + gap : 0;

    return [
      {
        "offset": margin,
        "extent": l
      },
      {
        "offset": centerStart - before,
        "extent": lc
      },
      {
        "offset": centerStart,
        "extent": c
      },
      {
        "offset": centerStart + c + (rc > 0 ? gap : 0),
        "extent": rc
      },
      {
        "offset": length - margin - r,
        "extent": r
      }
    ];
  }

  // measures: per section, [{pref, min, priority}]. Returns, per section,
  // the widget indices to hide so that every section's minimum length, plus
  // margins and gaps as in layoutSections, fits the bar; `spacing` is the
  // spacing between widgets within a section. The lowest priority goes
  // first. Ties go to the outer sections first and the center last, and
  // within a section to the widget listed last. With `lockCenter`, each half
  // of the bar must fit beside the full-size center on its own, and only the
  // overflowing half loses widgets; the center is only touched if it can't
  // fit the bar.
  function overflowHidden(measures, length, margin, gap, spacing, lockCenter) {
    const hidden = measures.map(() => []);
    const spanOf = (s, key) => root.span(measures[s].filter((m, i) => m.pref > 0 && !hidden[s].includes(i)).map(m => m[key]), spacing);
    const minSpan = s => spanOf(s, "min");
    const sideNeed = sections => sections.reduce((sum, s) => {
        const len = minSpan(s);
        return sum + (len > 0 ? len + gap : 0);
      }, 0);
    const room = length - 2 * margin + 0.5;

    // The sections to drop from (in tie order), or null when it all fits
    const overflowing = () => {
      if (!lockCenter) {
        const spans = measures.map((m, s) => minSpan(s));
        const needed = spans.reduce((a, b) => a + b, 0) + gap * [0, 1, 3, 4].filter(s => spans[s] > 0).length;
        return needed > room ? [4, 0, 3, 1, 2] : null;
      }
      if (minSpan(2) > room)
        return [2];
      const half = (length - Math.min(spanOf(2, "pref"), length - 2 * margin)) / 2 - margin + 0.5;
      if (sideNeed([0, 1]) > half)
        return [0, 1];
      if (sideNeed([3, 4]) > half)
        return [4, 3];
      return null;
    };

    const dropped = [];
    let order;
    while (length > 0 && (order = overflowing())) {
      let drop = null;
      order.forEach(s => {
        for (let i = measures[s].length - 1; i >= 0; i--) {
          const m = measures[s][i];
          if (m.pref > 0 && !hidden[s].includes(i) && (!drop || m.priority < drop.priority))
            drop = {
              "section": s,
              "index": i,
              "priority": m.priority
            };
        }
      });
      if (!drop)
        break;
      hidden[drop.section].push(drop.index);
      dropped.push(drop);
    }
    // Hiding a big widget can free more room than was missing; bring back
    // whatever still fits, most important (last dropped) first
    for (let d = dropped.length - 1; d >= 0; d--) {
      const list = hidden[dropped[d].section];
      list.splice(list.indexOf(dropped[d].index), 1);
      if (overflowing())
        list.push(dropped[d].index);
    }
    return hidden;
  }

  // The runs of true flags, as { start, count, members }: the widgets that
  // share a background (merged) or a powerline chain. A false flag (a
  // widget shown without a background) ends a run; a null one (a widget
  // showing nothing) is passed over, so `members` lists the indices in it.
  function runs(flags) {
    const out = [];
    let open = false;
    flags.forEach((on, i) => {
      if (on === null || on === undefined)
        return;
      if (!on) {
        open = false;
        return;
      }
      if (open) {
        const last = out[out.length - 1];
        last.count++;
        last.members.push(i);
      } else {
        out.push({
          "start": i,
          "count": 1,
          "members": [i]
        });
        open = true;
      }
    });
    return out;
  }

  // Each index's place in its run, { run, index, count }, or null off them
  function runPlaces(flags) {
    const places = flags.map(() => null);
    root.runs(flags).forEach((run, r) => {
      run.members.forEach((member, k) => {
        places[member] = {
          "run": r,
          "index": k,
          "count": run.count
        };
      });
    });
    return places;
  }

  // A floating bar's islands along it, from its sections' spans ({ start,
  // end }, the empty ones left out): each span grown by `gap` (its widgets'
  // room to the island's ends) within the limits, islands at most `merge`
  // apart joined. With `whole`, one island from limit to limit. Shaped like
  // pills ({ start, length, joinStart, joinEnd }; an island joins nothing),
  // so the pill code reads them.
  function islandRects(spans, gap, merge, limitStart, limitEnd, whole) {
    const rect = (start, end) => ({
          "start": start,
          "length": end - start,
          "joinStart": false,
          "joinEnd": false
        });
    if (whole)
      return [rect(limitStart, limitEnd)];
    const grown = spans.map(span => ({
          "start": Math.max(limitStart, span.start - gap),
          "end": Math.min(limitEnd, span.end + gap)
        })).sort((a, b) => a.start - b.start);
    return root._mergeSpans(grown, merge).map(m => rect(m.start, m.end));
  }

  // The islands as drawn: `stretch` ({ index, start, end, squareStart,
  // squareEnd }, or null) grows one to carry an open popout, which then
  // joins any island it comes within `merge` of. { start, length,
  // squareStart, squareEnd }: a squared end has its inner corner square,
  // where a popout runs flush into it.
  function stretchIslands(rects, stretch, merge) {
    const spans = rects.map((r, i) => {
      const grows = stretch?.index === i;
      return {
        "start": grows ? Math.min(r.start, stretch.start) : r.start,
        "end": grows ? Math.max(r.start + r.length, stretch.end) : r.start + r.length,
        "squareStart": grows && (stretch.squareStart ?? false),
        "squareEnd": grows && (stretch.squareEnd ?? false)
      };
    });
    return root._mergeSpans(spans, merge).map(m => ({
          "start": m.start,
          "length": m.end - m.start,
          "squareStart": m.squareStart ?? false,
          "squareEnd": m.squareEnd ?? false
        }));
  }

  // Sorted { start, end, ... } spans with those at most `merge` apart
  // joined, each keeping the flags of the span its ends came from
  function _mergeSpans(spans, merge) {
    const merged = [];
    spans.forEach(span => {
      const last = merged[merged.length - 1];
      if (!last || span.start - last.end > merge) {
        merged.push(Object.assign({}, span));
      } else if (span.end > last.end) {
        last.end = span.end;
        last.squareEnd = span.squareEnd;
      }
    });
    return merged;
  }

  // One section's widgets within `maxExtent`: measures [{pref, min,
  // priority}] and shown [bool] -> { sizes, offsets, visible }. Should even
  // the minimum sizes not fit, the lowest-priority widgets (the last listed
  // on a tie) are hidden; then elastic widgets shrink towards their minimum
  // sizes in proportion to how much they can give.
  function allocate(measures, shown, maxExtent, spacing) {
    const visible = shown.slice();
    const total = key => root.span(measures.filter((m, i) => visible[i]).map(m => m[key]), spacing);

    // Half a pixel of slack, so fractional text widths don't hide a widget
    const room = maxExtent + 0.5;
    while (total("min") > room) {
      let drop = -1;
      measures.forEach((m, i) => {
        if (visible[i] && (drop < 0 || m.priority <= measures[drop].priority))
          drop = i;
      });
      if (drop < 0)
        break;
      visible[drop] = false;
    }

    const pref = total("pref");
    const min = total("min");
    const squeeze = pref > room && pref > min ? Math.min(1, (pref - maxExtent) / (pref - min)) : 0;

    const sizes = measures.map((m, i) => visible[i] ? Math.floor(m.pref - (m.pref - m.min) * squeeze) : 0);
    const offsets = [];
    let pos = 0;
    sizes.forEach(size => {
      offsets.push(pos);
      if (size > 0)
        pos += size + spacing;
    });
    return {
      "sizes": sizes,
      "offsets": offsets,
      "visible": visible
    };
  }
}
