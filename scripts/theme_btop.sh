#!/usr/bin/env bash
#
# Quickshell theme -> btop theme (templates/btop_template.theme).
#
# Usage: theme_btop.sh <theme.json> [output]
#   output: ~/.config/btop/themes/axiom.theme
#   hookup: `color_theme = "axiom"` in ~/.config/btop/btop.conf
#   reload: btop's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst btop

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/btop/themes/axiom.theme}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/btop_template.theme" "$OUTPUT_FILE"
