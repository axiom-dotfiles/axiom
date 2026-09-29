#!/usr/bin/env bash
#
# Quickshell theme -> Yazi flavor (templates/yazi_template.toml).
#
# Usage: theme_yazi.sh <theme.json> [output.toml]
#   output: ~/.config/yazi/flavors/axiom.yazi/flavor.toml
#   hookup: `[flavor]` with `dark = "axiom"` and `light = "axiom"` in ~/.config/yazi/theme.toml
#   reload: Yazi's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst yazi

OUTPUT_FILE="${2:-$HOME/.config/yazi/flavors/axiom.yazi/flavor.toml}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/yazi_template.toml" "$OUTPUT_FILE"
