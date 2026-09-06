#!/bin/bash
# Builds one product, or both.
#
#   ./build.sh                     both
#   ./build.sh desktop-buddies     just that one
#
# One codebase, two apps: they share the whole engine and differ only in who
# ships with them and what the app is called. Each gets its own bundle
# identifier, so both can run at once and keep their own settings.
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
# character, only the frames it can actually put on screen. The repository
# keeps every frame a sheet gave up, because that is what the next animation
# gets authored from; the app has no use for the other nine tenths. Earthworm
# Jim's sheet is 1046 frames and he performs 25.
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

    catalogue_path = src / "animations.json"
    if not (src / "frames").is_dir():
        continue
    used = set()
    if catalogue_path.exists():
        catalogue = json.load(open(catalogue_path))
        for clip in catalogue["animations"].values():
            for step in clip["steps"]:
                used.add(step["f"])
                # Mouth patches and eye blinks are overlays composited onto a
                # body frame, and they are frames too.
                if step.get("o") is not None:
                    used.add(step["o"])
        # A talk pose holds a body frame and a set of mouth patches that no
        # animation lists, and the hero frame is a portrait nothing plays.
        for pose in catalogue.get("talk", {}).values():
            used.add(pose["body"])
            used.update(pose.get("mouths", []))
            used.update(pose.get("ramp", []))
        used.add(catalogue.get("hero", 0))
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
