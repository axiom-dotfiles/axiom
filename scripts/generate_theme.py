#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
from datetime import datetime, timezone
from pywalfox import color
from pywalfox.settings import S, D

# --- Configuration ---
# The semantic color definitions for dark and light themes.
# The values are keys from the base16 color palette (e.g., "base00").
SEMANTIC_MAP_DARK = {
    "background": "base00", "backgroundAlt": "base01", "backgroundHighlight": "base02",
    "foreground": "base05", "foregroundAlt": "base04", "foregroundHighlight": "base06",
    "foregroundInactive": "base03", "border": "base03", "borderFocus": "base0D",
    "accent": "base0D", "accentAlt": "base0E", "success": "base0B",
    "warning": "base0A", "error": "base08", "info": "base0C",
    "red": "base08", "green": "base0B", "yellow": "base0A", "blue": "base0D",
    "magenta": "base0E", "cyan": "base0C", "white": "base05",
    "bg0": "base00", "bg1": "base01", "bg2": "base02", "bg3": "base03",
    "fg3": "base04", "fg2": "base05", "fg1": "base06"
}

# Inversion map for light theme. Backgrounds become foregrounds and vice-versa.
SEMANTIC_MAP_LIGHT = {
    "background": "base06", "backgroundAlt": "base05", "backgroundHighlight": "base04",
    "foreground": "base01", "foregroundAlt": "base02", "foregroundHighlight": "base00",
    "foregroundInactive": "base03", "border": "base04", "borderFocus": "base0D",
    "accent": "base0D", "accentAlt": "base0E", "success": "base0B",
    "warning": "base0A", "error": "base08", "info": "base0C",
    "red": "base08", "green": "base0B", "yellow": "base0A", "blue": "base0D",
    "magenta": "base0E", "cyan": "base0C", "white": "base01",
    "bg0": "base06", "bg1": "base05", "bg2": "base04", "bg3": "base03",
    "fg3": "base02", "fg2": "base01", "fg1": "base00"
}

def generate_theme_pair(wallpaper_path, output_dir, index, backend):
    """Generates a dark and light theme pair from a wallpaper."""
    print(f"Generating theme {index} with backend '{backend}' from {wallpaper_path}...")
    
    # Generate the color palette using pywalfox
    # We update the global settings to use the chosen backend
    S.backend = backend
    try:
        colors = color.get(wallpaper_path, quiet=True)
    except Exception as e:
        print(f"Error running pywal backend '{backend}': {e}")
        return

    # Prepare base16 color map
    base16_colors = {f"base{i:02X}": colors["colors"][f"color{i}"] for i in range(16)}

    # Get absolute path for storing in the theme file
    abs_wallpaper_path = str(Path(wallpaper_path).resolve())

    # --- Create Dark Theme ---
    dark_theme = {
        "name": f"Generated Dark {index}", "author": "pywal", "variant": "dark",
        "paired": f"pywal-light{index}",
        "generated": {
            "source": "pywal",
            "backend": backend,
            "wallpaper": abs_wallpaper_path,
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        },
        "colors": base16_colors,
        "semantic": SEMANTIC_MAP_DARK
    }

    # --- Create Light Theme ---
    light_theme = {
        "name": f"Generated Light {index}", "author": "pywal", "variant": "light",
        "paired": f"pywal-dark{index}",
        "generated": dark_theme["generated"], # Copy generated info
        "colors": base16_colors,
        "semantic": SEMANTIC_MAP_LIGHT
    }
    
    # --- Write files ---
    output_dir_path = Path(output_dir)
    output_dir_path.mkdir(parents=True, exist_ok=True)
    
    dark_filename = output_dir_path / f"pywal-dark{index}.json"
    light_filename = output_dir_path / f"pywal-light{index}.json"

    try:
        with open(dark_filename, 'w') as f:
            json.dump(dark_theme, f, indent=2)
        print(f"Wrote dark theme to {dark_filename}")
        
        with open(light_filename, 'w') as f:
            json.dump(light_theme, f, indent=2)
        print(f"Wrote light theme to {light_filename}")
    except IOError as e:
        print(f"Error writing theme files: {e}")


def main():
    parser = argparse.ArgumentParser(description="Generate dark and light themes using pywal.")
    parser.add_argument("wallpaper", help="Path to the wallpaper image.")
    parser.add_argument("--output_dir", required=True, help="Directory to save the generated JSON themes.")
    parser.add_argument("--index", required=True, type=int, help="The index number for the theme (e.g., 1).")
    parser.add_argument("--backend", required=True, help="The pywal backend to use (e.g., 'wal', 'colorz').")
    
    args = parser.parse_args()
    
    generate_theme_pair(args.wallpaper, args.output_dir, args.index, args.backend)

if __name__ == "__main__":
    main()
