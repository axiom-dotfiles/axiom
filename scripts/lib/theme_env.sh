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

# Every semantic color as an UPPER_SNAKE variable (backgroundAlt ->
# BACKGROUND_ALT), plus the terminal palette ANSI_0..ANSI_15 (base16 order)
export_theme_colors() {
    local key name i base
    for key in "${!THEME_SEMANTIC[@]}"; do
        name=$(sed 's/\([A-Z]\)/_\1/g' <<< "$key" | tr '[:lower:]' '[:upper:]')
        export "$name=${THEME_SEMANTIC[$key]}"
    done
    local map=(00 08 0B 0A 0D 0E 0C 05 03 09 0B 0A 0D 0E 0C 07)
    for i in "${!map[@]}"; do
        base="BASE${map[$i]}"
        export "ANSI_$i=${!base:-}"
    done
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
