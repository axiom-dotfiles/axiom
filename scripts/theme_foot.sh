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

OUTPUT_FILE="${2:-$HOME/.config/foot/axiom.ini}"
load_theme "$1"
export_theme_colors
map_theme_colors hex
render_template "$SCRIPT_DIR/templates/foot_template.ini" "$OUTPUT_FILE"
