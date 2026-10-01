#!/usr/bin/env bash
#
# Quickshell theme -> qt5ct / qt6ct color scheme.
#
# Usage: theme_qt.sh <theme.json> [output.conf]
#   output: ~/.config/qt5ct/colors/axiom.conf and ~/.config/qt6ct/colors/axiom.conf (each tool that is installed)
#   hookup: in qt5ct/qt6ct, Palette: Custom, color scheme "axiom" (needs QT_QPA_PLATFORMTHEME=qt5ct / qt6ct)
#   reload: each Qt app's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq

if [ $# -ge 2 ]; then
    OUTPUTS=("$2")
else
    OUTPUTS=()
    for TOOL in qt5ct qt6ct; do
        command -v "$TOOL" &>/dev/null && OUTPUTS+=("${XDG_CONFIG_HOME:-$HOME/.config}/$TOOL/colors/axiom.conf")
    done
    if [ ${#OUTPUTS[@]} -eq 0 ]; then
        echo "Error: neither 'qt5ct' nor 'qt6ct' is installed." >&2
        exit 1
    fi
fi
load_theme "$1"
export_theme_colors

# #aarrggbb, as qt*ct writes them
argb() { echo "#ff${1#\#}"; }
# QPalette roles in order: WindowText Button Light Midlight Dark Mid Text
# BrightText ButtonText Base Window Shadow Highlight HighlightedText Link
# LinkVisited AlternateBase NoRole ToolTipBase ToolTipText PlaceholderText
palette_row() {
    local text="$1"
    local roles=(
        "$(argb "$text")" "$(argb "$BACKGROUND_ALT")" "$(argb "$BACKGROUND_HIGHLIGHT")" "$(argb "$BACKGROUND_HIGHLIGHT")"
        "$(argb "$BORDER")" "$(argb "$BORDER")" "$(argb "$text")"
        "$(argb "$FOREGROUND_HIGHLIGHT")" "$(argb "$text")" "$(argb "$BACKGROUND_ALT")" "$(argb "$BACKGROUND")" "#ff000000"
        "$(argb "$ACCENT")" "$(argb "$BACKGROUND")" "$(argb "$ACCENT")"
        "$(argb "$ACCENT_ALT")" "$(argb "$BACKGROUND_HIGHLIGHT")" "$(argb "$text")" "$(argb "$BACKGROUND_ALT")" "$(argb "$FOREGROUND")" "#80${FOREGROUND#\#}"
    )
    local IFS=,
    echo "${roles[*]}" | sed 's/,/, /g'
}
for OUTPUT in "${OUTPUTS[@]}"; do
    {
        echo "[ColorScheme]"
        echo "active_colors=$(palette_row "$FOREGROUND")"
        echo "disabled_colors=$(palette_row "$FOREGROUND_INACTIVE")"
        echo "inactive_colors=$(palette_row "$FOREGROUND")"
    } | write_atomic "$OUTPUT"
    echo "✅ Written to '$OUTPUT'"
done
