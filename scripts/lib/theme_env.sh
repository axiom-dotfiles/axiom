# shellcheck shell=bash
# Shared by the theme_*.sh integrations (sourced, not run): dependency
# checks, argument handling, one jq pass over a Quickshell theme file and
# atomic writes.
#
#   source "$SCRIPT_DIR/lib/theme_env.sh"
#   usage_or_help 3 7 "$@"          # print header lines 3-7 and exit on no args / --help
#   require_cmds jq envsubst
#   load_theme "$INPUT_FILE"        # THEME_*, BASE00..BASE0F, THEME_SEMANTIC
#   export_theme_colors             # ACCENT, BACKGROUND_ALT, ..., ANSI_0..ANSI_15
#   render_template "$TEMPLATE" "$OUTPUT"
#
# Every script writes only its own axiom.* file and never edits a user's
# config (a missing main config may be created with the include).

THEME_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DEFAULTS_FILE="$THEME_LIB_DIR/../../config/json/theme-defaults.json"

# The script's header comment (lines FROM..TO) as usage, when called
# without arguments or with -h/--help
usage_or_help() {
    local from="$1" to="$2" script="${BASH_SOURCE[1]}"
    shift 2
    if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
        sed -n "${from},${to}p" "$script" | sed 's/^# \{0,1\}//'
        exit 1
    fi
}

# Every missing command is an error
require_cmds() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: '$cmd' is not installed." >&2
            exit 1
        fi
    done
}

# The first of the commands that is installed (for apps packaged under two
# names); none is an error
require_any_cmd() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" &>/dev/null; then
            echo "$cmd"
            return
        fi
    done
    echo "Error: none of '$*' is installed." >&2
    exit 1
}

# version_at_least HAVE WANT (dotted versions)
version_at_least() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]
}

# Problems the user should see: ThemeManager logs stderr lines starting
# with "Warning:" as warnings even when the script succeeds
warn() { echo "Warning: $*" >&2; }

# Output path's directory exists; template is present
prepare_output() {
    local template="$1" output="$2"
    if [ ! -f "$template" ]; then
        echo "Error: Template file not found at '$template'" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$output")"
}

declare -gA THEME_SEMANTIC=()

# Exports THEME_NAME/THEME_AUTHOR/THEME_VARIANT and BASE00..BASE0F (hex, as
# in the theme), and fills THEME_SEMANTIC[key] with each semantic color
# resolved through the palette. Keys the theme leaves out come from
# theme-defaults.json, as they do in the shell (config/Theme.qml).
load_theme() {
    local file="$1" key value defaults="$THEME_DEFAULTS_FILE"
    if [ ! -f "$file" ]; then
        echo "Error: Input file not found at '$file'" >&2
        exit 1
    fi
    [ -f "$defaults" ] || defaults=<(echo '{}')
    echo "🎨 Reading theme from '$file'..."
    local entries
    entries=$(jq -r --slurpfile d "$defaults" '
        ($d[0] // {}) as $def
        | (if .variant == "light" then "light" else "dark" end) as $v
        | (($def.colors // {}) + (.colors // {})) as $colors
        | ((($def.semantic // {})[$v] // {}) + (.semantic // {})) as $sem
        | (["NAME", (.name // "Unknown")], ["AUTHOR", (.author // "N/A")], ["VARIANT", (.variant // "unknown")] | "meta\t\(.[0])\t\(.[1])"),
          ($colors | to_entries[] | "base\t\(.key | ascii_upcase)\t\(.value)"),
          ($sem | to_entries[] | "sem\t\(.key)\t\($colors[.value] // .value)")
    ' "$file")
    while IFS=$'\t' read -r kind key value; do
        case "$kind" in
            meta) export "THEME_$key=$value" ;;
            base) export "$key=$value" ;;
            sem) THEME_SEMANTIC["$key"]="$value" ;;
        esac
    done <<< "$entries"
}

# theme_color KEY [FALLBACK]
theme_color() {
    local value="${THEME_SEMANTIC[$1]:-}"
    echo "${value:-${2:-}}"
}

# Minimum WCAG contrast against the background for colors used as text in a
# terminal: chromatic ANSI/semantic colors, and bright black (comments,
# autosuggestions), which is meant to stay dim
TERM_MIN_CONTRAST=4.5
TERM_MIN_CONTRAST_DIM=3.0

# jq: readable($bg; $min) on a "#rrggbb" string gives the color with at
# least $min contrast against $bg. The OKLCH hue is kept; lightness moves
# away from the background (chroma shrinking to stay in sRGB) only as far
# as needed, so colors that already pass come back unchanged.
# shellcheck disable=SC2016
READABLE_JQ='
def lin: if . <= 0.04045 then . / 12.92 else pow((. + 0.055) / 1.055; 2.4) end;
def gam: if . <= 0.0031308 then . * 12.92 else 1.055 * pow(.; 1 / 2.4) - 0.055 end;
def nib: if . >= 97 then . - 87 elif . >= 65 then . - 55 else . - 48 end;
def rgb: ltrimstr("#") | [.[0:2], .[2:4], .[4:6]] | map(explode | map(nib) | .[0] * 16 + .[1] | . / 255 | lin);
def hexof: "#" + (map(gam | if . < 0 then 0 elif . > 1 then 1 else . end | . * 255 | round
    | [(. / 16 | floor), (. % 16)] | map(if . < 10 then . + 48 else . + 87 end) | implode) | join(""));
def lum: 0.2126 * .[0] + 0.7152 * .[1] + 0.0722 * .[2];
def ratio($a; $b): if $a > $b then ($a + 0.05) / ($b + 0.05) else ($b + 0.05) / ($a + 0.05) end;
def lch: (map(if . < 0 then 0 else . end)) as [$r, $g, $b]
    | [0.4122214708 * $r + 0.5363325363 * $g + 0.0514459929 * $b,
       0.2119034982 * $r + 0.6806995451 * $g + 0.1073969566 * $b,
       0.0883024619 * $r + 0.2817188376 * $g + 0.6299787005 * $b] | map(cbrt) as [$l, $m, $s]
    | [0.2104542553 * $l + 0.7936177850 * $m - 0.0040720468 * $s,
       1.9779984951 * $l - 2.4285922050 * $m + 0.4505937099 * $s,
       0.0259040371 * $l + 0.7827717662 * $m - 0.8086757660 * $s] as [$L, $A, $B]
    | [$L, ($A * $A + $B * $B | sqrt), atan2($B; $A)];
def linof: . as [$L, $C, $h] | ($C * ($h | cos)) as $a | ($C * ($h | sin)) as $b
    | [$L + 0.3963377774 * $a + 0.2158037573 * $b,
       $L - 0.1055613458 * $a - 0.0638541728 * $b,
       $L - 0.0894841775 * $a - 1.2914855480 * $b] | map(. * . * .) as [$l, $m, $s]
    | [4.0767416621 * $l - 3.3077115913 * $m + 0.2309699292 * $s,
       -1.2684380046 * $l + 2.6097574011 * $m - 0.3413193965 * $s,
       -0.0041960863 * $l - 0.7034186147 * $m + 1.7076147010 * $s];
def ingamut: all(.[]; . >= -0.0001 and . <= 1.0001);
def fit: . as [$L, $C, $h] | [$L, $C, $h] | until((linof | ingamut) or .[1] < 0.001; .[1] *= 0.95) | linof;
def readable($bg; $min):
    if test("^#[0-9a-fA-F]{6}$") | not then . else
    ($bg | rgb | lum) as $bl | rgb as $c
    | if ratio($c | lum; $bl) >= $min then . else
      (if ($bl + 0.05) / 0.05 >= 1.05 / ($bl + 0.05) then -0.01 else 0.01 end) as $step
      | [($c | lch), $c] | until(ratio(.[1] | lum; $bl) >= $min or .[0][0] <= 0 or .[0][0] >= 1;
            .[0][0] += $step | .[1] = (.[0] | fit | hexof | rgb)) | .[1] | hexof end end;
'

# floor_colors BG MIN VAR...: re-exports each variable holding a color with
# at least MIN contrast against BG (one jq run for all of them)
floor_colors() {
    local bg="$1" min="$2" name value out
    shift 2
    [ $# -gt 0 ] || return 0
    local pairs=()
    for name in "$@"; do
        pairs+=("$name=${!name:-}")
    done
    out=$(jq -rn --arg bg "$bg" --argjson min "$min" "$READABLE_JQ"'
        $ARGS.positional[] | capture("^(?<k>[^=]*)=(?<v>.*)$")
        | "\(.k)\t\(.v | readable($bg; $min))"' --args "${pairs[@]}")
    while IFS=$'\t' read -r name value; do
        export "$name=$value"
    done <<< "$out"
}

# Every semantic color as an UPPER_SNAKE variable (backgroundAlt ->
# BACKGROUND_ALT), plus the terminal palette ANSI_0..ANSI_15 (base16 order).
# A light theme's black and white slots take its dark and light shades (a
# terminal's "black" is dark whatever the background), and the palette's
# colors are made readable against the background.
export_theme_colors() {
    local key name i base
    for key in "${!THEME_SEMANTIC[@]}"; do
        name=$(sed 's/\([A-Z]\)/_\1/g' <<< "$key" | tr '[:lower:]' '[:upper:]')
        export "$name=${THEME_SEMANTIC[$key]}"
    done
    local map=(00 08 0B 0A 0D 0E 0C 05 03 09 0B 0A 0D 0E 0C 07)
    if [[ "${THEME_VARIANT:-}" == "light" ]]; then
        map=(05 08 0B 0A 0D 0E 0C 02 03 09 0B 0A 0D 0E 0C 01)
    fi
    for i in "${!map[@]}"; do
        base="BASE${map[$i]}"
        export "ANSI_$i=${!base:-}"
    done
    local bg="${BACKGROUND:-${BASE00:-}}"
    floor_colors "$bg" "$TERM_MIN_CONTRAST" ANSI_{1..6} ANSI_{9..14}
    floor_colors "$bg" "$TERM_MIN_CONTRAST_DIM" ANSI_8
}

# The semantic colors terminal apps draw text in, made readable against the
# background like the ANSI palette (after export_theme_colors; not for GTK,
# Qt or hyprlock, where they're accents)
readable_text_colors() {
    floor_colors "${BACKGROUND:-${BASE00:-}}" "$TERM_MIN_CONTRAST" \
        RED GREEN YELLOW BLUE MAGENTA CYAN ORANGE ERROR WARNING SUCCESS INFO
}

# Re-exports each named variable through a formatter: map_vars hex FOO BAR
map_vars() {
    local fn="$1" var
    shift
    for var in "$@"; do
        export "$var=$("$fn" "${!var:-}")"
    done
}

# The variables export_theme_colors sets (plus BASE00..BASE0F), for map_vars
# (map_theme_colors)
theme_color_vars() {
    compgen -v | grep -E '^(BASE0[0-9A-F]|ANSI_[0-9]+)$'
    local key
    for key in "${!THEME_SEMANTIC[@]}"; do
        sed 's/\([A-Z]\)/_\1/g' <<< "$key" | tr '[:lower:]' '[:upper:]'
    done
}

# map_vars over every theme color variable: map_theme_colors hex
map_theme_colors() {
    local names
    mapfile -t names < <(theme_color_vars)
    map_vars "$1" "${names[@]}"
}

# "#rrggbb" in quotes, for YAML/INI values ('""' when empty)
quote_color() {
    local color="${1#\#}"
    if [ -z "$color" ] || [ "$color" == "null" ]; then
        echo '""'
    else
        echo "\"#${color}\""
    fi
}

# rrggbb, no '#'
hex() { echo "${1#\#}"; }

# Stdin to OUTPUT atomically (a temp file beside it, then mv); an empty
# result is an error and leaves OUTPUT as it was
write_atomic() {
    local output="$1" tmp
    mkdir -p "$(dirname "$output")"
    tmp="$(mktemp "$output.XXXXXX")"
    cat > "$tmp"
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        echo "Error: Failed to generate '$output'." >&2
        exit 1
    fi
    chmod 644 "$tmp"
    mv "$tmp" "$output"
}

# render_template TEMPLATE OUTPUT [SHELL_FORMAT]: envsubst, written
# atomically. SHELL_FORMAT limits envsubst to those variables (for
# templates with $vars of their own).
render_template() {
    local template="$1" output="$2" name
    prepare_output "$template" "$output"
    # envsubst writes an unset variable as "", which would quietly drop a color
    while read -r name; do
        [[ -v "$name" ]] || warn "$(basename "$template") uses \${$name}, which nothing sets"
    done < <(grep -o '\${[A-Za-z_][A-Za-z0-9_]*}' "$template" | tr -d '${}' | sort -u)
    if [ $# -ge 3 ]; then
        envsubst "$3" < "$template" | write_atomic "$output"
    else
        envsubst < "$template" | write_atomic "$output"
    fi
    echo "✅ Written to '$output'"
}

# old_output_notice OLD NEW: the output used to be OLD; say where it went
# (never deletes OLD or edits the config that includes it)
old_output_notice() {
    local old="$1" new="$2"
    if [ -e "$old" ]; then
        warn "the theme file moved from '$old' to '$new': point your config at the new file, then delete the old one."
    fi
}
