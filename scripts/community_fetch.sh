#!/usr/bin/env bash
# Downloads community setup files (CommunitySetupsManager): each URL to its
# destination, checked against its sha256 when one is given, written
# atomically (a .part file renamed into place), so a half-downloaded or
# tampered file never lands. A destination already holding that sha256 is
# kept without downloading (the cache).
#
#   community_fetch.sh URL DEST SHA256|- [URL DEST SHA256|- ...]
#
# Prints one line per file, "ok DEST" or "fail DEST REASON", and exits 1
# if any failed. Files are capped at 20 MB; only http(s) is fetched.
set -uo pipefail

if [ $# -eq 0 ] || [ $(($# % 3)) -ne 0 ]; then
  echo "usage: $0 URL DEST SHA256|- [URL DEST SHA256|- ...]" >&2
  exit 2
fi

status=0
while [ $# -gt 0 ]; do
  url="$1" dest="$2" sha="$3"
  shift 3
  if [ "$sha" != "-" ] && [ -f "$dest" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$sha" ]; then
    echo "ok $dest"
    continue
  fi
  if ! mkdir -p "$(dirname "$dest")"; then
    echo "fail $dest can't make its folder"
    status=1
    continue
  fi
  part="$dest.part"
  if ! error=$(curl --fail --silent --show-error --location --proto =https,http --max-time 60 --max-filesize 20971520 -o "$part" -- "$url" 2>&1); then
    rm -f "$part"
    echo "fail $dest ${error//$'\n'/ }"
    status=1
    continue
  fi
  if [ "$sha" != "-" ] && [ "$(sha256sum "$part" | cut -d' ' -f1)" != "$sha" ]; then
    rm -f "$part"
    echo "fail $dest checksum mismatch"
    status=1
    continue
  fi
  if mv -f "$part" "$dest"; then
    echo "ok $dest"
  else
    rm -f "$part"
    echo "fail $dest can't write it"
    status=1
  fi
done
exit $status
