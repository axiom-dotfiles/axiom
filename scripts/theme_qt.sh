#!/usr/bin/env bash
#
# Quickshell theme -> qt5ct / qt6ct color scheme, and a KDE color scheme.
#
# Usage: theme_qt.sh <theme.json> [output_dir]
#   output: ~/.config/qt5ct/colors/axiom.conf and ~/.config/qt6ct/colors/axiom.conf (each tool that is installed),
#           ~/.local/share/color-schemes/Axiom.colors (KDE apps; into output_dir: axiom.conf and Axiom.colors)
#   hookup: in qt5ct/qt6ct, Palette: Custom, color scheme "axiom" (needs QT_QPA_PLATFORMTHEME=qt5ct, which
#           axiom's managed session sets); ColorScheme=Axiom in kdeglobals' [General], after which its
#           color groups are kept a copy of Axiom.colors (as Plasma does)
#   reload: each Qt app's next start (KDE apps are told the palette changed)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 11 "$@"
require_cmds jq

if [ $# -ge 2 ]; then
    OUTPUTS=("$2/axiom.conf")
    SCHEME="$2/Axiom.colors"
else
    SCHEME="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes/Axiom.colors"
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

# The KDE color scheme: the same colors as r,g,b
kde_rgb() {
    local h="${1#\#}"
    [[ "$h" =~ ^[0-9a-fA-F]{6} ]] || { echo "$1"; return; }
    echo "$((16#${h:0:2})),$((16#${h:2:2})),$((16#${h:4:2}))"
}
map_theme_colors kde_rgb
render_template "$SCRIPT_DIR/templates/qt_template.colors" "$SCHEME"

# KDE apps outside Plasma read kdeglobals' copy of the scheme, not the
# file: once Apply has named it there, its groups are kept in step (only
# the keys the scheme sets; the rest of kdeglobals stays as it is)
KDEGLOBALS="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
[ $# -lt 2 ] && [ -f "$KDEGLOBALS" ] || exit 0
SELECTED=$(awk '/^\[/ { general = ($0 == "[General]"); next }
    general && /^ColorScheme[ \t]*=/ { sub(/^[^=]*=[ \t]*/, ""); value = $0 }
    END { print value }' "$KDEGLOBALS")
[ "$SELECTED" == "Axiom" ] || exit 0
REAL="$(realpath -m "$KDEGLOBALS")"
if [ ! -w "$REAL" ] || [ ! -w "$(dirname "$REAL")" ]; then
    warn "'$KDEGLOBALS' is '$REAL', which you can't change: KDE apps keep its colors."
    exit 0
fi
# The scheme's groups but [General]: each key of theirs replaced where it
# is, the ones missing added at the end of their group, and groups missing
# added at the end
# shellcheck disable=SC2016
NEW=$(awk '
    function flush(   i, k) {
        if (cur in groups)
            for (i = 1; i <= count[cur]; i++) {
                k = cur SUBSEP keys[cur, i]
                if (!(k in done)) { print line[k]; done[k] = 1 }
            }
    }
    function blank_lines() { for (; blanks > 0; blanks--) print "" }
    FNR == NR {
        if (/^\[.*\]$/) {
            g = ($0 == "[General]") ? "" : $0
            if (g != "" && !(g in groups)) { groups[g] = 1; order[++n] = g }
        } else if (g != "" && /^[A-Za-z]+=/) {
            k = substr($0, 1, index($0, "=") - 1)
            if (!((g SUBSEP k) in line)) keys[g, ++count[g]] = k
            line[g SUBSEP k] = $0
        }
        next
    }
    /^[ \t]*$/ { blanks++; next }
    /^\[/ { flush(); blank_lines(); cur = $0; present[cur] = 1; print; next }
    {
        blank_lines()
        if (cur in groups && index($0, "=") > 0) {
            k = cur SUBSEP substr($0, 1, index($0, "=") - 1)
            if (k in line) { print line[k]; done[k] = 1; next }
        }
        print
    }
    END {
        flush()
        for (i = 1; i <= n; i++) {
            if (order[i] in present) continue
            print ""
            print order[i]
            for (j = 1; j <= count[order[i]]; j++) print line[order[i] SUBSEP keys[order[i], j]]
        }
    }
' "$SCHEME" "$REAL")
if [ "$NEW" == "$(cat "$REAL")" ]; then
    echo "✅ '$KDEGLOBALS' already has these colors"
    exit 0
fi
printf '%s\n' "$NEW" | write_atomic "$REAL"
echo "✅ Colors written into '$KDEGLOBALS'"
# Running KDE apps re-read the palette (KGlobalSettings::PaletteChanged)
if command -v busctl &>/dev/null; then
    busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 0 0 &>/dev/null || true
fi
