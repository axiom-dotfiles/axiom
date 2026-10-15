#!/usr/bin/env bash
#
# Runs another compositor nested (a window in this session) with a second
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
# Usage: scripts/dev/nested.sh <sway|niri> [--copy-config]
#   --copy-config  start from a copy of ~/.config/axiom/config.json (with
#                  the same parts off) instead of the defaults
#
# Logs: qs log -p <repo> (the nested instance is the newest), or the
# log.log under /run/user/$UID/quickshell/by-id/. IPC: qs ipc --newest call …
# Closing the nested window ends it all.

set -euo pipefail

kind="${1:-}"
copy=0
[[ "${2:-}" == "--copy-config" ]] && copy=1
repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="${AXIOM_NESTED_DIR:-${XDG_RUNTIME_DIR:-/tmp}/axiom-nested-$kind}"

case "$kind" in
sway | niri) ;;
*)
  echo "usage: $0 <sway|niri> [--copy-config]" >&2
  exit 2
  ;;
esac
command -v "$kind" >/dev/null || {
  echo "$kind is not installed" >&2
  exit 1
}
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
  exec dbus-run-session -- env WLR_BACKENDS=wayland sway -c "$scratch/sway.conf"
else
  cat >"$scratch/niri.kdl" <<EOF
spawn-at-startup "$launch"
binds {
    Mod+Return { spawn "foot"; }
    Mod+Q { close-window; }
    Mod+Shift+E { quit; }
}
EOF
  exec dbus-run-session -- niri -c "$scratch/niri.kdl"
fi
