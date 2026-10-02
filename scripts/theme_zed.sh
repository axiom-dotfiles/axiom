#!/usr/bin/env bash
#
# Quickshell theme -> Zed theme family (one "Axiom" theme, following light/dark).
#
# Usage: theme_zed.sh <theme.json> [output.json]
#   output: ~/.config/zed/themes/axiom.json
#   hookup: `"theme": "Axiom"` in ~/.config/zed/settings.json
#   reload: Zed watches its themes folder and reloads the theme by itself
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 8 "$@"
require_cmds jq

OUTPUT_FILE="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/zed/themes/axiom.json}"
load_theme "$1"
export_theme_colors
readable_text_colors
APPEARANCE=$([[ "$THEME_VARIANT" == "light" ]] && echo light || echo dark)

# Every exported color, for jq ($c.ACCENT, $c.ANSI_0, ...)
COLORS_JSON=$(for var in $(theme_color_vars); do printf '%s\t%s\n' "$var" "${!var}"; done |
    jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add')

jq -n --argjson c "$COLORS_JSON" --arg name "$THEME_NAME" --arg appearance "$APPEARANCE" '
def status($k; $color): { ($k): $color, ($k + ".background"): ($color + "26"), ($k + ".border"): $color };
def fg($color): { color: $color };
{
    "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
    name: "Axiom",
    author: "axiom (generated from the \($name) theme; rewritten on every theme change)",
    themes: [{
        name: "Axiom",
        appearance: $appearance,
        style: ({
            "background": $c.BACKGROUND_ALT,
            "surface.background": $c.BACKGROUND_ALT,
            "elevated_surface.background": $c.BACKGROUND_ALT,
            "panel.background": $c.BACKGROUND_ALT,
            "panel.focused_border": $c.BORDER_FOCUS,
            "pane.focused_border": $c.BORDER_FOCUS,
            "border": $c.BACKGROUND_HIGHLIGHT,
            "border.variant": $c.BACKGROUND_HIGHLIGHT,
            "border.focused": $c.BORDER_FOCUS,
            "border.selected": $c.ACCENT,
            "border.transparent": "#00000000",
            "border.disabled": $c.BACKGROUND_HIGHLIGHT,
            "element.background": $c.BACKGROUND_HIGHLIGHT,
            "element.hover": $c.BACKGROUND_HIGHLIGHT,
            "element.active": ($c.ACCENT + "40"),
            "element.selected": ($c.ACCENT + "33"),
            "element.disabled": $c.BACKGROUND_ALT,
            "ghost_element.background": "#00000000",
            "ghost_element.hover": $c.BACKGROUND_HIGHLIGHT,
            "ghost_element.active": ($c.ACCENT + "40"),
            "ghost_element.selected": ($c.ACCENT + "33"),
            "ghost_element.disabled": "#00000000",
            "drop_target.background": ($c.ACCENT + "33"),
            "text": $c.FOREGROUND,
            "text.muted": $c.FOREGROUND_ALT,
            "text.placeholder": $c.FOREGROUND_INACTIVE,
            "text.disabled": $c.FOREGROUND_INACTIVE,
            "text.accent": $c.ACCENT,
            "icon": $c.FOREGROUND,
            "icon.muted": $c.FOREGROUND_ALT,
            "icon.disabled": $c.FOREGROUND_INACTIVE,
            "icon.placeholder": $c.FOREGROUND_INACTIVE,
            "icon.accent": $c.ACCENT,
            "link_text.hover": $c.ACCENT,
            "status_bar.background": $c.BACKGROUND_ALT,
            "title_bar.background": $c.BACKGROUND_ALT,
            "title_bar.inactive_background": $c.BACKGROUND_ALT,
            "toolbar.background": $c.BACKGROUND,
            "tab_bar.background": $c.BACKGROUND_ALT,
            "tab.inactive_background": $c.BACKGROUND_ALT,
            "tab.active_background": $c.BACKGROUND,
            "search.match_background": ($c.WARNING + "55"),
            "scrollbar.thumb.background": ($c.FOREGROUND_INACTIVE + "66"),
            "scrollbar.thumb.hover_background": $c.FOREGROUND_INACTIVE,
            "scrollbar.thumb.border": "#00000000",
            "scrollbar.track.background": "#00000000",
            "scrollbar.track.border": "#00000000",
            "editor.foreground": $c.FOREGROUND,
            "editor.background": $c.BACKGROUND,
            "editor.gutter.background": $c.BACKGROUND,
            "editor.subheader.background": $c.BACKGROUND_ALT,
            "editor.active_line.background": ($c.BACKGROUND_HIGHLIGHT + "80"),
            "editor.highlighted_line.background": $c.BACKGROUND_HIGHLIGHT,
            "editor.line_number": $c.FOREGROUND_INACTIVE,
            "editor.active_line_number": $c.ACCENT,
            "editor.invisible": $c.BACKGROUND_HIGHLIGHT,
            "editor.wrap_guide": $c.BACKGROUND_HIGHLIGHT,
            "editor.active_wrap_guide": $c.FOREGROUND_INACTIVE,
            "editor.indent_guide": $c.BACKGROUND_HIGHLIGHT,
            "editor.indent_guide_active": $c.FOREGROUND_INACTIVE,
            "editor.document_highlight.read_background": ($c.ACCENT + "26"),
            "editor.document_highlight.write_background": ($c.ACCENT + "40"),
            "terminal.background": $c.BACKGROUND,
            "terminal.foreground": $c.FOREGROUND,
            "terminal.bright_foreground": $c.FOREGROUND_HIGHLIGHT,
            "terminal.dim_foreground": $c.FOREGROUND_ALT,
            "terminal.ansi.black": $c.ANSI_0, "terminal.ansi.red": $c.ANSI_1,
            "terminal.ansi.green": $c.ANSI_2, "terminal.ansi.yellow": $c.ANSI_3,
            "terminal.ansi.blue": $c.ANSI_4, "terminal.ansi.magenta": $c.ANSI_5,
            "terminal.ansi.cyan": $c.ANSI_6, "terminal.ansi.white": $c.ANSI_7,
            "terminal.ansi.bright_black": $c.ANSI_8, "terminal.ansi.bright_red": $c.ANSI_9,
            "terminal.ansi.bright_green": $c.ANSI_10, "terminal.ansi.bright_yellow": $c.ANSI_11,
            "terminal.ansi.bright_blue": $c.ANSI_12, "terminal.ansi.bright_magenta": $c.ANSI_13,
            "terminal.ansi.bright_cyan": $c.ANSI_14, "terminal.ansi.bright_white": $c.ANSI_15,
            "players": [
                { cursor: $c.ACCENT, background: $c.ACCENT, selection: ($c.ACCENT + "40") },
                { cursor: $c.MAGENTA, background: $c.MAGENTA, selection: ($c.MAGENTA + "40") },
                { cursor: $c.GREEN, background: $c.GREEN, selection: ($c.GREEN + "40") },
                { cursor: $c.ORANGE, background: $c.ORANGE, selection: ($c.ORANGE + "40") },
                { cursor: $c.CYAN, background: $c.CYAN, selection: ($c.CYAN + "40") },
                { cursor: $c.RED, background: $c.RED, selection: ($c.RED + "40") },
                { cursor: $c.YELLOW, background: $c.YELLOW, selection: ($c.YELLOW + "40") }
            ],
            "syntax": {
                "attribute": fg($c.YELLOW),
                "boolean": fg($c.ORANGE),
                "comment": { color: $c.FOREGROUND_INACTIVE, font_style: "italic" },
                "comment.doc": { color: $c.FOREGROUND_ALT, font_style: "italic" },
                "constant": fg($c.ORANGE),
                "constructor": fg($c.YELLOW),
                "embedded": fg($c.FOREGROUND),
                "emphasis": { color: $c.FOREGROUND, font_style: "italic" },
                "emphasis.strong": { color: $c.FOREGROUND, font_weight: 700 },
                "enum": fg($c.YELLOW),
                "function": fg($c.BLUE),
                "hint": { color: $c.FOREGROUND_INACTIVE, font_style: "italic" },
                "keyword": fg($c.MAGENTA),
                "label": fg($c.ACCENT),
                "link_text": { color: $c.BLUE, font_style: "italic" },
                "link_uri": fg($c.CYAN),
                "number": fg($c.ORANGE),
                "operator": fg($c.FOREGROUND_ALT),
                "predictive": { color: $c.FOREGROUND_INACTIVE, font_style: "italic" },
                "preproc": fg($c.MAGENTA),
                "primary": fg($c.FOREGROUND),
                "property": fg($c.RED),
                "punctuation": fg($c.FOREGROUND_ALT),
                "punctuation.bracket": fg($c.FOREGROUND_ALT),
                "punctuation.delimiter": fg($c.FOREGROUND_ALT),
                "punctuation.list_marker": fg($c.RED),
                "punctuation.special": fg($c.CYAN),
                "string": fg($c.GREEN),
                "string.escape": fg($c.CYAN),
                "string.regex": fg($c.CYAN),
                "string.special": fg($c.CYAN),
                "string.special.symbol": fg($c.ORANGE),
                "tag": fg($c.RED),
                "text.literal": fg($c.GREEN),
                "title": { color: $c.ACCENT, font_weight: 700 },
                "type": fg($c.YELLOW),
                "variable": fg($c.FOREGROUND),
                "variable.special": fg($c.RED),
                "variant": fg($c.CYAN)
            }
        }
        + status("conflict"; $c.WARNING) + status("created"; $c.SUCCESS) + status("deleted"; $c.ERROR)
        + status("error"; $c.ERROR) + status("hidden"; $c.FOREGROUND_INACTIVE) + status("hint"; $c.FOREGROUND_INACTIVE)
        + status("ignored"; $c.FOREGROUND_INACTIVE) + status("info"; $c.INFO) + status("modified"; $c.WARNING)
        + status("predictive"; $c.FOREGROUND_INACTIVE) + status("renamed"; $c.INFO) + status("success"; $c.SUCCESS)
        + status("unreachable"; $c.FOREGROUND_INACTIVE) + status("warning"; $c.WARNING))
    }]
}' | write_atomic "$OUTPUT_FILE"
echo "✅ Written to '$OUTPUT_FILE'"
