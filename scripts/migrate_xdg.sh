#!/usr/bin/env bash
# Copies an install's data out of the repo into the XDG folders, once
# (DataMigrationManager runs it from a session still on the old folders):
#   migrate_xdg.sh MARKER FROM TO [FROM TO ...]
# Each FROM folder's contents go into TO, never overwriting what's there; a
# FROM inside another FROM is left to its own pair. config.json goes last,
# written whole (temp file + rename), then MARKER, which says where
# everything went: the shell takes its presence as "moved". The FROM
# folders are kept (an older axiom still reads them). Prints the pairs
# copied; exits non-zero, writing no marker, if anything failed.
set -euo pipefail

if [[ $# -lt 3 || $(($# % 2)) -ne 1 ]]; then
  sed -n 2,10p "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

marker="$1"
shift
from=() to=()
while [[ $# -gt 0 ]]; do
  from+=("${1%/}")
  to+=("${2%/}")
  shift 2
done

# Whether $1 is another pair's FROM (copied by that pair, not this one)
is_other_from() {
  local f
  for f in "${from[@]}"; do
    [[ "$1" == "$f" ]] && return 0
  done
  return 1
}

config_from="" config_to=""
for i in "${!from[@]}"; do
  src="${from[$i]}" dst="${to[$i]}"
  [[ -d "$src" ]] || continue
  mkdir -p "$dst"
  shopt -s nullglob dotglob
  for entry in "$src"/*; do
    is_other_from "$entry" && continue
    name="${entry##*/}"
    if [[ "$name" == config.json && -f "$entry" ]]; then
      config_from="$entry" config_to="$dst/config.json"
      continue
    fi
    [[ "$entry" == "$marker" ]] && continue
    cp -an -- "$entry" "$dst/"
  done
  shopt -u nullglob dotglob
  echo "$src -> $dst"
done

# Last, whole: a copy cut short never leaves a partial config.json behind
if [[ -n "$config_from" && ! -e "$config_to" ]]; then
  tmp="$(mktemp "$config_to.XXXXXX")"
  cp -- "$config_from" "$tmp"
  mv -n -- "$tmp" "$config_to"
  rm -f -- "$tmp"
fi

{
  echo "# Moved"
  echo
  echo "axiom now keeps its config and state in the XDG folders. These were copied there on $(date -I):"
  echo
  for i in "${!from[@]}"; do
    echo "- \`${from[$i]}/\` → \`${to[$i]}/\`"
  done
  echo
  echo "The copies here are no longer read (only an older axiom would read them) and can be deleted."
} >"$marker.tmp"
mv -- "$marker.tmp" "$marker"
