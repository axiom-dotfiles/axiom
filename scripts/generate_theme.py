#!/usr/bin/env python3
import pywal  # Now import pywal
import argparse
import json
import os
import subprocess
from pathlib import Path
from datetime import datetime, timezone
import logging

# --- THIS IS THE NEW SECTION ---
# Configure logging BEFORE importing pywal to suppress its noisy "ERROR:root" messages.
# These messages are printed to stderr and can cause process wrappers (like in QML)
# to think the script has failed.
# We set the level for the 'pywal' logger to FATAL, so it only shows true crash-level errors.
logging.getLogger("pywal").setLevel(logging.FATAL)
# --- END OF NEW SECTION ---


def check_available_backends():
    """Check which pywal backends are available on the system."""
    available = ['wal']  # 'wal' is always available if pywal is installed
    try:
        # Use subprocess.DEVNULL to hide output
        subprocess.run(['colorz', '--help'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        available.append('colorz')
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass
    try:
        # This is the correct way pywal checks for it.
        import colorthief
        available.append('colorthief')
    except ImportError:
        pass
    try:
        import haishoku
        available.append('haishoku')
    except ImportError:
        pass
    try:
        import schemer2
        available.append('schemer2')
    except ImportError:
        pass
    return available


# --- Configuration (remains the same) ---
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
    print(f"Generating theme {index} with backend '{
          backend}' from {wallpaper_path}...")

    try:
        # Use the primary pywal API, which is much more stable.
        colors_dict = pywal.colors.get(
            wallpaper_path, backend=backend, light=False)
        if not colors_dict or 'colors' not in colors_dict:
            raise ValueError("Pywal did not return a valid color dictionary.")
        colors = colors_dict['colors']
        print(f"Successfully generated colors using backend '{backend}'")

    except Exception as e:
        print(f"Error with backend '{backend}': {e}")
        if backend != 'wal':
            print("Attempting with 'wal' backend as last resort...")
            try:
                colors_dict = pywal.colors.get(
                    wallpaper_path, backend='wal', light=False)
                if not colors_dict or 'colors' not in colors_dict:
                    raise ValueError(
                        "Pywal (wal backend) did not return a valid color dictionary.")
                colors = colors_dict['colors']
                backend = 'wal'  # Update the backend name for the log
                print("Successfully generated colors using 'wal' backend")
            except Exception as e2:
                print(f"Fatal error: Could not generate colors with any backend: {
                      e2}", file=sys.stderr)
                return
        else:
            print(f"Fatal error: Could not generate colors: {
                  e}", file=sys.stderr)
            return

    base16_colors = {f"base{i:02X}": colors[f"color{i}"] for i in range(16)}
    abs_wallpaper_path = str(Path(wallpaper_path).resolve())

    dark_theme = {
        "name": f"Generated Dark {index}", "author": "pywal", "variant": "dark",
        "paired": f"pywal-light{index}",
        "generated": {
            "source": "pywal", "backend": backend, "wallpaper": abs_wallpaper_path,
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        },
        "colors": base16_colors, "semantic": SEMANTIC_MAP_DARK
    }

    light_theme = {
        "name": f"Generated Light {index}", "author": "pywal", "variant": "light",
        "paired": f"pywal-dark{index}",
        "generated": dark_theme["generated"],
        "colors": base16_colors, "semantic": SEMANTIC_MAP_LIGHT
    }

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
        print(f"Error writing theme files: {e}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Generate dark and light themes using pywal.")
    parser.add_argument("wallpaper", help="Path to the wallpaper image.")
    parser.add_argument("--output_dir", required=True,
                        help="Directory to save the generated JSON themes.")
    parser.add_argument("--index", required=True, type=int,
                        help="The index number for the theme (e.g., 1).")
    parser.add_argument("--backend", required=True,
                        help="The pywal backend to use (e.g., 'wal', 'colorz').")
    parser.add_argument("--list-backends", action="store_true",
                        help="List available backends and exit.")

    args = parser.parse_args()

    if args.list_backends:
        available = check_available_backends()
        print("Available backends:")
        for backend in available:
            print(f"  - {backend}")
        return

    generate_theme_pair(args.wallpaper, args.output_dir,
                        args.index, args.backend)


if __name__ == "__main__":
    # It's good practice to import sys for stderr printing
    import sys
    main()
