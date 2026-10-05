#!/usr/bin/env bash
#
# Description: Sets axiom up as greetd's greeter (GreeterManager), or takes
#              it out again. The greeter runs as greetd's user, who can't
#              read the user's home, so it gets a copy of axiom of its own,
#              owned by root, and a folder the user's axiom exports its
#              config to (no root needed after this).
# Usage:       greeter_install.sh check <repo>
#              greeter_install.sh hash <repo>
#              greeter_install.sh install|update <repo> <user> [<staged bundle>]
#              greeter_install.sh uninstall <repo> <user>
#                check      (no root) what's set up: prints { greetd,
#                           displayManager, installed, configured,
#                           installedHash, currentHash, greeterUser,
#                           bundleWritable, error }
#                hash       (no root) the hash of what install would copy
#                install    (root, through pkexec) copies <repo>'s tracked
#                           files to the install folder, makes the greeter's
#                           folder (config/ <user>'s, state/ greetd's user's),
#                           snapshots the bundle (<staged bundle>, a folder
#                           of <user>'s the bundle was just written to, else
#                           the greeter's config/) as the copy's fallback,
#                           and points greetd's default_session at
#                           greeter-session.sh, backing its config up first
#                update     the copy and the snapshot again (and greetd's
#                           command, if something changed it)
#                uninstall  puts greetd's config back from its backup and
#                           removes the copy and the greeter's folder
#              Prints one JSON object: { ok, changed: [paths], backup, error }
#              AXIOM_GREETER_ROOT (default /) prefixes every system path,
#              for tests; never run it against the real / to test.

set -uo pipefail

command -v jq >/dev/null || { echo '{"error": "jq is not installed"}'; exit 1; }

action=${1:-}
repo=${2:-}
user=${3:-}
staged=${4:-}
[[ -d "$repo" ]] && repo=$(cd "$repo" && pwd)

root=${AXIOM_GREETER_ROOT:-/}
root=${root%/}
install_dir="$root/usr/share/axiom-greeter"
var_dir="$root/var/lib/axiom-greeter"
greetd_config="$root/etc/greetd/config.toml"
dm_link="$root/etc/systemd/system/display-manager.service"
session_script="/usr/share/axiom-greeter/scripts/greeter/greeter-session.sh"

changed=()
backup=""

emit() {
  local error=${1:-}
  local ok=true
  [[ -n "$error" ]] && ok=false
  jq -cn --argjson ok "$ok" --arg error "$error" --arg backup "$backup" \
    --args '{ok: $ok, changed: $ARGS.positional, backup: $backup, error: $error}' "${changed[@]}"
}

fail() {
  emit "$1"
  exit 1
}

# The files install copies, NUL-separated: what git tracks (as they are in
# the working tree), less what the greeter never runs
files() {
  # Root runs this on the user's clone: no fsmonitor command from its config
  git -c safe.directory="$repo" -c core.fsmonitor=false -C "$repo" ls-files -z --cached -- \
    ':!:tests/' ':!:.github/' ':!:docs/' ':!:install.sh' ':!:*.md' 2>/dev/null
}

hash_of() {
  (cd "$repo" && files | xargs -0 -r sha256sum -- 2>/dev/null | sha256sum | cut -d' ' -f1)
}

# greetd's default_session value of `key` (command, user), unquoted
greetd_value() {
  [[ -f "$greetd_config" ]] || return 0
  awk -v key="$1" '
    /^[[:space:]]*\[/ { section = $0; gsub(/[[:space:]\[\]]/, "", section); next }
    section == "default_session" && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*(#.*)?$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }' "$greetd_config"
}

# greetd's config with default_session's command set to the session script
# (the section and its user made if missing)
point_greetd() {
  local user_line="" tmp
  [[ -n "$(greetd_value user)" ]] || user_line="user = \"greeter\""
  tmp=$(mktemp "$greetd_config.XXXXXX") || return 1
  awk -v command="command = \"$session_script\"" -v user_line="$user_line" '
    function finish() {
      if (in_section && !done) { print command; done = 1 }
      if (in_section && user_line != "") { print user_line; user_line = "" }
    }
    /^[[:space:]]*\[/ {
      finish()
      section = $0; gsub(/[[:space:]\[\]]/, "", section)
      in_section = section == "default_session"
      if (in_section) seen = 1
      print; next
    }
    in_section && /^[[:space:]]*command[[:space:]]*=/ { if (!done) print command; done = 1; next }
    { print }
    END {
      finish()
      if (!seen) { print ""; print "[default_session]"; print command; print (user_line != "" ? user_line : "user = \"greeter\"") }
    }' "$greetd_config" >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  chmod --reference="$greetd_config" "$tmp" 2>/dev/null
  mv "$tmp" "$greetd_config"
}

case "$action" in
check)
  [[ -d "$repo" ]] || fail "no repo: $repo"
  greetd=false
  { [[ -x "$root/usr/bin/greetd" ]] || [[ -x "$root/usr/sbin/greetd" ]]; } && greetd=true
  dm=$(basename "$(readlink "$dm_link" 2>/dev/null)" .service)
  installed=false installed_hash=""
  if [[ -f "$install_dir/.greeter-hash" ]]; then
    installed=true
    installed_hash=$(<"$install_dir/.greeter-hash")
  fi
  configured=false
  [[ "$(greetd_value command)" == "$session_script" ]] && configured=true
  writable=false
  [[ -w "$var_dir/config" ]] && writable=true
  jq -cn --argjson greetd "$greetd" --arg dm "$dm" --argjson installed "$installed" \
    --argjson configured "$configured" --arg installedHash "$installed_hash" \
    --arg currentHash "$(hash_of)" --arg greeterUser "$(greetd_value user)" \
    --argjson bundleWritable "$writable" \
    '{greetd: $greetd, displayManager: $dm, installed: $installed, configured: $configured,
      installedHash: $installedHash, currentHash: $currentHash, greeterUser: $greeterUser,
      bundleWritable: $bundleWritable, error: ""}'
  ;;

hash)
  [[ -d "$repo" ]] || fail "no repo: $repo"
  hash_of
  ;;

install | update)
  [[ -d "$repo" ]] || fail "no repo: $repo"
  [[ -n "$user" ]] && id "$user" >/dev/null 2>&1 || fail "no such user: $user"
  # Through pkexec, the bundle's folder goes only to whoever authenticated
  if [[ -n "${PKEXEC_UID:-}" && "$(id -un "$PKEXEC_UID" 2>/dev/null)" != "$user" ]]; then
    fail "$user isn't the user who ran pkexec"
  fi
  [[ -f "$greetd_config" ]] || fail "greetd isn't installed ($greetd_config is missing)"
  [[ -n "$(files | head -c 1)" ]] || fail "not a git clone: $repo"
  greeter_user=$(greetd_value user)
  greeter_user=${greeter_user:-greeter}
  id "$greeter_user" >/dev/null 2>&1 || fail "greetd's user $greeter_user doesn't exist"

  # The greeter's folder: config/ the user's (the bundle), state/ greetd's
  # user's (the last user and sessions)
  group=$(id -gn "$user")
  install -d -m 755 "$var_dir" &&
    install -d -m 755 -o "$user" -g "$group" "$var_dir/config" &&
    install -d -m 700 -o "$greeter_user" -g "$(id -gn "$greeter_user")" "$var_dir/state" ||
    fail "can't make $var_dir"
  changed+=("$var_dir")

  # The copy: staged beside the old one, then swapped in
  stage="$install_dir.new"
  rm -rf "$stage" && mkdir -p "$stage" || fail "can't write $stage"
  (cd "$repo" && files | tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$stage" || fail "copying $repo failed"
  hash_of >"$stage/.greeter-hash"
  # What the user's axiom exported, as the copy's fallback config: written
  # by this same code, so it loads whatever the bundle later becomes. On a
  # first install the bundle isn't there yet, so axiom stages it first.
  # Either folder is the user's: a link there is copied as a link (-P),
  # never followed by root
  source="$var_dir/config"
  [[ -n "$staged" && -d "$staged" && ! -L "$staged" ]] && source=$staged
  mkdir -p "$stage/fallback"
  for name in greeter.json theme.json; do
    [[ -f "$source/$name" && ! -L "$source/$name" ]] && cp -P "$source/$name" "$stage/fallback/$name"
  done
  chown -R 0:0 "$stage" 2>/dev/null
  chmod -R u=rwX,go=rX "$stage"
  rm -rf "$install_dir.old"
  [[ -d "$install_dir" ]] && mv "$install_dir" "$install_dir.old"
  if ! mv "$stage" "$install_dir"; then
    [[ -d "$install_dir.old" ]] && mv "$install_dir.old" "$install_dir"
    fail "can't replace $install_dir"
  fi
  rm -rf "$install_dir.old"
  changed+=("$install_dir")

  # greetd's command, backed up first: the original once, and each change
  if [[ "$(greetd_value command)" != "$session_script" ]]; then
    [[ -f "$greetd_config.axiom-original" ]] || cp -p "$greetd_config" "$greetd_config.axiom-original"
    backup="$greetd_config.axiom-bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$greetd_config" "$backup" || fail "can't back up $greetd_config"
    point_greetd || fail "can't write $greetd_config"
    changed+=("$greetd_config")
  fi
  emit
  ;;

uninstall)
  if [[ "$(greetd_value command)" == "$session_script" ]]; then
    # The config from before axiom's first install, else the latest backup
    original="$greetd_config.axiom-original"
    [[ -f "$original" ]] || original=$(ls -1 "$greetd_config".axiom-bak-* 2>/dev/null | sort | tail -n 1)
    [[ -n "$original" && -f "$original" ]] || fail "no backup of $greetd_config to put back"
    backup="$greetd_config.axiom-bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$greetd_config" "$backup" && cp -p "$original" "$greetd_config" || fail "can't restore $greetd_config"
    # Spent: a later install takes greetd's config as it is then
    rm -f "$greetd_config.axiom-original"
    changed+=("$greetd_config")
  fi
  for dir in "$install_dir" "$var_dir"; do
    if [[ -e "$dir" ]]; then
      rm -rf "$dir" || fail "can't remove $dir"
      changed+=("$dir")
    fi
  done
  emit
  ;;

*)
  fail "usage: greeter_install.sh check|hash <repo> | install|update <repo> <user> [<staged bundle>] | uninstall <repo> <user>"
  ;;
esac
