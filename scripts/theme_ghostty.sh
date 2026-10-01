#!/usr/bin/env bash
#
# Quickshell theme -> Ghostty colors (templates/ghostty_template).
#
# Usage: theme_ghostty.sh <theme.json> [output]
#   output: ~/.config/ghostty/themes/axiom
#   hookup: `theme = axiom` in ~/.config/ghostty/config
#   reload: running Ghostty reloads its config (SIGUSR2, Ghostty 1.2+)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst ghostty

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/themes/axiom}"
load_theme "$1"
export_theme_colors
render_template "$SCRIPT_DIR/templates/ghostty_template" "$OUTPUT_FILE"

# SIGUSR2 only reloads from 1.2 on; before that it terminates Ghostty
VERSION=$(ghostty --version 2>/dev/null | sed -n "s/^Ghostty \([0-9][0-9.]*\).*/\1/p" | head -n1)
if [ -n "$VERSION" ] && version_at_least "$VERSION" 1.2; then
    pkill -USR2 -x ghostty 2>/dev/null || true
else
    echo "Ghostty ${VERSION:-(unknown version)} cannot reload on a signal: the colors apply to new windows."
fi
