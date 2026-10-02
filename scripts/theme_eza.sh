#!/usr/bin/env bash
#
# Quickshell theme -> eza theme (templates/eza_template.yml).
#
# Usage: theme_eza.sh <theme.json> [output]
#   output: ~/.config/eza/axiom/theme.yml
#   hookup: `export EZA_CONFIG_DIR=...` pointing eza at that folder (eza 0.20+)
#   reload: the next eza run
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/eza/axiom/theme.yml}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/eza_template.yml" "$OUTPUT_FILE"
