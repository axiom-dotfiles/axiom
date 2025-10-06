#!/usr/bin/env bash

#
# Quickshell Theme to Kitty Config Converter & Reloader (Template Version)
#
# This script reads a Quickshell theme file, exports color variables,
# and uses envsubst with a template to generate Kitty configuration.
#
# Dependencies:
#   - jq:     For parsing the input JSON file.
#   - kitty:  The script needs to be able to call `kitty @`.
#   - gettext-base: For envsubst command.
#
# Usage:
#   ./theme-to-kitty.sh <input_file.json> [output_file.conf]
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
if ! command -v kitty &> /dev/null; then
    echo "Error: 'kitty' is not installed. Please install it to use this script." >&2
    exit 1
fi
if ! command -v envsubst &> /dev/null; then
    echo "Error: 'envsubst' is not installed. Please install gettext-base package." >&2
    exit 1
fi

# --- Functions ---
usage() {
    cat <<EOF
Usage: $(basename "$0") <input_file.json> [output_file.conf]

Converts a Quickshell JSON theme to a Kitty configuration file and reloads all
running Kitty instances.

Arguments:
  input_file.json   Path to the input Quickshell theme JSON file. (Required)
  output_file.conf  Path for the generated Kitty config file. (Optional)
                    Defaults to: ~/.config/kitty/theme/generated.conf
EOF
    exit 1
}

# --- Argument Parsing & Validation ---
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

INPUT_FILE="$1"
DEFAULT_OUTPUT_PATH="$HOME/.config/kitty/theme/generated.conf"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_PATH}"
TEMPLATE_FILE="$SCRIPT_DIR/templates/kitty_template.conf"

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

# Export base16 colors
export BASE00=$(echo "$THEME_JSON" | jq -r '.colors.base00')
export BASE01=$(echo "$THEME_JSON" | jq -r '.colors.base01')
export BASE02=$(echo "$THEME_JSON" | jq -r '.colors.base02')
export BASE03=$(echo "$THEME_JSON" | jq -r '.colors.base03')
export BASE04=$(echo "$THEME_JSON" | jq -r '.colors.base04')
export BASE05=$(echo "$THEME_JSON" | jq -r '.colors.base05')
export BASE06=$(echo "$THEME_JSON" | jq -r '.colors.base06')
export BASE07=$(echo "$THEME_JSON" | jq -r '.colors.base07')
export BASE08=$(echo "$THEME_JSON" | jq -r '.colors.base08')
export BASE09=$(echo "$THEME_JSON" | jq -r '.colors.base09')
export BASE0A=$(echo "$THEME_JSON" | jq -r '.colors.base0A')
export BASE0B=$(echo "$THEME_JSON" | jq -r '.colors.base0B')
export BASE0C=$(echo "$THEME_JSON" | jq -r '.colors.base0C')
export BASE0D=$(echo "$THEME_JSON" | jq -r '.colors.base0D')
export BASE0E=$(echo "$THEME_JSON" | jq -r '.colors.base0E')
export BASE0F=$(echo "$THEME_JSON" | jq -r '.colors.base0F')

# Export semantic colors (with resolution)
export FOREGROUND=$(resolve_color "foreground")
export BACKGROUND=$(resolve_color "background")
export BACKGROUND_ALT=$(resolve_color "backgroundAlt")
export FOREGROUND_INACTIVE=$(resolve_color "foregroundInactive")
export ACCENT=$(resolve_color "accent")
export BORDER=$(resolve_color "border")
export BORDER_FOCUS=$(resolve_color "borderFocus")
export WARNING=$(resolve_color "warning")

# Default fallbacks if semantic colors are missing
: "${FOREGROUND:=$BASE05}"
: "${BACKGROUND:=$BASE00}"
: "${BACKGROUND_ALT:=$BASE01}"
: "${FOREGROUND_INACTIVE:=$BASE03}"
: "${ACCENT:=$BASE0D}"
: "${BORDER:=$BASE02}"
: "${BORDER_FOCUS:=$BASE0D}"
: "${WARNING:=$BASE09}"

echo "📝 Generating Kitty config from template..."
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "Error: Failed to generate config file." >&2
    exit 1
fi

echo "✅ Config written to '$OUTPUT_FILE'"
echo "🚀 Reloading all running Kitty instances..."

# Find all Kitty socket files and reload each one
SOCKET_FILES=$(ls /tmp/kitty-* 2>/dev/null || true)

if [ -z "$SOCKET_FILES" ]; then
    echo "⚠️  Warning: No Kitty instances found to reload." >&2
    echo "   This might be because no Kitty windows are open or remote control is disabled." >&2
    echo "   To enable it, add 'allow_remote_control yes' to your main kitty.conf." >&2
else
    RELOAD_SUCCESS=false
    for SOCKET in $SOCKET_FILES; do
        if [ -S "$SOCKET" ]; then  # Check if it's a socket
            echo "   Reloading via socket: $SOCKET"
            if kitty @ --to "unix:$SOCKET" set-colors --all --configured "$OUTPUT_FILE" 2>/dev/null; then
                RELOAD_SUCCESS=true
            fi
        fi
    done
    
    if [ "$RELOAD_SUCCESS" = false ]; then
        echo "⚠️  Warning: Could not reload any Kitty instances via remote control." >&2
        echo "   This might be because remote control is disabled." >&2
        echo "   To enable it, add 'allow_remote_control yes' to your main kitty.conf." >&2
    else
        echo "✅ Kitty instances reloaded successfully!"
    fi
fi
