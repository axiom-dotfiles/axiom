#!/usr/bin/env bash
#
# Quickshell theme -> browser colors for Firefox and its forks (templates/firefox_template.css).
#
# Usage: theme_firefox.sh <theme.json> [output]
#   output: chrome/axiom.css in every profile the x-profiles profiles.ini files
#           list (Firefox, LibreWolf, Zen, Floorp, Waterfox; native and Flatpak)
#   hookup: `@import url("axiom.css");` atop each chrome/userChrome.css, and
#           toolkit.legacyUserProfileCustomizations.stylesheets in each user.js
#   reload: each browser's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 10 "$@"
require_cmds jq envsubst python3

if [ $# -ge 2 ]; then
    TARGETS=("$2")
else
    # The profiles the hookup sets up (one list, in the schema)
    mapfile -t PROFILES < <(python3 "$SCRIPT_DIR/integration_hookup.py" profiles firefox)
    TARGETS=()
    for PROFILE in "${PROFILES[@]}"; do
        [ -n "$PROFILE" ] && TARGETS+=("$PROFILE/chrome/axiom.css")
    done
    if [ ${#TARGETS[@]} -eq 0 ]; then
        echo "Error: no Firefox, LibreWolf, Zen, Floorp or Waterfox profile found (start the browser once)." >&2
        exit 1
    fi
fi
load_theme "$1"
export_theme_colors
COLOR_SCHEME=$([[ "$THEME_VARIANT" == "light" ]] && echo light || echo dark)
export COLOR_SCHEME
for TARGET in "${TARGETS[@]}"; do
    render_template "$SCRIPT_DIR/templates/firefox_template.css" "$TARGET"
done
echo "🚀 Browsers pick up the colors on their next start."
