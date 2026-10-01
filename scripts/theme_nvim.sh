#!/usr/bin/env bash
#
# Quickshell theme -> Neovim palette file, read by ~/.config/nvim/lua/axiom_theme.lua.
#
# Usage: theme_nvim.sh <theme.json> [output.json]
#   output: $XDG_STATE_HOME/axiom/nvim-theme.json
#   hookup: the axiom_theme module in your Neovim config
#   reload: every running Neovim over its RPC socket
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq nvim

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${XDG_STATE_HOME:-$HOME/.local/state}/axiom/nvim-theme.json}"
load_theme "$INPUT_FILE"

# The file stem picks a native colorscheme on the nvim side; the palette is
# the mini.base16 fallback for themes it doesn't map, and the semantic colors
# (accent, borders, ...) are drawn on top of it. "text" holds the accents
# made readable against the background, for highlights that color text.
STEM="$(basename "$INPUT_FILE" .json)"
SEMANTIC_PAIRS=()
for KEY in "${!THEME_SEMANTIC[@]}"; do
    SEMANTIC_PAIRS+=("$KEY=${THEME_SEMANTIC[$KEY]}")
done
SEMANTIC_JSON=$(jq -n '[$ARGS.positional[] | capture("^(?<key>[^=]*)=(?<value>.*)$")] | from_entries' \
    --args "${SEMANTIC_PAIRS[@]}")
jq --arg stem "$STEM" --arg variant "$THEME_VARIANT" --argjson sem "$SEMANTIC_JSON" \
    --argjson min "$TERM_MIN_CONTRAST" "$READABLE_JQ"'{
    stem: $stem,
    name: (.name // $stem),
    variant: (if $variant == "light" then "light" else "dark" end),
    colors: (.colors // {}),
    semantic: $sem,
    text: ($sem.background as $bg | ["accent", "accentAlt"]
        | map(select($sem[.]) | {key: ., value: ($sem[.] | readable($bg; $min))}) | from_entries)
}' "$INPUT_FILE" | write_atomic "$OUTPUT_FILE"
echo "✅ Written to '$OUTPUT_FILE'"

RELOADED=0
for SOCKET in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*.0; do
    [ -S "$SOCKET" ] || continue
    # "true" only from an nvim that has the module and reloaded without error
    RESULT=$(timeout 2 nvim --server "$SOCKET" --remote-expr \
        'luaeval("select(1, pcall(function() require(\"axiom_theme\").reload() end))")' 2>/dev/null || true)
    if [[ "$RESULT" == "true" || "$RESULT" == "v:true" ]]; then
        RELOADED=$((RELOADED + 1))
    fi
done
echo "🚀 Reloaded $RELOADED Neovim instance(s) (the others lack axiom_theme)."
