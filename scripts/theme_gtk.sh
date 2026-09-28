#!/usr/bin/env bash
#
# Quickshell theme -> GTK 3 and GTK 4 colors (templates/gtk_template.css).
#
# Usage: theme_gtk.sh <theme.json> [config_dir]
#   output: axiom.css in ~/.config/gtk-3.0 and ~/.config/gtk-4.0
#   hookup: `@import url("axiom.css");` in each gtk.css (created with it when missing);
#           GTK3 apps follow it with the adw-gtk3 theme (pacman -S adw-gtk-theme)
#   reload: dark/light live (gsettings color-scheme, and gtk-theme between
#           adw-gtk3 and adw-gtk3-dark when it's one of them); colors on each
#           app's next start
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/theme_env.sh"
usage_or_help 3 9 "$@"
require_cmds jq envsubst

CONFIG_DIR="${2:-${XDG_CONFIG_HOME:-$HOME/.config}}"
IMPORT='@import url("axiom.css");'
load_theme "$1"
export_theme_colors

for DIR in "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"; do
    render_template "$SCRIPT_DIR/templates/gtk_template.css" "$DIR/axiom.css"
    # A gtk.css (or a symlink to a theme's) that isn't there is created;
    # one that is stays yours
    if [ ! -e "$DIR/gtk.css" ] && [ ! -L "$DIR/gtk.css" ]; then
        printf '/* GTK user CSS (created by axiom; yours to edit) */\n%s\n' "$IMPORT" | write_atomic "$DIR/gtk.css"
        echo "📄 Created '$DIR/gtk.css' importing the colors"
    elif ! grep -qF "$IMPORT" "$DIR/gtk.css" 2>/dev/null; then
        warn "'$DIR/gtk.css' doesn't import the colors: add '$IMPORT' at its top."
    fi
done

# Only for the real config: a test run into another directory leaves the
# session alone
if [ $# -lt 2 ] && command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme "$([[ "$THEME_VARIANT" == "light" ]] && echo prefer-light || echo prefer-dark)"
    # adw-gtk3 comes as a light and a dark theme, and apps that judge the
    # mode by the theme (Firefox and its forks) follow its name, not
    # color-scheme. Any other theme is the user's to pick.
    GTK_THEME="$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")"
    if [[ "$GTK_THEME" == adw-gtk3 || "$GTK_THEME" == adw-gtk3-dark ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "$([[ "$THEME_VARIANT" == "light" ]] && echo adw-gtk3 || echo adw-gtk3-dark)"
    fi
fi
echo "🚀 GTK apps pick up the colors on their next start."
