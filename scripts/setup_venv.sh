#!/usr/bin/env bash
# Creates/updates the venv used by the python scripts (generate_theme.py).
# A no-op while requirements.txt and the system python are unchanged, so it
# runs before every generation (scripts/venv_python.sh). --force reinstalls.
set -euo pipefail

AXIOM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$AXIOM_DIR/.venv"
REQUIREMENTS="$AXIOM_DIR/scripts/requirements.txt"
STAMP="$VENV_DIR/.requirements.stamp"

# The venv links to the system python: a python upgrade leaves its
# site-packages behind, so the version is part of the stamp
stamp="$(python3 --version 2>&1) $(sha256sum "$REQUIREMENTS" | cut -d' ' -f1)"

if [[ "${1:-}" != "--force" && -x "$VENV_DIR/bin/python3" && -f "$STAMP" && "$(<"$STAMP")" == "$stamp" ]]; then
  exit 0
fi

echo "Setting up the python venv at $VENV_DIR..." >&2
if [[ ! -f "$STAMP" || "$(<"$STAMP")" != "$(python3 --version 2>&1) "* ]]; then
  python3 -m venv --clear "$VENV_DIR" >&2
fi
"$VENV_DIR/bin/pip" install --upgrade pip --quiet >&2
"$VENV_DIR/bin/pip" install --upgrade --quiet -r "$REQUIREMENTS" >&2
echo "$stamp" >"$STAMP"

echo "venv ready at $VENV_DIR" >&2
