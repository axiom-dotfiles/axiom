#!/usr/bin/env bash
#
# Quickshell theme -> Kitty colors (templates/kitty_template.conf).
#
# Usage: theme_kitty.sh <theme.json> [output.conf]
#   output: ~/.config/kitty/axiom.conf
#   hookup: `include axiom.conf` in kitty.conf
#   reload: every running Kitty that allows remote control (allow_remote_control yes)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst kitty

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty/axiom.conf}"
load_theme "$1"
export_theme_colors
render_template "$SCRIPT_DIR/templates/kitty_template.conf" "$OUTPUT_FILE"
[ $# -ge 2 ] || old_output_notice "${XDG_CONFIG_HOME:-$HOME/.config}/kitty/theme/generated.conf" "$OUTPUT_FILE"

RELOADED=0
for SOCKET in /tmp/kitty-*; do
    [ -S "$SOCKET" ] || continue
    if kitty @ --to "unix:$SOCKET" set-colors --all --configured "$OUTPUT_FILE" 2>/dev/null; then
        RELOADED=$((RELOADED + 1))
    fi
done
echo "🚀 Reloaded $RELOADED Kitty instance(s) (the others need allow_remote_control)."
