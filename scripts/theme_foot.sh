#!/usr/bin/env bash
#
# Quickshell theme -> Foot colors (templates/foot_template.ini).
#
# Usage: theme_foot.sh <theme.json> [output]
#   output: ~/.config/foot/axiom.ini
#   hookup: `include=~/.config/foot/axiom.ini` in foot.ini
#   reload: new windows (restart a `foot --server` to pick it up)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst foot

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/foot/axiom.ini}"
load_theme "$1"
export_theme_colors
map_theme_colors hex
render_template "$SCRIPT_DIR/templates/foot_template.ini" "$OUTPUT_FILE"

# The template is foot 1.20's format ([colors], with cursor= in it). Newer
# foots have [colors-dark] and [colors-light] instead (1.28 rejects
# [colors]): the theme goes in both, so it shows whichever foot is using.
# Older ones had the cursor in [cursor]. Asked of the installed foot.
foot_accepts() {
    local probe status
    probe="$(mktemp)"
    printf '%s\n' "$@" > "$probe"
    foot --check-config --config="$probe" >/dev/null 2>&1 && status=0 || status=1
    rm -f "$probe"
    return $status
}
if foot_accepts '[colors-dark]' 'background=000000' '[colors-light]' 'background=ffffff'; then
    COLORS="$(sed -n '/^\[colors\]$/,$p' "$OUTPUT_FILE" | tail -n +2)"
    { sed '/^\[colors\]$/,$d' "$OUTPUT_FILE"
      printf '[colors-dark]\n%s\n\n[colors-light]\n%s\n' "$COLORS" "$COLORS"; } | write_atomic "$OUTPUT_FILE"
elif ! foot_accepts '[colors]' 'cursor=000000 ffffff'; then
    CURSOR=$(grep '^cursor=' "$OUTPUT_FILE")
    { printf '[cursor]\ncolor=%s\n\n' "${CURSOR#cursor=}"; grep -v '^cursor=' "$OUTPUT_FILE"; } | write_atomic "$OUTPUT_FILE"
fi
