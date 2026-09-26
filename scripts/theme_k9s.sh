#!/usr/bin/env bash
#
# Quickshell theme -> K9s skin (templates/k9s_template.yaml).
#
# Usage: theme_k9s.sh <theme.json> [output.yaml]
#   output: ~/.config/k9s/skins/axiom.yaml
#   hookup: `k9s.ui.skin: axiom` in ~/.config/k9s/config.yaml
#   reload: K9s watches its skin file
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst

OUTPUT_FILE="${2:-$HOME/.config/k9s/skins/axiom.yaml}"
load_theme "$1"
export_theme_colors
map_theme_colors quote_color
render_template "$SCRIPT_DIR/templates/k9s_template.yaml" "$OUTPUT_FILE"
[ $# -ge 2 ] || old_output_notice "$HOME/.config/k9s/skins/wal-generated.yaml" "$OUTPUT_FILE"
