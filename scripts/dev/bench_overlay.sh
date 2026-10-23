#!/usr/bin/env bash
#
# Times the live overlay: opening it, then switching to each page given, in
# order. For each step it prints how long the IPC call blocked (what was
# built synchronously; a no-op call is ~25 ms) and the pages built during
# it and the wait after, as the overlay logs them (OverlayPage: "Overlay page
# N built in X ms"; a streamed grid; and anything BuildQueueManager built
# that alone took over a frame), then closes the overlay.
#
# Usage: scripts/dev/bench_overlay.sh [-w SECONDS] [PAGE...]
#   PAGE      a view type or a page's name, as `ipc call overlay page` takes
#             (default: just open and close)
#   -w        seconds to wait after each step (default 1.5)

set -euo pipefail

wait_s=1.5
if [[ "${1:-}" == "-w" ]]; then
  wait_s="$2"
  shift 2
fi
repo="$(cd "$(dirname "$0")/../.." && pwd)"
export LC_ALL=C.UTF-8

built() { "$repo/scripts/log.sh" --debug -g 'Overlay (page [0-9]+ built|modules streamed) in|Built .* in [0-9]+ ms' | sed 's/^.*qml: //'; }

step() {
  local before after start end
  before=$(built | wc -l)
  start=$(date +%s%N)
  axiom ipc overlay "$@" 2>/dev/null
  end=$(date +%s%N)
  sleep "$wait_s"
  after=$(built)
  printf '%-28s ipc %5d ms\n' "$*" $(((end - start) / 1000000))
  tail -n +"$((before + 1))" <<<"$after" | sed 's/^/    /'
}

step open
for page in "$@"; do
  step page "$page"
done
step close
