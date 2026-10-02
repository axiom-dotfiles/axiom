#!/usr/bin/env bash
#
# Quickshell theme -> ncspot colors (templates/ncspot_template.toml).
#
# Usage: theme_ncspot.sh <theme.json> [config]
#   output: $XDG_STATE_HOME/axiom/ncspot-theme.toml, copied between the axiom
#           markers in the [theme] table of ~/.config/ncspot/config.toml
#           (ncspot can't include a file); keys you set in [theme] yourself win
#   hookup: the two marker lines in [theme] (Apply adds them)
#   reload: live (a `reload` sent to ncspot's socket)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 11 "$@"
require_cmds jq envsubst awk

CONFIG="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/ncspot/config.toml}"
OUTPUT="${XDG_STATE_HOME:-$HOME/.local/state}/axiom/ncspot-theme.toml"
# Must match the ncspot x-hookup text in config.schema.json
BEGIN='# axiom theme: begin (rewritten on every theme change)'
END='# axiom theme: end'

load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/ncspot_template.toml" "$OUTPUT"

# Edit the file a symlink points at, keeping the link (a dotfiles repo's)
REAL="$(realpath -m "$CONFIG")"
if [ ! -f "$REAL" ]; then
    warn "'$CONFIG' doesn't exist: turn on the hookup's Apply to add axiom's [theme] block."
    exit 0
fi

# Where the markers are, and the keys the user sets in [theme] outside them
# shellcheck disable=SC2016
SCAN=$(awk -v begin="$BEGIN" -v end="$END" '
    /^[ \t]*\[/ { section = $0; gsub(/^[ \t]*\[[ \t]*|[ \t]*\].*$/, "", section) }
    $0 == begin { if (section == "theme") ok++; inside = 1; markers++; next }
    $0 == end { inside = 0; markers++; next }
    !inside && section == "theme" && /^[ \t]*[A-Za-z_]+[ \t]*=/ { key = $0; sub(/[ \t]*=.*/, "", key); gsub(/[ \t]/, "", key); print "key\t" key }
    END { print "markers\t" markers + 0 "\t" ok + 0 }
' "$REAL")
MARKERS=$(awk -F'\t' '$1 == "markers" { print $2 "\t" $3 }' <<< "$SCAN")
if [ "$MARKERS" != $'2\t1' ]; then
    warn "'$CONFIG' has no axiom block in its [theme] table: turn on the hookup's Apply to add it."
    exit 0
fi
OWN_KEYS=$(awk -F'\t' '$1 == "key" { print $2 }' <<< "$SCAN")
if [ -n "$OWN_KEYS" ]; then
    echo "ℹ️ Left to your config.toml: ${OWN_KEYS//$'\n'/, }"
fi

# The block, without the keys the user sets, spliced between the markers
BLOCK=$(awk -v own="$OWN_KEYS" '
    BEGIN { n = split(own, keys, "\n"); for (i = 1; i <= n; i++) skip[keys[i]] = 1 }
    { key = $0; sub(/[ \t]*=.*/, "", key) }
    !(key in skip)
' "$OUTPUT")
NEW=$(awk -v begin="$BEGIN" -v end="$END" -v block="$BLOCK" '
    $0 == begin { print; print block; inside = 1; next }
    $0 == end { inside = 0 }
    !inside
' "$REAL")
if [ "$NEW" == "$(cat "$REAL")" ]; then
    echo "✅ '$CONFIG' already has these colors"
else
    printf '%s\n' "$NEW" | write_atomic "$REAL"
    echo "✅ Colors written into '$CONFIG'"
fi

# Only for the real config: a running ncspot reloads it
SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ncspot/ncspot.sock"
if [ $# -lt 2 ] && [ -S "$SOCKET" ] && command -v python3 &>/dev/null; then
    python3 - "$SOCKET" <<'EOF' || warn "couldn't ask the running ncspot to reload."
import socket, sys
with socket.socket(socket.AF_UNIX) as s:
    s.settimeout(2)
    s.connect(sys.argv[1])
    s.sendall(b"reload\n")
EOF
fi
