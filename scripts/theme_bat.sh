#!/usr/bin/env bash
#
# Quickshell theme -> bat (and delta) syntax theme (templates/bat_template.tmTheme).
#
# Usage: theme_bat.sh <theme.json> [output]
#   output: ~/.config/bat/themes/axiom.tmTheme
#   hookup: `--theme=axiom` in ~/.config/bat/config; delta: `syntax-theme = axiom`
#   reload: next run (rebuilds the bat theme cache)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst bat

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/bat/themes/axiom.tmTheme}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/bat_template.tmTheme" "$OUTPUT_FILE"

# bat only sees themes from its cache; delta reads the same cache
bat cache --build >/dev/null
echo "🚀 Rebuilt the bat theme cache."
