#!/usr/bin/env bash
#
# Quickshell theme -> fish theme (templates/fish_template.theme).
#
# Usage: theme_fish.sh <theme.json> [output]
#   output: ~/.config/fish/themes/axiom.theme
#   hookup: `fish_config theme choose axiom` in ~/.config/fish/config.fish (fish 4.3+)
#   reload: new shells
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/fish/themes/axiom.theme}"
load_theme "$1"
export_theme_colors
readable_text_colors
# fish takes colors as rrggbb
map_theme_colors hex
render_template "$SCRIPT_DIR/templates/fish_template.theme" "$OUTPUT_FILE"
