#!/usr/bin/env bash
#
# Quickshell theme -> lazygit theme (templates/lazygit_template.yml).
#
# Usage: theme_lazygit.sh <theme.json> [output]
#   output: ~/.config/lazygit/axiom.yml
#   hookup: add it to LG_CONFIG_FILE, e.g. `export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/axiom.yml"`
#   reload: lazygit's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst lazygit

OUTPUT_FILE="${2:-$HOME/.config/lazygit/axiom.yml}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/lazygit_template.yml" "$OUTPUT_FILE"
