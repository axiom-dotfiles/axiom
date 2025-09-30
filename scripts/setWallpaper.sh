#!/usr/bin/env bash
#
# Author:      travmonkey
# Date:        2025-09-30
# Description: Sets a wallpaper with a random transition on the active monitor.
# Usage:       setWallpaper.sh <path_to_image>

set -euo pipefail

if [ -z "${1:-}" ] || [ ! -f "$1" ]; then
  echo "Usage: $0 <path_to_image>"
  echo "Error: Please provide a valid path to a wallpaper image."
  exit 1
fi

WALLPAPER_PATH="$1"

pkill swaybg &>/dev/null || true

swww query >/dev/null || swww init

transitions=("wipe" "any" "outer" "wave")
TRANSITION_TYPE=${transitions[$RANDOM % ${#transitions[@]}]}
SWWW_PARAMS="--transition-fps 144 --transition-type $TRANSITION_TYPE --transition-duration 1"

current_monitor=$(hyprctl -j activeworkspace | jq -r .monitor)
swww img -o "$current_monitor" "$WALLPAPER_PATH" $SWWW_PARAMS

if [[ "$current_monitor" == "DP-1" ]]; then
  ln -sf "$WALLPAPER_PATH" "$HOME/.current_wallpaper"
fi
