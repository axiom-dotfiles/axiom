#!/usr/bin/env bash
#
# Quickshell theme -> Helix theme (templates/helix_template.toml).
#
# Usage: theme_helix.sh <theme.json> [output.toml]
#   output: ~/.config/helix/themes/axiom.toml
#   hookup: `theme = "axiom"` in ~/.config/helix/config.toml
#   reload: running Helix reloads its config (SIGUSR1, Helix 23.10+)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq envsubst
# Arch names the binary helix, most others hx
HELIX=$(require_any_cmd hx helix)

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/helix/themes/axiom.toml}"
load_theme "$1"
export_theme_colors
readable_text_colors
render_template "$SCRIPT_DIR/templates/helix_template.toml" "$OUTPUT_FILE"

# SIGUSR1 only reloads from 23.10 on; before that it terminates Helix
VERSION=$("$HELIX" --version 2>/dev/null | sed -n 's/^helix \([0-9][0-9.]*\).*/\1/p' | head -n1)
if [ -n "$VERSION" ] && version_at_least "$VERSION" 23.10; then
    pkill -USR1 -x hx 2>/dev/null || true
    pkill -USR1 -x helix 2>/dev/null || true
else
    echo "Helix ${VERSION:-(unknown version)} cannot reload on a signal: the theme applies on its next start."
fi
