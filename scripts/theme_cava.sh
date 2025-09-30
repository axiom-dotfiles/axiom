#!/usr/bin/env bash

#
# Quickshell Theme to Cava Config Converter
#
# This script reads a Quickshell theme file, translates it into a Cava
# configuration file with color settings.
#
# It intelligently handles semantic colors, allowing them to be either
# direct hex codes or references to the base16 palette. It is also
# robust against missing or null values in the semantic block.
#
# Dependencies:
#   - jq:    For parsing the input JSON file.
#
# Usage:
#   ./theme-to-cava.sh <input_file.json> [output_file.conf]
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
Usage: $(basename "$0") <input_file.json> [output_file.conf]

Converts a Quickshell JSON theme to a Cava configuration file.

Arguments:
  input_file.json   Path to the input Quickshell theme JSON file. (Required)
  output_file.conf  Path for the generated Cava config file. (Optional)
                    Defaults to: ~/.config/cava/colors/wal-generated.conf
EOF
    exit 1
}

# --- Argument Parsing & Validation ---
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

INPUT_FILE="$1"
DEFAULT_OUTPUT_PATH="$HOME/.config/cava/colors/wal-generated.conf"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_PATH}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at '$INPUT_FILE'" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---

echo "🎨 Reading theme from '$INPUT_FILE'..."

# This jq script converts the theme to Cava config format
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
  
  # Determine gradient style based on theme properties
  (.variant as $variant |
   if $variant == "dark" then
     "dark"
   else
     "light"
   end) as $mode |
  
  [
    "# Cava Configuration - Auto-generated from Quickshell Theme",
    "# Theme: \(.name)",
    "# Author: \(.author // "N/A")",
    "# Variant: \(.variant)",
    "",
    "[general]",
    "# Bars (0-200), adjust to taste",
    "bars = 0",
    "# Lower and higher cutoff frequencies for lowest and highest bars",
    "lower_cutoff_freq = 50",
    "higher_cutoff_freq = 10000",
    "",
    "[color]",
    "",
    "# Background color (only used in SDconsole)",
    "background = \(.semantic.background | resolve($palette) | format_color)",
    "",
    "# Gradient mode: 0 = no gradient, 1 = gradient using gradient_color values",
    "gradient = 1",
    "",
    "# Gradient colors - creates a smooth transition from bottom to top",
    "# Using accent colors and base colors for an appealing spectrum",
    (if $mode == "dark" then
      [
        "gradient_count = 8",
        "gradient_color_1 = \(.semantic.accent | resolve($palette) | format_color)",
        "gradient_color_2 = \($palette.base0D | format_color)",
        "gradient_color_3 = \($palette.base0C | format_color)",
        "gradient_color_4 = \($palette.base0B | format_color)",
        "gradient_color_5 = \($palette.base0A | format_color)",
        "gradient_color_6 = \($palette.base09 | format_color)",
        "gradient_color_7 = \($palette.base08 | format_color)",
        "gradient_color_8 = \(.semantic.accentSecondary // $palette.base0E | resolve($palette) | format_color)"
      ]
    else
      [
        "gradient_count = 6",
        "gradient_color_1 = \(.semantic.accent | resolve($palette) | format_color)",
        "gradient_color_2 = \($palette.base0D | format_color)",
        "gradient_color_3 = \($palette.base0C | format_color)",
        "gradient_color_4 = \($palette.base0B | format_color)",
        "gradient_color_5 = \($palette.base09 | format_color)",
        "gradient_color_6 = \(.semantic.accentSecondary // $palette.base0E | resolve($palette) | format_color)"
      ]
    end | .[]),
    "",
    "# Alternative single-color mode (set gradient = 0 to use)",
    "# foreground = \(.semantic.accent | resolve($palette) | format_color)",
    "",
    "[smoothing]",
    "# Smoothing mode: 0 = off, 1 = monstercat, 2 = waves",
    "mode = 1",
    "# Waves would be 2, adjust these values for different effects",
    "# waves = 2",
    "# gravity = 100",
    "",
    "# Monstercat smoothing values",
    "monstercat = 1",
    "waves = 0",
    "",
    "[eq]",
    "# This one is tricky. You can have as much keys as you want.",
    "# Remember to uncomment more then one key! More keys = more precision.",
    "# Look at readme.md on github for further explanations and examples.",
    "# 1 = 1 # bass",
    "# 2 = 1",
    "# 3 = 1 # midtone", 
    "# 4 = 1",
    "# 5 = 1 # treble"
  ] | .[]
' < "$INPUT_FILE")

# Check if jq produced any output.
if [ -z "$CONFIG_CONTENT" ]; then
    echo "Error: Failed to parse JSON or extract required color keys from '$INPUT_FILE'." >&2
    echo "Please ensure the file is valid and conforms to the Quickshell Theme schema." >&2
    exit 1
fi

echo "📝 Writing Cava config to '$OUTPUT_FILE'..."
echo "$CONFIG_CONTENT" > "$OUTPUT_FILE"

# Create main config if it doesn't exist
MAIN_CONFIG="$HOME/.config/cava/config"
if [ ! -f "$MAIN_CONFIG" ]; then
    echo "📄 Creating main Cava config file..."
    cat > "$MAIN_CONFIG" <<EOF
# Main Cava Configuration
# Include the generated color theme
include = $OUTPUT_FILE

[general]
framerate = 60
autosens = 1
sensitivity = 100
bars = 0
bar_width = 2
bar_spacing = 1

[input]
method = pulse
source = auto

[output]
method = ncurses
channels = stereo
mono_option = average
EOF
    echo "   Main config created at '$MAIN_CONFIG'"
else
    echo "ℹ️  Main config already exists at '$MAIN_CONFIG'"
    echo "   To use the generated theme, add this line to your config:"
    echo "   include = $OUTPUT_FILE"
fi

echo "✅ Cava color configuration successfully generated!"
