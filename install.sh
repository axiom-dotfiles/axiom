#!/usr/bin/env bash
#
# Description: Installs axiom on Arch Linux: its packages (all from the
#              official repos), a clone at the latest release, the python
#              venv, and (if you agree) one line in hyprland.lua that starts
#              it. Everything after that, keybinds and Hyprland settings
#              included, is axiom's own Settings → Desktop → Hyprland.
# Usage:       curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
#              ./install.sh [--yes | --minimal]   (from a clone)
#                --yes      answer yes to every question
#                --minimal  required packages only, and no other changes
#              AXIOM_REPO and AXIOM_DIR override the clone's source and
#              target. Safe to run again: nothing is installed or added twice.

set -euo pipefail

# Wrapped in main so bash reads all of it before running any of it: under
# curl | bash, anything reading stdin would otherwise eat the rest
main() {
AXIOM_REPO=${AXIOM_REPO:-https://github.com/axiom-dotfiles/axiom.git}
AXIOM_DIR=${AXIOM_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/axiom}
HYPR_CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua
AUTOSTART='hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom'

REQUIRED=(git hyprland quickshell jq python ttf-material-symbols-variable)
# "feature|packages", offered one at a time
OPTIONAL=(
  "Wallpapers|awww"
  "Theme generation from wallpapers|imagemagick"
  "Wi-Fi menu and network widget|networkmanager"
  "Package update checks|pacman-contrib"
  "Screenshot module|grim slurp wl-clipboard"
  "Launcher calculator|libqalculate wl-clipboard"
  "hyprlock lock mode and locking on idle|hyprlock hypridle"
)
MIN_QS=0.3.1
MIN_HYPRLAND=0.55.0

mode=ask
case "${1:-}" in
--yes | -y) mode=yes ;;
--minimal) mode=minimal ;;
--help | -h)
  sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
  ;;
"") ;;
*)
  echo "Unknown option: $1 (try --help)" >&2
  exit 2
  ;;
esac

if [[ -t 1 ]]; then
  bold=$'\e[1m' blue=$'\e[34m' yellow=$'\e[33m' red=$'\e[31m' green=$'\e[32m' reset=$'\e[0m'
else
  bold="" blue="" yellow="" red="" green="" reset=""
fi
info() { printf '%s::%s %s\n' "$blue$bold" "$reset" "$*"; }
ok() { printf '%s::%s %s\n' "$green$bold" "$reset" "$*"; }
warn() { printf '%swarning:%s %s\n' "$yellow$bold" "$reset" "$*" >&2; }
die() {
  printf '%serror:%s %s\n' "$red$bold" "$reset" "$*" >&2
  exit 1
}

# Under curl | bash stdin is this script, so questions and pacman read the
# terminal instead
if { : </dev/tty; } 2>/dev/null; then
  have_tty=1
else
  have_tty=0
fi

# ask "question" [default y|n]: in --yes mode yes, in --minimal mode or
# without a terminal no
ask() {
  local default=${2:-y} hint answer
  [[ "$mode" == yes ]] && return 0
  [[ "$mode" == minimal ]] && return 1
  # No terminal to ask on: change nothing unasked (--yes says otherwise)
  ((have_tty)) || return 1
  [[ "$default" == y ]] && hint="[Y/n]" || hint="[y/N]"
  printf '%s::%s %s %s ' "$blue$bold" "$reset" "$1" "$hint"
  read -r answer </dev/tty || answer=""
  answer=${answer:-$default}
  [[ "$answer" == [yY]* ]]
}

# Installs whichever of the packages are missing
pacman_install() {
  local missing flags=(-S --needed)
  mapfile -t missing < <(pacman -T "$@" || true)
  if ((!${#missing[@]})); then
    ok "Already installed: $*"
    return
  fi
  set -- "${missing[@]}"
  info "Installing: $*"
  if [[ "$mode" != ask ]] || ((!have_tty)); then
    flags+=(--noconfirm)
  fi
  if ((have_tty)); then
    # shellcheck disable=SC2024 # the terminal is pacman's stdin, on purpose
    sudo pacman "${flags[@]}" "$@" </dev/tty
  else
    sudo pacman "${flags[@]}" "$@"
  fi
}

# version_at_least have want
version_at_least() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

first_version() { grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }

axiom_running() { pgrep -f '(^|/)(qs|quickshell) (.* )?-c axiom( |$)' >/dev/null; }

# ─── Preflight ───────────────────────────────────────────────────────────────

if [[ ! -f /etc/arch-release ]] || ! command -v pacman >/dev/null; then
  die "This installer supports Arch Linux only. See the README for installing by hand."
fi
((EUID != 0)) || die "Run this as your own user, not root: it uses sudo for pacman only."
command -v sudo >/dev/null || die "sudo is needed to install packages."

# ─── Packages ────────────────────────────────────────────────────────────────

pacman_install "${REQUIRED[@]}"

wanted=()
skipped=()
for entry in "${OPTIONAL[@]}"; do
  feature=${entry%%|*}
  read -ra pkgs <<<"${entry#*|}"
  if ask "$feature? (${pkgs[*]})"; then
    wanted+=("${pkgs[@]}")
  else
    skipped+=("$feature")
  fi
done
if ((${#wanted[@]})); then
  # wl-clipboard can appear twice
  mapfile -t wanted < <(printf '%s\n' "${wanted[@]}" | sort -u)
  pacman_install "${wanted[@]}"
fi

qs_path=$(command -v qs || true)
if [[ -n "$qs_path" && "$(readlink -f "$qs_path")" != /usr/bin/* ]]; then
  warn "$qs_path comes before the quickshell package's /usr/bin/qs on your PATH."
fi
qs_version=$(qs --version 2>/dev/null | first_version || true)
if [[ -z "$qs_version" ]] || ! version_at_least "$qs_version" "$MIN_QS"; then
  warn "axiom needs Quickshell $MIN_QS or newer (found ${qs_version:-none})."
fi
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hypr_version=$(hyprctl version 2>/dev/null | first_version || true)
  if [[ -n "$hypr_version" ]] && ! version_at_least "$hypr_version" "$MIN_HYPRLAND"; then
    warn "The running Hyprland is $hypr_version; axiom needs $MIN_HYPRLAND or newer. Log out and back in after the upgrade."
  fi
fi

# ─── The clone ───────────────────────────────────────────────────────────────

is_axiom_clone() { [[ -f "$1/shell.qml" && -f "$1/scripts/self_update.sh" ]] && git -C "$1" rev-parse --git-dir >/dev/null 2>&1; }

script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

if [[ -n "$script_dir" ]] && is_axiom_clone "$script_dir"; then
  AXIOM_DIR=$script_dir
  info "Using this clone: $AXIOM_DIR"
elif is_axiom_clone "$AXIOM_DIR"; then
  info "axiom is already cloned at $AXIOM_DIR"
elif [[ -e "$AXIOM_DIR" ]]; then
  die "$AXIOM_DIR already exists and isn't an axiom clone. Move it away and run this again."
else
  info "Cloning axiom into $AXIOM_DIR"
  mkdir -p "$(dirname "$AXIOM_DIR")"
  git clone --quiet "$AXIOM_REPO" "$AXIOM_DIR"
  # Releases are v* tags; self-update also works from a detached tag
  latest=$(git -C "$AXIOM_DIR" tag -l 'v*' --sort=-v:refname | head -1)
  if [[ -n "$latest" ]]; then
    git -C "$AXIOM_DIR" -c advice.detachedHead=false checkout --quiet "$latest"
    ok "Checked out $latest"
  else
    warn "No release tag yet, so this is the development branch."
  fi
fi

if [[ "$AXIOM_DIR" != "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/axiom" ]]; then
  warn "axiom isn't at ~/.config/quickshell/axiom, so \`qs -c axiom\` won't find it."
fi

# ─── Python venv (theme generation) ──────────────────────────────────────────

if [[ "$mode" != minimal ]]; then
  "$AXIOM_DIR/scripts/setup_venv.sh" || warn "The python venv failed; theme generation retries it later."
fi

# ─── Autostart ───────────────────────────────────────────────────────────────

hypr_target=$(readlink -f "$HYPR_CONFIG" 2>/dev/null || echo "$HYPR_CONFIG")
if [[ -f "$hypr_target" ]] && grep -qE '(qs|quickshell) (.* )?-c axiom' "$hypr_target"; then
  ok "hyprland.lua already starts axiom"
  autostart=present
else
  echo
  info "To start with Hyprland, axiom needs this line at the end of $HYPR_CONFIG:"
  printf '\n    %s\n\n' "$AUTOSTART"
  if ask "Add it?"; then
    mkdir -p "$(dirname "$hypr_target")"
    if [[ -f "$hypr_target" ]]; then
      backup="$hypr_target.bak-$(date +%Y%m%d-%H%M%S)"
      cp -p "$hypr_target" "$backup"
      info "Backed up to $backup"
      # Don't glue the line onto a last line without a newline
      [[ -n "$(tail -c1 "$hypr_target")" ]] && echo >>"$hypr_target"
    elif [[ -f /usr/share/hypr/hyprland.lua ]]; then
      # What Hyprland would write on its first start, so its starter binds
      # (terminal, close window, ...) are there too; axiom skips taken keys
      cp /usr/share/hypr/hyprland.lua "$hypr_target"
      info "Created $hypr_target from Hyprland's default config"
    fi
    printf '%s\n' "$AUTOSTART" >>"$hypr_target"
    ok "Added to $hypr_target"
    autostart=added
  else
    autostart=manual
  fi
fi

# ─── Start ───────────────────────────────────────────────────────────────────

started=0
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  if axiom_running; then
    ok "axiom is already running"
    started=1
  elif ask "Start axiom now?"; then
    setsid qs -c axiom >/dev/null 2>&1 </dev/null &
    disown
    ok "Started axiom"
    started=1
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo
ok "${bold}axiom is installed${reset} at $AXIOM_DIR"
if ((${#skipped[@]})); then
  joined=$(printf '%s, ' "${skipped[@]}")
  info "Skipped: ${joined%, }. Run this again to add them."
fi
case "$autostart" in
manual) info "Add the line above to $HYPR_CONFIG to start axiom with Hyprland." ;;
*) ((started)) || info "axiom starts the next time you log in to Hyprland." ;;
esac
info "Keybinds and Hyprland setup are in axiom's Settings → Desktop → Hyprland."
}

main "$@"
