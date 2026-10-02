#!/usr/bin/env bash
#
# Quickshell theme -> a Vencord theme for Vesktop (templates/vesktop_template.css).
#
# Usage: theme_vesktop.sh <theme.json> [output]
#   output: axiom.theme.css in the themes/ folder of each of vesktop, Vencord, equibop, Equicord
#           and the Flatpak Vesktop (~/.var/app/dev.vencord.Vesktop) that has run
#   hookup: switch on axiom.theme.css under Settings → Vencord → Themes
#   reload: live (the client watches its themes folder)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 9 "$@"
require_cmds jq envsubst

if [ $# -ge 2 ]; then
    TARGETS=("$2")
else
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
    TARGETS=()
    # The Flathub Vesktop keeps its config in its sandbox's own XDG_CONFIG_HOME
    for DIR in "$CONFIG_DIR"/{vesktop,Vencord,equibop,Equicord} "$HOME/.var/app/dev.vencord.Vesktop/config/vesktop"; do
        [ -d "$DIR" ] && TARGETS+=("$DIR/themes/axiom.theme.css")
    done
    if [ ${#TARGETS[@]} -eq 0 ]; then
        echo "Error: no Vesktop (native or Flatpak), Vencord, Equibop or Equicord config found (start Vesktop once)." >&2
        exit 1
    fi
fi
load_theme "$1"
export_theme_colors
readable_text_colors
for TARGET in "${TARGETS[@]}"; do
    render_template "$SCRIPT_DIR/templates/vesktop_template.css" "$TARGET"
done
