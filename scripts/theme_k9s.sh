#!/usr/bin/env bash

#
# Quickshell Theme to K9s Skin Converter
#
# This script reads a Quickshell theme file, translates it into a K9s
# skin YAML configuration file.
#
# It intelligently handles semantic colors, allowing them to be either
# direct hex codes or references to the base16 palette. It is also
# robust against missing or null values in the semantic block.
#
# Dependencies:
#   - jq:    For parsing the input JSON file.
#
# Usage:
#   ./theme-to-k9s.sh <input_file.json> [output_file.yaml]
#

# --- Script Setup ---
set -e
set -u
set -o pipefail

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to use this script." >&2
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

# --- Argument Parsing & Validation ---
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

INPUT_FILE="$1"
DEFAULT_OUTPUT_PATH="$HOME/.config/k9s/skins/wal-generated.yaml"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_PATH}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at '$INPUT_FILE'" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---

echo "🎨 Reading theme from '$INPUT_FILE'..."

# This jq script converts the theme to K9s skin format
CONFIG_CONTENT=$(jq -r '
  # Helper function to resolve color names against a given palette.
  def resolve(palette):
    . as $key |
    if $key | type == "string" then
      if palette | has($key) then
        palette[$key]
      else
        $key
      end
    elif $key == null then
      ""
    else
      $key
    end;

  # Helper to ensure color format (prepend # if needed)
  def format_color:
    if . == "" then
      ""
    elif . | startswith("#") then
      "\"\(.)\""
    else
      "\"#\(.)\""
    end;

  # Main filter
  .colors as $palette |
  [
    "# K9s Skin - Auto-generated from Quickshell Theme",
    "# Theme: \(.name)",
    "# Author: \(.author // "N/A")",
    "# Variant: \(.variant)",
    "",
    "k9s:",
    "  # General K9s styles",
    "  body:",
    "    fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "    bgColor: \(.semantic.background | resolve($palette) | format_color)",
    "    logoColor: \(.semantic.accent | resolve($palette) | format_color)",
    "",
    "  # ClusterInfoView styles",
    "  info:",
    "    fgColor: \(.semantic.foregroundInactive // $palette.base04 | resolve($palette) | format_color)",
    "    sectionColor: \(.semantic.warning // $palette.base0A | resolve($palette) | format_color)",
    "",
    "  # Frame styles",
    "  frame:",
    "    # Borders styles",
    "    border:",
    "      fgColor: \(.semantic.border | resolve($palette) | format_color)",
    "      focusColor: \(.semantic.borderFocus | resolve($palette) | format_color)",
    "",
    "    # MenuView attributes and styles",
    "    menu:",
    "      fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "      keyColor: \($palette.base09 | format_color)",
    "      numKeyColor: \(.semantic.accentSecondary // $palette.base0E | resolve($palette) | format_color)",
    "",
    "    # CrumbView attributes for history navigation",
    "    crumbs:",
    "      fgColor: \(.semantic.background | resolve($palette) | format_color)",
    "      bgColor: \(.semantic.backgroundAlt2 // $palette.base03 | resolve($palette) | format_color)",
    "      activeColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "",
    "    # Resource status and update styles",
    "    status:",
    "      newColor: \(.semantic.success // $palette.base0B | resolve($palette) | format_color)",
    "      modifyColor: \(.semantic.warning // $palette.base0A | resolve($palette) | format_color)",
    "      addColor: \($palette.base0B | format_color)",
    "      errorColor: \(.semantic.error // $palette.base08 | resolve($palette) | format_color)",
    "      highlightcolor: \($palette.base09 | format_color)",
    "      killColor: \($palette.base08 | format_color)",
    "      completedColor: \(.semantic.foregroundInactive // $palette.base03 | resolve($palette) | format_color)",
    "",
    "    # Border title styles",
    "    title:",
    "      fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "      bgColor: \(.semantic.backgroundAlt // $palette.base01 | resolve($palette) | format_color)",
    "      highlightColor: \(.semantic.accent | resolve($palette) | format_color)",
    "      counterColor: \(.semantic.accentSecondary // $palette.base0E | resolve($palette) | format_color)",
    "      filterColor: \($palette.base09 | format_color)",
    "",
    "  # Views",
    "  views:",
    "    # Table view",
    "    table:",
    "      fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "      bgColor: \(.semantic.background | resolve($palette) | format_color)",
    "      cursorColor: \(.semantic.backgroundAlt // $palette.base01 | resolve($palette) | format_color)",
    "      header:",
    "        fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "        bgColor: \(.semantic.backgroundAlt // $palette.base01 | resolve($palette) | format_color)",
    "        sorterColor: \($palette.base09 | format_color)",
    "",
    "    # YAML view",
    "    yaml:",
    "      keyColor: \($palette.base0D | format_color)",
    "      colonColor: \(.semantic.foregroundInactive // $palette.base03 | resolve($palette) | format_color)",
    "      valueColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "",
    "    # Logs view",
    "    logs:",
    "      fgColor: \(.semantic.foreground | resolve($palette) | format_color)",
    "      bgColor: \(.semantic.background | resolve($palette) | format_color)"
  ] | .[]
' < "$INPUT_FILE")

# Check if jq produced any output.
if [ -z "$CONFIG_CONTENT" ]; then
    echo "Error: Failed to parse JSON or extract required color keys from '$INPUT_FILE'." >&2
    echo "Please ensure the file is valid and conforms to the Quickshell Theme schema." >&2
    exit 1
fi

echo "📝 Writing K9s skin to '$OUTPUT_FILE'..."
echo "$CONFIG_CONTENT" > "$OUTPUT_FILE"

echo "✅ K9s skin successfully generated!"
