#!/usr/bin/env bash
#
# Quickshell theme -> zathura colors (templates/zathura_template).
#
# Usage: theme_zathura.sh <theme.json> [output]
#   output: ~/.config/zathura/axiom
#   hookup: `include axiom` in ~/.config/zathura/zathurarc
#   reload: running zathura re-reads its config (D-Bus SourceConfig)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/zathura/axiom}"
load_theme "$1"
export_theme_colors
render_template "$SCRIPT_DIR/templates/zathura_template" "$OUTPUT_FILE"

# Only for the real config: each running zathura (one D-Bus name per
# process) sources its zathurarc again
if [ $# -lt 2 ] && command -v busctl &>/dev/null; then
    busctl --user list --no-legend 2>/dev/null | awk '$1 ~ /^org\.pwmt\.zathura\.PID-/ { print $1 }' |
        while read -r NAME; do
            busctl --user call "$NAME" /org/pwmt/zathura org.pwmt.zathura SourceConfig &>/dev/null || true
        done
fi
