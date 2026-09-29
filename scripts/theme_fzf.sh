#!/usr/bin/env bash
#
# Quickshell theme -> fzf colors (an options file of --color flags).
#
# Usage: theme_fzf.sh <theme.json> [output]
#   output: $XDG_STATE_HOME/axiom/fzf-colors
#   hookup: `export FZF_DEFAULT_OPTS_FILE="$XDG_STATE_HOME/axiom/fzf-colors"` (fzf 0.49+) in your shell profile
#   reload: fzf's next run
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq fzf

OUTPUT_FILE="${2:-${XDG_STATE_HOME:-$HOME/.local/state}/axiom/fzf-colors}"
load_theme "$1"
export_theme_colors
readable_text_colors

COLORS=(
    "fg:$FOREGROUND" "bg:$BACKGROUND" "hl:$ACCENT"
    "fg+:$FOREGROUND_HIGHLIGHT" "bg+:$BACKGROUND_HIGHLIGHT" "hl+:$ACCENT"
    "info:$INFO" "marker:$SUCCESS" "prompt:$ACCENT" "spinner:$ACCENT_ALT"
    "pointer:$ACCENT" "header:$FOREGROUND_ALT" "border:$BORDER"
    "label:$FOREGROUND_ALT" "query:$FOREGROUND" "gutter:$BACKGROUND"
)
{
    echo "--color=$(IFS=,; echo "${COLORS[*]}")"
} | write_atomic "$OUTPUT_FILE"
echo "✅ Written to '$OUTPUT_FILE'"
