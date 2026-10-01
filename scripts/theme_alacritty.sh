#!/usr/bin/env bash
#
# Quickshell theme -> Alacritty colors (templates/alacritty_template.toml).
#
# Usage: theme_alacritty.sh <theme.json> [output]
#   output: ~/.config/alacritty/axiom.toml
#   hookup: `import = ["~/.config/alacritty/axiom.toml"]` under [general] in alacritty.toml
#   reload: Alacritty watches imported files (live_config_reload, on by default)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst alacritty

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/axiom.toml}"
load_theme "$1"
export_theme_colors
render_template "$SCRIPT_DIR/templates/alacritty_template.toml" "$OUTPUT_FILE"
