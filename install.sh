#!/usr/bin/env bash
#
# Description: Installs axiom on Arch Linux: its packages (all from the
#              official repos), a clone at the latest release, the python
#              venv, and (if you agree) one line in hyprland.lua that starts
#              it; from a text console it then offers to start Hyprland.
#              Everything after that, keybinds and Hyprland settings
#              included, is axiom's own Settings → Desktop → Hyprland.
# Usage:       curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
#              ./install.sh [--yes | --minimal]   (from a clone anywhere; it's
#                linked into ~/.config/quickshell/axiom, or moved there)
#                --yes      answer yes to every question
#                --minimal  required packages only, and no other changes
#              AXIOM_REPO and AXIOM_DIR override the clone's source and
#              target. Safe to run again: nothing is installed or added twice.
#              sudo runs once, for pacman, after showing the command.

set -euo pipefail

# Wrapped in main so bash reads all of it before running any of it: under
# curl | bash, anything reading stdin would otherwise eat the rest
main() {
AXIOM_REPO=${AXIOM_REPO:-https://github.com/axiom-dotfiles/axiom.git}
# Where `qs -c axiom` looks for it
QS_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/axiom
AXIOM_DIR=${AXIOM_DIR:-$QS_DIR}
HYPR_CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua
AUTOSTART='hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom'

REQUIRED=(git hyprland quickshell jq python ttf-material-symbols-variable)
# "feature|packages", offered one at a time
OPTIONAL=(
  "Wallpapers|awww"
  "Wi-Fi menu and network widget|networkmanager"
  "Package update checks|pacman-contrib"
  "Copying screenshots to the clipboard|wl-clipboard"
  "Screen recording|wf-recorder"
  "Annotating screenshots|satty"
  "Launcher calculator|libqalculate wl-clipboard"
  "Typing emoji from the launcher (copying needs only wl-clipboard)|wtype wl-clipboard"
  "Clipboard history with images, shared with other apps|cliphist wl-clipboard"
  "Brightness keys and OSD bar (laptop panels, external monitors over DDC/CI)|brightnessctl ddcutil"
  "hyprlock lock mode and locking on idle|hyprlock hypridle"
)
MIN_QS=0.3.1
MIN_HYPRLAND=0.55.0

mode=ask
case "${1:-}" in
--yes | -y) mode=yes ;;
--minimal) mode=minimal ;;
--help | -h)
  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

# missing pkg...: prints the packages not installed yet, one per line
missing() { (($#)) && pacman -T "$@" || true; }

# Installs the packages with one sudo pacman call, after saying what runs as
# root and why. Declining returns 1
pacman_install() {
  local flags=(-S --needed)
  if [[ "$mode" != ask ]] || ((!have_tty)); then
    flags+=(--noconfirm)
  fi
  echo
  info "${bold}Installing packages needs root${reset}, so this runs through sudo:"
  printf '\n    sudo pacman %s %s\n\n' "${flags[*]}" "$*"
  cat <<'EOF'
   pacman writes to /usr and to its own database, which only root can do. This
   is the only command run as root: the clone, the python venv and hyprland.lua
   all stay in your home and run as you. Every package comes from the official
   repositories, and pacman lists them all, dependencies included, before it
   installs anything. sudo may ask for your password.

EOF
  # --yes, --minimal and no terminal go ahead: the plan above is the notice
  if [[ "$mode" == ask ]] && ((have_tty)); then
    ask "Continue?" || return 1
  fi
  if ((have_tty)); then
    # shellcheck disable=SC2024 # the terminal is pacman's stdin, on purpose
    sudo pacman "${flags[@]}" "$@" </dev/tty && return
  else
    sudo pacman "${flags[@]}" "$@" && return
  fi
  die "pacman failed. If a download returned 404, the package database is out of date: run \`sudo pacman -Syu\`, then this again."
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

is_axiom_clone() { [[ -f "$1/shell.qml" && -f "$1/scripts/self_update.sh" ]] && git -C "$1" rev-parse --git-dir >/dev/null 2>&1; }

# Run from a clone (not curl | bash): that clone is the install, wherever it is
from_clone=0
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  if is_axiom_clone "$script_dir"; then
    AXIOM_DIR=$script_dir
    from_clone=1
  fi
fi

same_dir() { [[ "$(readlink -f "$1" 2>/dev/null)" == "$(readlink -f "$2" 2>/dev/null)" ]]; }

if [[ "$mode" == ask ]] && ((have_tty)); then
  if ((from_clone)); then
    clone_step="this clone, at $AXIOM_DIR"
  else
    clone_step="a clone of the latest release at $AXIOM_DIR"
  fi
  same_dir "$AXIOM_DIR" "$QS_DIR" || clone_step+=$'\n      (then linked or moved to '"$QS_DIR"', where `qs -c axiom` looks)'
  echo
  info "${bold}This installs axiom${reset}, asking before each step that changes anything:"
  cat <<EOF
   1. packages from the official repositories, through sudo pacman (you'll see
      the exact command first)
   2. $clone_step
   3. a python venv inside it, for theme generation
   4. the line that starts axiom, at the end of $HYPR_CONFIG

EOF
fi

mapfile -t need_required < <(missing "${REQUIRED[@]}")
if ((${#need_required[@]})); then
  info "Required, not installed yet: ${need_required[*]}"
else
  ok "The required packages are installed"
fi

# Features whose packages are all there already aren't asked about
offered=()
for entry in "${OPTIONAL[@]}"; do
  read -ra pkgs <<<"${entry#*|}"
  [[ -n "$(missing "${pkgs[@]}")" ]] && offered+=("$entry")
done

wanted=()
skipped=()
if ((${#offered[@]})); then
  all=0
  if [[ "$mode" == yes ]]; then
    all=1
  elif [[ "$mode" == ask ]] && ((have_tty)); then
    echo
    info "Optional features:"
    for entry in "${offered[@]}"; do
      printf '     %-40s %s\n' "${entry%%|*}" "${entry#*|}"
    done
    echo
    ask "Install all of them? (recommended)" && all=1
  fi
  for entry in "${offered[@]}"; do
    feature=${entry%%|*}
    read -ra pkgs <<<"${entry#*|}"
    if ((all)) || ask "$feature? (${pkgs[*]})"; then
      wanted+=("${pkgs[@]}")
    else
      skipped+=("$feature")
    fi
  done
else
  ok "Every optional feature's packages are installed"
fi

# One sudo pacman for everything; wl-clipboard can be wanted twice
mapfile -t to_install < <(missing "${need_required[@]}" "${wanted[@]}" | sort -u)
if ((${#to_install[@]})) && ! pacman_install "${to_install[@]}"; then
  if ((${#need_required[@]})); then
    die "axiom can't run without ${need_required[*]}. Install them, then run this again."
  fi
  warn "Skipped the optional packages."
  skipped=()
  for entry in "${offered[@]}"; do
    skipped+=("${entry%%|*}")
  done
  to_install=()
fi

if [[ " ${to_install[*]} " == *" networkmanager "* ]] && ! systemctl is-active --quiet NetworkManager; then
  warn "NetworkManager isn't running, so the Wi-Fi menu stays empty. Enable it with \`sudo systemctl enable --now NetworkManager\` (after stopping any other network manager, such as iwd or systemd-networkd)."
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

if [[ "$from_clone" == 1 ]]; then
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

# `qs -c axiom` only looks in $QS_DIR, so a clone elsewhere is linked (or
# moved) there
AXIOM_DIR=$(cd "$AXIOM_DIR" && pwd)
placed=1
if same_dir "$QS_DIR" "$AXIOM_DIR"; then
  [[ -L "$QS_DIR" ]] && ok "$QS_DIR links to this clone"
elif [[ -e "$QS_DIR" ]]; then
  placed=0
  if is_axiom_clone "$QS_DIR"; then
    warn "$QS_DIR is another axiom clone, and it's the one \`qs -c axiom\` runs. Run its install.sh instead, or move it away and run this again to use $AXIOM_DIR."
  else
    warn "$QS_DIR exists and isn't axiom, so \`qs -c axiom\` can't find $AXIOM_DIR. Move it away and run this again."
  fi
else
  echo
  info "\`qs -c axiom\` looks for axiom at $QS_DIR, but this clone is at $AXIOM_DIR."
  # A dangling link there (a clone that was moved or deleted) is replaced
  [[ -L "$QS_DIR" ]] && info "$QS_DIR is a broken link; it gets replaced."
  if ask "Link it there? (recommended: the clone stays where it is)"; then
    mkdir -p "$(dirname "$QS_DIR")"
    ln -sfn "$AXIOM_DIR" "$QS_DIR"
    ok "Linked $QS_DIR → $AXIOM_DIR"
  elif ask "Move the clone there instead?" n; then
    mkdir -p "$(dirname "$QS_DIR")"
    rm -f "$QS_DIR"
    mv "$AXIOM_DIR" "$QS_DIR"
    AXIOM_DIR=$QS_DIR
    # Its scripts name the old path; the venv step below rebuilds it
    rm -rf "$AXIOM_DIR/.venv"
    ok "Moved the clone to $QS_DIR"
  else
    placed=0
  fi
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
  elif ((placed)) && ask "Start axiom now?"; then
    setsid qs -c axiom >/dev/null 2>&1 </dev/null &
    disown
    ok "Started axiom"
    started=1
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo
ok "${bold}axiom is installed${reset} at $AXIOM_DIR"
if ((!placed)); then
  warn "\`qs -c axiom\` won't find it until it's at $QS_DIR. Link it with: ln -s \"$AXIOM_DIR\" \"$QS_DIR\""
fi
if ((${#skipped[@]})); then
  joined=$(printf '%s, ' "${skipped[@]}")
  info "Skipped: ${joined%, }. Run this again to add them."
fi
case "$autostart" in
manual) info "Add the line above to $HYPR_CONFIG to start axiom with Hyprland." ;;
*) ((started)) || info "axiom starts the next time you log in to Hyprland." ;;
esac
info "Keybinds and Hyprland setup are in axiom's Settings → Desktop → Hyprland."

# ─── Into Hyprland ───────────────────────────────────────────────────────────

# Not in Hyprland already: say how to get there, and from a text console
# (no graphical session at all) offer to start it right here
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  if command -v start-hyprland >/dev/null; then
    launcher=start-hyprland
  else
    launcher=Hyprland
  fi
  echo
  info "To get into Hyprland: run \`$launcher\` from a text console (a TTY), or log out and pick Hyprland in your login screen's session menu."
  if [[ "$mode" == ask && -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]] && ((have_tty)) \
    && [[ "$(tty </dev/tty 2>/dev/null)" == /dev/tty[0-9]* ]] && ask "Start Hyprland now?"; then
    exec "$launcher" </dev/tty
  fi
fi
}

main "$@"
