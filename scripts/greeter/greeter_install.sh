#!/usr/bin/env bash
#
# Description: Sets axiom up as greetd's greeter (GreeterManager), or takes
#              it out again. The greeter runs as greetd's user, who can't
#              read the user's home, so it gets a copy of axiom of its own,
#              owned by root, and a folder the user's axiom exports its
#              config to (no root needed after this).
#              Install runs this file from the user's clone (pkexec bash);
#              it then installs a polkit action for the copy's own file, so
#              update and uninstall run root's copy, by its own prompt
#              (scripts/greeter/org.axiom.greeter.policy). An update is run
#              by the copy being replaced: its arguments stay compatible.
# Usage:       greeter_install.sh check <repo> [<source> [<channel>]]
#              greeter_install.sh hash <repo> [<source> [<channel>]]
#              greeter_install.sh install|update <repo> <user> [<staged bundle> [<source> [<channel>]]]
#              greeter_install.sh uninstall <repo> <user>
#              <source> is where the copy's code comes from (Greeter.source):
#                git    (default) root fetches it into its own mirror
#                       (/var/lib/axiom-greeter/upstream.git) from the
#                       repository <repo> was cloned from, recorded at the
#                       first git install so nothing that writes to <repo>
#                       can redirect it later: <channel> (SelfUpdate.channel)
#                       "tags" (default) takes the newest v* tag, "main" the
#                       main (or master) branch
#                local  <repo> as it is: the checked-out branch, uncommitted
#                       changes included (read as <user>)
#                check      (no root) what's set up: prints { greetd,
#                           agreety, displayManager, installed, configured,
#                           helper, installedSource ("git:tags" | "git:main"
#                           | "local" | ""), url (git's), installedHash,
#                           currentHash (for <source>: "" when the remote
#                           can't be reached), greeterUser, bundleWritable,
#                           error }. A git hash is the commit, a local one
#                           the files' content
#                hash       (no root) currentHash alone
#                install    (root, through pkexec) copies <source>'s code
#                           (less tests and docs) to the install folder,
#                           makes the greeter's folder (config/ <user>'s,
#                           state/ greetd's user's), snapshots the bundle
#                           (<staged bundle>, a folder of <user>'s the
#                           bundle was just written to, else the greeter's
#                           config/; "" for none) as the copy's fallback,
#                           points greetd's default_session at
#                           greeter-session.sh, backing its config up first,
#                           and installs the polkit action
#                update     the copy and the snapshot again (and greetd's
#                           command, if something changed it)
#                uninstall  puts greetd's config back from its backup and
#                           removes the copy, the greeter's folder (the
#                           mirror with it) and the polkit action
#              Prints one JSON object: { ok, changed: [paths], backup, error }
#              AXIOM_GREETER_ROOT (default /) prefixes every system path,
#              for tests; never run it against the real / to test.

set -uo pipefail

command -v jq >/dev/null || { echo '{"error": "jq is not installed"}'; exit 1; }

action=${1:-}
repo=${2:-}
user=${3:-}
staged=${4:-}
source=${5:-git}
channel=${6:-tags}
if [[ "$action" == check || "$action" == hash ]]; then
  # No user: these run as whoever calls them (as_user must never take the
  # source for a user name, which as root would run nothing)
  user=""
  staged=""
  source=${3:-git}
  channel=${4:-tags}
fi
[[ -d "$repo" ]] && repo=$(cd "$repo" && pwd)

root=${AXIOM_GREETER_ROOT:-/}
root=${root%/}
install_dir="$root/usr/share/axiom-greeter"
var_dir="$root/var/lib/axiom-greeter"
greetd_config="$root/etc/greetd/config.toml"
dm_link="$root/etc/systemd/system/display-manager.service"
session_script="/usr/share/axiom-greeter/scripts/greeter/greeter-session.sh"
helper="$install_dir/scripts/greeter/greeter_install.sh"
policy="$root/usr/share/polkit-1/actions/org.axiom.greeter.policy"
mirror="$var_dir/upstream.git"
# Never wait on a password or host-key prompt; never run a transport's
# commands
export GIT_TERMINAL_PROMPT=0
git_safe=(-c protocol.ext.allow=never)

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

# What the greeter never runs
pathspec=(':!:tests/' ':!:.github/' ':!:docs/' ':!:install.sh' ':!:*.md')

# A command as the user: as root (pkexec), their clone, its git config and
# any filters it names stay theirs
as_user() {
  if [[ $EUID -eq 0 && -n "$user" && "$user" != root ]]; then
    runuser -u "$user" -- env HOME="$(getent passwd "$user" | cut -d: -f6)" "$@"
  else
    "$@"
  fi
}

git_repo() {
  as_user git "${git_safe[@]}" -C "$repo" "$@"
}

# --- local: the clone as it is ---

# Its tracked files as they are in the working tree, as a tar
local_archive() {
  as_user bash -c 'cd "$1" && shift && git ls-files -z --cached -- "$@" |
    tar --null --ignore-failed-read -T - -cf - 2>/dev/null' _ "$repo" "${pathspec[@]}"
}

# The hash of those files' content
local_hash() {
  as_user bash -c 'cd "$1" && shift && git ls-files -z --cached -- "$@" |
    xargs -0 -r sha256sum -- 2>/dev/null | sha256sum | cut -d" " -f1' _ "$repo" "${pathspec[@]}"
}

# --- git: root's mirror of the clone's upstream ---

# A remote's url as https, which root can fetch without the user's keys
# (git@host:path and ssh://[user@]host/path; anything else as it is)
https_url() {
  case "$1" in
  git@*:*)
    local rest=${1#git@}
    printf 'https://%s/%s\n' "${rest%%:*}" "${rest#*:}"
    ;;
  ssh://*)
    local rest=${1#ssh://}
    printf 'https://%s\n' "${rest#*@}"
    ;;
  *) printf '%s\n' "$1" ;;
  esac
}

# What the copy was made from: "git <channel> <url>" | "local" | ""
installed_source() {
  [[ -f "$install_dir/.greeter-source" ]] && head -n 1 "$install_dir/.greeter-source"
}

# The url git takes: the one recorded by the copy's git install, else the
# clone's remote (its branch's, else origin), as https
upstream_url() {
  local recorded branch remote
  recorded=$(installed_source)
  if [[ "$recorded" == git\ * ]]; then
    printf '%s\n' "${recorded#git * }"
    return
  fi
  branch=$(git_repo symbolic-ref --quiet --short HEAD 2>/dev/null)
  remote=$([[ -n "$branch" ]] && git_repo config "branch.$branch.remote" 2>/dev/null)
  remote=$(git_repo remote get-url "${remote:-origin}" 2>/dev/null) || return 0
  https_url "$remote"
}

# The channel's newest commit on `url`: "<commit> <ref>", nothing when the
# remote can't be reached or has none
remote_target() {
  local refs
  refs=$(timeout 60 git "${git_safe[@]}" ls-remote "$1" 2>/dev/null) || return 0
  if [[ "$channel" == main ]]; then
    awk -F'\t' '$2 == "refs/heads/main" { print $1, $2; found = 1; exit }
      $2 == "refs/heads/master" { master = $1 }
      END { if (!found && master) print master, "refs/heads/master" }' <<<"$refs"
  else
    # Annotated tags by their peeled commit
    awk -F'\t' '$2 ~ /^refs\/tags\/v/ {
        name = $2; sub(/^refs\/tags\//, "", name)
        if (name ~ /\^\{\}$/) { sub(/\^\{\}$/, "", name); peeled[name] = $1 } else plain[name] = $1
      }
      END { for (n in plain) print n "\t" (n in peeled ? peeled[n] : plain[n]) }' <<<"$refs" |
      sort -t$'\t' -k1,1V | tail -n 1 | awk -F'\t' '$1 != "" { print $2, "refs/tags/" $1 }'
  fi
}

git_hash() {
  local url target
  url=$(upstream_url)
  [[ -n "$url" ]] || return 0
  target=$(remote_target "$url")
  printf '%s\n' "${target%% *}"
}

# git in root's mirror (made on first use)
git_mirror() {
  git "${git_safe[@]}" -C "$mirror" "$@"
}

current_hash() {
  if [[ "$source" == local ]]; then
    local_hash
  else
    git_hash
  fi
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
  agreety=false
  [[ -x "$root/usr/bin/agreety" ]] && agreety=true
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
  has_helper=false
  [[ -x "$helper" && -f "$policy" ]] && has_helper=true
  recorded=$(installed_source)
  installed_from=""
  case "$recorded" in
  local) installed_from=local ;;
  git\ *)
    rest=${recorded#git }
    installed_from="git:${rest%% *}"
    ;;
  esac
  url=""
  [[ "$source" == git ]] && url=$(upstream_url)
  jq -cn --argjson greetd "$greetd" --argjson agreety "$agreety" --arg dm "$dm" \
    --argjson installed "$installed" --argjson configured "$configured" --argjson helper "$has_helper" \
    --arg installedSource "$installed_from" --arg url "$url" \
    --arg installedHash "$installed_hash" --arg currentHash "$(current_hash)" \
    --arg greeterUser "$(greetd_value user)" --argjson bundleWritable "$writable" \
    '{greetd: $greetd, agreety: $agreety, displayManager: $dm, installed: $installed,
      configured: $configured, helper: $helper, installedSource: $installedSource, url: $url,
      installedHash: $installedHash, currentHash: $currentHash, greeterUser: $greeterUser,
      bundleWritable: $bundleWritable, error: ""}'
  ;;

hash)
  [[ -d "$repo" ]] || fail "no repo: $repo"
  current_hash
  ;;

install | update)
  [[ -d "$repo" ]] || fail "no repo: $repo"
  [[ -n "$user" ]] && id "$user" >/dev/null 2>&1 || fail "no such user: $user"
  # Through pkexec, the bundle's folder goes only to whoever authenticated
  if [[ -n "${PKEXEC_UID:-}" && "$(id -un "$PKEXEC_UID" 2>/dev/null)" != "$user" ]]; then
    fail "$user isn't the user who ran pkexec"
  fi
  [[ -f "$greetd_config" ]] || fail "greetd isn't installed ($greetd_config is missing)"
  # The login screen's fallback: without it a broken greeter locks everyone out
  [[ -x "$root/usr/bin/agreety" ]] || fail "agreety (greetd's text login, the login screen's fallback) isn't installed"
  [[ "$source" == git || "$source" == local ]] || fail "unknown source: $source"
  [[ "$channel" == tags || "$channel" == main ]] || fail "unknown channel: $channel"
  git_repo rev-parse --git-dir >/dev/null 2>&1 || fail "not a git clone: $repo"
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

  # The code, as a tar, and what names it (.greeter-hash, .greeter-source)
  tarball=$(mktemp) || fail "can't make a temporary file"
  trap 'rm -f "$tarball"' EXIT
  if [[ "$source" == local ]]; then
    local_archive >"$tarball" && [[ -s "$tarball" ]] || fail "copying $repo failed"
    hash=$(local_hash)
    origin=local
    label=$repo
  else
    url=$(upstream_url)
    [[ -n "$url" ]] || fail "$repo has no remote to fetch axiom from"
    target=$(remote_target "$url")
    [[ -n "$target" ]] || fail "nothing to fetch from $url on the $channel channel (offline?)"
    [[ -d "$mirror" ]] || git init -q --bare "$mirror" || fail "can't make $mirror"
    timeout 300 git "${git_safe[@]}" -C "$mirror" fetch -q --no-tags "$url" "+${target#* }:refs/axiom/target" ||
      fail "fetching ${target#* } from $url failed"
    hash=$(git_mirror rev-parse 'refs/axiom/target^{commit}') || fail "fetched nothing from $url"
    git_mirror archive --format=tar 'refs/axiom/target^{tree}' -- "${pathspec[@]}" >"$tarball" ||
      fail "archiving ${target#* } failed"
    origin="git $channel $url"
    label=${target#* refs/*/}
  fi

  # The copy: staged beside the old one, then swapped in
  stage="$install_dir.new"
  rm -rf "$stage" && mkdir -p "$stage" || fail "can't write $stage"
  tar -xf "$tarball" -C "$stage" --no-same-owner || fail "unpacking the copy failed"
  # A release from before the login screen existed has nothing to run
  for file in greeter.qml scripts/greeter/greeter-session.sh scripts/greeter/org.axiom.greeter.policy; do
    if [[ ! -f "$stage/$file" ]]; then
      rm -rf "$stage"
      fail "$label has no login screen (no $file): follow main, or use local"
    fi
  done
  printf '%s\n' "$hash" >"$stage/.greeter-hash"
  printf '%s\n' "$origin" >"$stage/.greeter-source"
  # What the user's axiom exported, as the copy's fallback config: written
  # by this same code, so it loads whatever the bundle later becomes. On a
  # first install the bundle isn't there yet, so axiom stages it first.
  # Either folder is the user's: a link there is copied as a link (-P),
  # never followed by root
  bundle="$var_dir/config"
  [[ -n "$staged" && -d "$staged" && ! -L "$staged" ]] && bundle=$staged
  mkdir -p "$stage/fallback"
  for name in greeter.json theme.json; do
    [[ -f "$bundle/$name" && ! -L "$bundle/$name" ]] && cp -P "$bundle/$name" "$stage/fallback/$name"
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

  # The polkit action naming the copy's own script: update and uninstall
  # ask for it by name, and run root's file rather than the user's
  install -D -m 644 "$install_dir/scripts/greeter/org.axiom.greeter.policy" "$policy" || fail "can't write $policy"
  changed+=("$policy")

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
  for dir in "$install_dir" "$var_dir" "$policy"; do
    if [[ -e "$dir" ]]; then
      rm -rf "$dir" || fail "can't remove $dir"
      changed+=("$dir")
    fi
  done
  emit
  ;;

*)
  fail "usage: greeter_install.sh check|hash <repo> [<source> [<channel>]] | install|update <repo> <user> [<staged bundle> [<source> [<channel>]]] | uninstall <repo> <user>"
  ;;
esac
