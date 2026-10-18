#!/usr/bin/env bash
#
# Runs a compositor nested (a window in this session) with a second
# axiom inside it, for working on a compositor backend
# (docs/dev/compositor/sway-backend.md). The live shell, its config and its
# D-Bus names are left alone:
#   - config, state, data and cache are scratch folders (AXIOM_NESTED_DIR,
#     default $XDG_RUNTIME_DIR/axiom-nested-<compositor>)
#   - it runs on its own D-Bus session (dbus-run-session), so it can't take
#     the notification, tray or MPRIS names from the live shell
#   - its config turns off what would reach outside it: the idle daemon
#     (it would replace the session's) and the polkit agent
#
# Usage: scripts/dev/nested.sh <sway|niri|hyprland> [--copy-config] [--managed]
#   --copy-config  start from a copy of ~/.config/axiom/config.json (with
#                  the same parts off) instead of the defaults
#   --managed      run the compositor on the scratch config folder's own
#                  config (sway/config, niri/config.kdl,
#                  hypr/hyprland.lua), the one axiom's managed mode takes
#                  over (written from the usual nested config the first
#                  time), so the takeover, its reloads and a release can be
#                  tried
#
# axiom's "Restart shell" (scripts/restart.sh) and its one-per-display check
# (InstanceManager) end only the axioms on their own display, so the nested
# and the live one never end each other.
#
# Logs: qs log -p <repo> (the nested instance is the newest), or the
# log.log under /run/user/$UID/quickshell/by-id/. IPC: qs ipc --newest call …
# Closing the nested window ends it all.

set -euo pipefail

kind="${1:-}"
copy=0
managed=0
for arg in "${@:2}"; do
  case "$arg" in
  --copy-config) copy=1 ;;
  --managed) managed=1 ;;
  esac
done
repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="${AXIOM_NESTED_DIR:-${XDG_RUNTIME_DIR:-/tmp}/axiom-nested-$kind}"

case "$kind" in
sway | niri) bin="$kind" ;;
hyprland) bin=Hyprland ;;
*)
  echo "usage: $0 <sway|niri|hyprland> [--copy-config] [--managed]" >&2
  exit 2
  ;;
esac
command -v "$bin" >/dev/null || {
  echo "$bin is not installed" >&2
  exit 1
}
# Hyprland's Wayland backend asks for xdg_wm_base 6, which sway (1.12) doesn't
# have: it fails at once (CBackend::create() failed). Run it from Hyprland or niri
if [[ "$kind" == "hyprland" && -n "${SWAYSOCK:-}" ]]; then
  echo "nested Hyprland doesn't start under sway (it needs xdg_wm_base 6); run it from Hyprland or niri" >&2
  exit 1
fi
command -v dbus-run-session >/dev/null || {
  echo "dbus-run-session (dbus) is needed" >&2
  exit 1
}

mkdir -p "$scratch"/{config/axiom,state,data,cache}

# The config axiom starts with: the defaults, or the user's, with the parts
# that reach outside the nested session off
python3 - "$scratch/config/axiom/config.json" "$copy" <<'EOF'
import json, os, sys
path, copy = sys.argv[1], sys.argv[2] == "1"
config = {}
if copy:
    with open(os.path.expanduser("~/.config/axiom/config.json")) as f:
        config = json.load(f)
elif os.path.exists(path):
    with open(path) as f:
        config = json.load(f)
for section in ("Idle", "Polkit", "Greeter"):
    config.setdefault(section, {})["enabled"] = False
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(config, f, indent=2)
os.replace(tmp, path)
EOF

# The second axiom, as the nested compositor starts it
launch="$scratch/launch.sh"
cat >"$launch" <<EOF
#!/usr/bin/env bash
export XDG_CONFIG_HOME="$scratch/config" XDG_STATE_HOME="$scratch/state" XDG_DATA_HOME="$scratch/data" XDG_CACHE_HOME="$scratch/cache"
exec qs -p "$repo"
EOF
chmod +x "$launch"

# Nothing of this session's compositor may leak in: axiom picks its backend
# from these
unset HYPRLAND_INSTANCE_SIGNATURE NIRI_SOCKET SWAYSOCK I3SOCK

if [[ "$kind" == "sway" ]]; then
  cat >"$scratch/sway.conf" <<EOF
output * bg #1e1e2e solid_color
bindsym Mod4+Return exec foot
bindsym Mod4+q kill
bindsym Mod4+Shift+e exit
$(for i in 1 2 3 4 5; do echo "bindsym Mod4+$i workspace number $i"; done)
exec "$launch"
EOF
  conf="$scratch/sway.conf"
  if [[ $managed -eq 1 ]]; then
    conf="$scratch/config/sway/config"
    mkdir -p "$(dirname "$conf")"
    [[ -f "$conf" ]] || cp "$scratch/sway.conf" "$conf"
  fi
  exec dbus-run-session -- env WLR_BACKENDS=wayland sway -c "$conf"
elif [[ "$kind" == "hyprland" ]]; then
  cat >"$scratch/hyprland.lua" <<EOF
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0, background_color = "rgb(1e1e2e)" } })
hl.on("hyprland.start", function() hl.exec_cmd("$launch") end)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
for i = 1, 5 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
end
EOF
  conf="$scratch/hyprland.lua"
  if [[ $managed -eq 1 ]]; then
    conf="$scratch/config/hypr/hyprland.lua"
    mkdir -p "$(dirname "$conf")"
    [[ -f "$conf" ]] || cp "$scratch/hyprland.lua" "$conf"
  fi
  exec dbus-run-session -- Hyprland -c "$conf"
else
  cat >"$scratch/niri.kdl" <<EOF
spawn-at-startup "$launch"
hotkey-overlay {
    skip-at-startup
}
binds {
    Mod+Return { spawn "foot"; }
    Mod+Q { close-window; }
    Mod+Shift+E { quit; }
}
EOF
  conf="$scratch/niri.kdl"
  if [[ $managed -eq 1 ]]; then
    conf="$scratch/config/niri/config.kdl"
    mkdir -p "$(dirname "$conf")"
    [[ -f "$conf" ]] || cp "$scratch/niri.kdl" "$conf"
  fi
  exec dbus-run-session -- niri -c "$conf"
fi
