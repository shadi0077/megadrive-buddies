#!/bin/bash
# Cut a sprite sheet into a character's asset pack.
#
# The packed sprites are committed, so a clone builds and runs without this.
# You need it only to add a character, or to redo one from a different rip.
#
#   ./setup.sh <name> <sheet.png> [key_r,key_g,key_b | alpha] [y0:y1]
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -lt 2 ]; then
    cat <<'USAGE'
usage: ./setup.sh <name> <sheet.png> [key | alpha] [y0:y1]

  name        what the character will be called, e.g. "shiva"
  sheet.png   a spriters-resource style sheet: frames laid out in rows
  key         background colour to knock out, "r,g,b" (default 204,255,204).
              Pass "alpha" if the sheet already has a transparent background;
              it is auto-detected either way.
  y0:y1       optional horizontal slice, for sheets holding several characters

Then author the clip ranges in tools/catalog.py and add a Personality — see
CONTRIBUTING.md. Render the numbered index first:

    python3 tools/index.py <name>
USAGE
    exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: $1 is required"; exit 1; }; }
need python3
need swiftc
python3 -c "import PIL" 2>/dev/null || {
    echo "==> installing Pillow (image tooling)"
    python3 -m pip install --quiet --user pillow
}

echo "==> cutting the sheet"
python3 tools/sheet.py "$@"

echo "==> rendering the numbered index"
python3 tools/index.py "$1"

cat <<DONE

Frames are in app/Resources/characters/$1/.
Open tools/out/$1-index.png, note which frames belong to which animation,
then add the ranges to tools/catalog.py and a Personality in app/Sources/.

DONE
