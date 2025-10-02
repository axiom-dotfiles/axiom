#!/usr/bin/env python3
import pywal
import argparse
import json
import os
import subprocess
from pathlib import Path
from datetime import datetime, timezone
import logging
import sys

logging.getLogger("pywal").setLevel(logging.FATAL)


def check_available_backends():
    """Check which pywal backends are available on the system."""
    available = ['wal']
    try:
        subprocess.run(['colorz', '--help'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        available.append('colorz')
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass
    try:
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


def generate_theme_pair(wallpaper_path, output_dir, backend):
    """Generates a dark and light theme pair from a wallpaper."""
    print(f"Generating theme with backend '{
          backend}' from {wallpaper_path}...")

    try:
        colors_dict = pywal.colors.get(
            wallpaper_path, backend=backend, light=False)
        if not colors_dict or 'colors' not in colors_dict:
            raise ValueError("Pywal did not return a valid color dictionary.")
        colors = colors_dict['colors']
        base16_colors = reorder_base16_colors(colors)
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
                base16_colors = reorder_base16_colors(colors)
                backend = 'wal'
                print("Successfully generated colors using 'wal' backend")
            except Exception as e2:
                print(f"Fatal error: Could not generate colors with any backend: {
                      e2}", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"Fatal error: Could not generate colors: {
                  e}", file=sys.stderr)
            sys.exit(1)

    abs_wallpaper_path = str(Path(wallpaper_path).resolve())

    output_dir_path = Path(output_dir)
    output_dir_path.mkdir(parents=True, exist_ok=True)

    dark_filename = output_dir_path / f"pywal-dark-{backend}.json"
    light_filename = output_dir_path / f"pywal-light-{backend}.json"

    dark_theme = {
        "name": f"Pywal {backend.capitalize()} Dark", "author": "pywal", "variant": "dark",
        "paired": f"{light_filename.stem}",
        "generated": {
            "source": "pywal", "backend": backend, "wallpaper": abs_wallpaper_path,
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        },
        "colors": base16_colors, "semantic": SEMANTIC_MAP_DARK
    }

    light_theme = {
        "name": f"Pywal {backend.capitalize()} Light", "author": "pywal", "variant": "light",
        "paired": f"{dark_filename.stem}",
        "generated": dark_theme["generated"],
        "colors": base16_colors, "semantic": SEMANTIC_MAP_LIGHT
    }

    try:
        with open(dark_filename, 'w') as f:
            json.dump(dark_theme, f, indent=2)
        print(f"Wrote dark theme to {dark_filename}")

        with open(light_filename, 'w') as f:
            json.dump(light_theme, f, indent=2)
        print(f"Wrote light theme to {light_filename}")
    except IOError as e:
        print(f"Error writing theme files: {e}", file=sys.stderr)
        sys.exit(1)


def reorder_base16_colors(colors):
    """
    Intelligently reorders pywal colors into a proper base16 scheme.
    - Separates grays and accents based on saturation.
    - Sorts grays by lightness to create a smooth ramp.
    - Maps accents to their correct slots (red, green, etc.) based on hue.
    """
    from colormath.color_objects import sRGBColor, HSLColor
    from colormath.color_conversions import convert_color

    # --- Color Representation and Helpers ---
    class Color:
        """A helper class to store color data in multiple formats."""

        def __init__(self, hex_val):
            self.hex = hex_val
            rgb = sRGBColor.new_from_rgb_hex(hex_val)
            hsl = convert_color(rgb, HSLColor)
            self.hsl = (hsl.hsl_h, hsl.hsl_s, hsl.hsl_l)

        @property
        def hue(self):
            return self.hsl[0]

        @property
        def saturation(self):
            return self.hsl[1]

        @property
        def lightness(self):
            return self.hsl[2]

    # Target hues for the 6 main accent colors on a 0-360 degree circle
    TARGET_HUES = {
        'red': 0, 'yellow': 60, 'green': 120,
        'cyan': 180, 'blue': 240, 'magenta': 300
    }

    # Base16 slots for these accent colors
    # We will map our best-matched colors to these slots.
    ACCENT_SLOTS = {
        'red': 'base08', 'green': 'base0B', 'yellow': 'base0A',
        'blue': 'base0D', 'magenta': 'base0E', 'cyan': 'base0C'
    }

    def hue_distance(h1, h2):
        """Calculates the shortest distance between two hues on a color circle."""
        diff = abs(h1 - h2)
        return min(diff, 360 - diff)

    # --- Main Logic ---

    # 1. Convert all 16 pywal colors into our helper class
    all_colors = [Color(colors[f'color{i}']) for i in range(16)]

    # 2. Separate grays from accent colors based on saturation
    # A low saturation value means the color is close to a gray.
    SATURATION_THRESHOLD = 0.20
    grays = [c for c in all_colors if c.saturation < SATURATION_THRESHOLD]
    accents = [c for c in all_colors if c.saturation >= SATURATION_THRESHOLD]

    # 3. Ensure we have exactly 8 grays and 8 accents.
    # If we have too few grays, "borrow" the least saturated accents.
    while len(grays) < 8:
        accents.sort(key=lambda c: c.saturation)
        color_to_move = accents.pop(0)
        grays.append(color_to_move)

    # If we have too many grays, "donate" the most saturated grays to the accents.
    while len(grays) > 8:
        grays.sort(key=lambda c: c.saturation, reverse=True)
        color_to_move = grays.pop(0)
        accents.append(color_to_move)

    # 4. Process the Grays: Sort by lightness to create a smooth ramp.
    grays.sort(key=lambda c: c.lightness)
    new_colors = {}
    # The 4 darkest grays are backgrounds
    for i in range(4):
        new_colors[f'base0{i:X}'] = grays[i].hex
    # The 4 lightest grays are foregrounds
    for i in range(4):
        new_colors[f'base0{i+4:X}'] = grays[i+4].hex

    # 5. Process the Accents: Map them to semantic slots using hue.
    unassigned_accents = list(accents)

    # Find the best match for each of the 6 primary accent colors
    for name, target_hue in TARGET_HUES.items():
        # Find the unassigned color with the minimum hue distance to the target
        best_match = min(unassigned_accents,
                         key=lambda c: hue_distance(c.hue, target_hue))

        # Assign it to the correct base16 slot
        slot = ACCENT_SLOTS[name]
        new_colors[slot] = best_match.hex

        # Remove it from the pool of unassigned colors
        unassigned_accents.remove(best_match)

    # 6. Assign the remaining 2 accent colors to the leftover slots (base09 and base0F)
    # These are often used for orange/brown and a bright gray/accent.
    # Here, we just assign them based on lightness.
    unassigned_accents.sort(key=lambda c: c.lightness)
    if len(unassigned_accents) > 0:
        new_colors['base09'] = unassigned_accents[0].hex
    if len(unassigned_accents) > 1:
        new_colors['base0F'] = unassigned_accents[1].hex

    return new_colors

# You also need to remove the old import from the top of the file
# as the new function handles its own imports.
# Remove this line: from colorsys import rgb_to_hls


def main():
    parser = argparse.ArgumentParser(
        description="Generate dark and light themes using pywal.")
    parser.add_argument("wallpaper", help="Path to the wallpaper image.")
    parser.add_argument("--output_dir", required=True,
                        help="Directory to save the generated JSON themes.")
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

    generate_theme_pair(args.wallpaper, args.output_dir, args.backend)


if __name__ == "__main__":
    main()
