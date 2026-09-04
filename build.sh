#!/bin/bash
# Builds every product in products/ — there is one, MegaDrive Buddies.
#
#   ./build.sh                       all of them
#   ./build.sh megadrive-buddies     just that one
#
# A product is a manifest naming a cast; the build copies only that cast's
# sprites and stamps the name and bundle identifier into the app.
set -euo pipefail
cd "$(dirname "$0")"

build_one() {
    local manifest="products/$1.json"
    [ -f "$manifest" ] || { echo "no such product: $1"; exit 1; }

    local name bundle
    name=$(python3 -c "import json;print(json.load(open('$manifest'))['name'])")
    bundle=$(python3 -c "import json;print(json.load(open('$manifest'))['bundleID'])")

    local app="build/$name.app"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

    swiftc -O \
      -target arm64-apple-macos11.0 \
      -framework AppKit -framework ServiceManagement -framework AVFoundation \
      app/Sources/*.swift \
      -o "$app/Contents/MacOS/$name"

    python3 - "$manifest" "$app" <<'PY'
import json, plistlib, shutil, sys
from pathlib import Path

manifest, app = json.load(open(sys.argv[1])), Path(sys.argv[2])
name = manifest["name"]

plist = plistlib.load(open("app/Info.plist", "rb"))
plist.update({
    "CFBundleName": name,
    "CFBundleDisplayName": name,
    "CFBundleExecutable": name,
    "CFBundleIdentifier": manifest["bundleID"],
})
plistlib.dump(plist, open(app / "Contents/Info.plist", "wb"))
json.dump(manifest, open(app / "Contents/Resources/product.json", "w"))

# Only this product's characters, plus whatever they share — and within a
# character, only the frames its animations actually play. The repository
# keeps every frame a sheet gave up, because that is what the next animation
# gets authored from; the app has no use for the other nine tenths of them.
# Earthworm Jim's sheet alone is 1046 frames and he performs 25.
dest = app / "Contents/Resources/characters"
dest.mkdir(parents=True, exist_ok=True)
kept = dropped = 0
for who in manifest["cast"] + manifest.get("sharedResources", []):
    src = Path("app/Resources/characters") / who
    if not src.is_dir():
        print(f"  warning: {who} has no resources")
        continue
    target = dest / who
    target.mkdir(parents=True)
    for item in src.iterdir():
        if item.name == "frames":
            continue
        (shutil.copytree if item.is_dir() else shutil.copy)(item, target / item.name)

    anims = src / "animations.json"
    if not (src / "frames").is_dir():
        continue
    used = set()
    if anims.exists():
        catalogue = json.load(open(anims))
        for clip in catalogue["animations"].values():
            used.update(step["f"] for step in clip["steps"])
        # The menu-bar frame is a portrait no animation plays, and dropping it
        # leaves the status item blank — which on a menu-bar-only app means no
        # way into the thing at all.
        used.add(catalogue.get("icon", 0))
    (target / "frames").mkdir()
    for frame in sorted((src / "frames").iterdir()):
        if frame.suffix != ".png":
            continue
        if int(frame.stem) in used:
            shutil.copy(frame, target / "frames" / frame.name)
            kept += 1
        else:
            dropped += 1
print(f"  frames: {kept} shipped, {dropped} left in the repository")

icon = Path(f"app/Resources/{manifest['id']}.icns")
if icon.exists():
    shutil.copy(icon, app / "Contents/Resources/AppIcon.icns")
PY

    codesign --force --deep --sign - "$app" >/dev/null 2>&1 || \
      echo "note: ad-hoc codesign skipped"

    local size
    size=$(du -sh "$app" | cut -f1 | tr -d ' ')
    echo "built $app  ($size)"
}

if [ $# -ge 1 ]; then
    build_one "$1"
else
    for m in products/*.json; do
        build_one "$(basename "$m" .json)"
    done
fi
