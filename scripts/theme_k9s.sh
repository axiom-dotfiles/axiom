#!/usr/bin/env bash

#
# Quickshell Theme to K9s Skin Converter (Template Version)
#
# This script reads a Quickshell theme file, exports color variables,
# and uses envsubst with a template to generate K9s skin YAML.
#
# Dependencies:
#   - jq:    For parsing the input JSON file.
#   - gettext-base: For envsubst command.
#
# Usage:
#   ./theme-to-k9s.sh <input_file.json> [output_file.yaml]
#

# --- Script Setup ---
set -e
set -u
set -o pipefail

# Change to script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to use this script." >&2
    exit 1
fi
if ! command -v envsubst &> /dev/null; then
    echo "Error: 'envsubst' is not installed. Please install gettext-base package." >&2
    exit 1
fi

# --- Functions ---
usage() {
    cat <<EOF
Usage: $(basename "$0") <input_file.json> [output_file.yaml]

Converts a Quickshell JSON theme to a K9s skin YAML file.

Arguments:
  input_file.json   Path to the input Quickshell theme JSON file. (Required)
  output_file.yaml  Path for the generated K9s skin file. (Optional)
                    Defaults to: ~/.config/k9s/skins/wal-generated.yaml
EOF
    exit 1
}

# Helper to format colors for YAML (ensure quotes and # prefix)
format_color() {
    local color="$1"
    if [ -z "$color" ] || [ "$color" == "null" ]; then
        echo '""'
        return
    fi
    
    # Remove existing # if present
    color="${color#\#}"
    # Add # and quotes
    echo "\"#${color}\""
}

# --- Argument Parsing & Validation ---
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

INPUT_FILE="$1"
DEFAULT_OUTPUT_PATH="$HOME/.config/k9s/skins/wal-generated.yaml"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_PATH}"
TEMPLATE_FILE="$SCRIPT_DIR/templates/k9s_template.yaml"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at '$INPUT_FILE'" >&2
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at '$TEMPLATE_FILE'" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---

echo "🎨 Reading theme from '$INPUT_FILE'..."

# Helper function to resolve color references
resolve_color() {
    local key="$1"
    local value=$(echo "$THEME_JSON" | jq -r ".semantic.$key // empty")
    
    if [ -z "$value" ] || [ "$value" == "null" ]; then
        echo ""
        return
    fi
    
    # Check if it's a reference to base16 palette
    if echo "$THEME_JSON" | jq -e ".colors.$value" &>/dev/null; then
        echo "$THEME_JSON" | jq -r ".colors.$value"
    else
        echo "$value"
    fi
}

# Read the entire JSON into a variable
THEME_JSON=$(cat "$INPUT_FILE")

# Export theme metadata
export THEME_NAME=$(echo "$THEME_JSON" | jq -r '.name // "Unknown"')
export THEME_AUTHOR=$(echo "$THEME_JSON" | jq -r '.author // "N/A"')
export THEME_VARIANT=$(echo "$THEME_JSON" | jq -r '.variant // "unknown"')

# Export base16 colors (formatted for YAML)
export BASE00=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base00')")
export BASE01=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base01')")
export BASE02=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base02')")
export BASE03=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base03')")
export BASE04=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base04')")
export BASE05=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base05')")
export BASE06=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base06')")
export BASE07=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base07')")
export BASE08=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base08')")
export BASE09=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base09')")
export BASE0A=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0A')")
export BASE0B=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0B')")
export BASE0C=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0C')")
export BASE0D=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0D')")
export BASE0E=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0E')")
export BASE0F=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0F')")

# Export semantic colors (with resolution and formatting)
export FOREGROUND=$(format_color "$(resolve_color "foreground")")
export BACKGROUND=$(format_color "$(resolve_color "background")")
export BACKGROUND_ALT=$(format_color "$(resolve_color "backgroundAlt")")
export BACKGROUND_ALT2=$(format_color "$(resolve_color "backgroundAlt2")")
export FOREGROUND_INACTIVE=$(format_color "$(resolve_color "foregroundInactive")")
export ACCENT=$(format_color "$(resolve_color "accent")")
export ACCENT_SECONDARY=$(format_color "$(resolve_color "accentSecondary")")
export BORDER=$(format_color "$(resolve_color "border")")
export BORDER_FOCUS=$(format_color "$(resolve_color "borderFocus")")
export WARNING=$(format_color "$(resolve_color "warning")")
export ERROR=$(format_color "$(resolve_color "error")")
export SUCCESS=$(format_color "$(resolve_color "success")")

# Default fallbacks if semantic colors are missing
: "${FOREGROUND:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base05')")}"
: "${BACKGROUND:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base00')")}"
: "${BACKGROUND_ALT:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base01')")}"
: "${BACKGROUND_ALT2:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base03')")}"
: "${FOREGROUND_INACTIVE:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base04')")}"
: "${ACCENT:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0D')")}"
: "${ACCENT_SECONDARY:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0E')")}"
: "${BORDER:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base02')")}"
: "${BORDER_FOCUS:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0D')")}"
: "${WARNING:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0A')")}"
: "${ERROR:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base08')")}"
: "${SUCCESS:=$(format_color "$(echo "$THEME_JSON" | jq -r '.colors.base0B')")}"

echo "📝 Generating K9s skin from template..."
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "Error: Failed to generate skin file." >&2
    exit 1
fi

echo "✅ K9s skin successfully generated at '$OUTPUT_FILE'!"
