#!/usr/bin/env bash
#
# Quickshell theme -> Cava colors (templates/cava_template.conf).
#
# Usage: theme_cava.sh <theme.json> [output.conf]
#   output: ~/.config/cava/colors/axiom.conf
#   hookup: `include = ~/.config/cava/colors/axiom.conf` in ~/.config/cava/config
#           (a main config with it is created when there is none)
#   reload: running Cava instances reload their colors (SIGUSR2)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 9 "$@"
require_cmds jq envsubst

OUTPUT_FILE="${2:-$HOME/.config/cava/colors/axiom.conf}"
load_theme "$1"
export_theme_colors
map_theme_colors quote_color
if [[ "$THEME_VARIANT" == "dark" ]]; then
    export GRADIENT_COUNT=8 GRADIENT_7="$BASE08" GRADIENT_8="$ACCENT_ALT"
else
    export GRADIENT_COUNT=6 GRADIENT_7="" GRADIENT_8=""
fi
render_template "$SCRIPT_DIR/templates/cava_template.conf" "$OUTPUT_FILE"
[ $# -ge 2 ] || old_output_notice "$HOME/.config/cava/colors/wal-generated.conf" "$OUTPUT_FILE"

MAIN_CONFIG="$HOME/.config/cava/config"
if [ ! -e "$MAIN_CONFIG" ]; then
    write_atomic "$MAIN_CONFIG" <<CONF
# Main Cava configuration (created by axiom; yours to edit)
include = $OUTPUT_FILE

[general]
framerate = 60
autosens = 1
sensitivity = 100
bars = 0
bar_width = 2
bar_spacing = 1

[input]
method = pulse
source = auto

[output]
method = ncurses
channels = stereo
mono_option = average
CONF
    echo "📄 Created '$MAIN_CONFIG' including the colors"
fi

pkill -USR2 -x cava 2>/dev/null || true
