#!/usr/bin/env bash
#
# Quickshell theme -> WezTerm colors (templates/wezterm_template.toml).
#
# Usage: theme_wezterm.sh <theme.json> [output]
#   output: ~/.config/wezterm/colors/axiom.toml
#   hookup: `config.color_scheme = "axiom"` in wezterm.lua
#   reload: on WezTerm's next config reload (Ctrl+Shift+R)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst wezterm

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/colors/axiom.toml}"
load_theme "$1"
export_theme_colors
render_template "$SCRIPT_DIR/templates/wezterm_template.toml" "$OUTPUT_FILE"
