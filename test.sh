#!/bin/bash
# Checks for the pure logic, plus headless renders into shots/ so the sprite
# work can be eyeballed without needing screen-recording permission.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build shots

APPKIT="-framework AppKit -framework ServiceManagement -framework AVFoundation"
CORE="app/Sources/SpriteStore.swift app/Sources/BuddyView.swift"
CAST="app/Sources/Personality.swift app/Sources/AxelPersonality.swift
      app/Sources/SoRPersonalities.swift app/Sources/RecentPicks.swift"
ENGINE="app/Sources/Animator.swift app/Sources/BuddyWindow.swift
        app/Sources/SoundBank.swift app/Sources/Brain.swift"

echo "== deployment target =="
./build.sh >/dev/null
APP="build/MegaDrive Buddies.app"
PLIST_MIN=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" app/Info.plist)
BIN_MIN=$(otool -l "$APP/Contents/MacOS/MegaDrive Buddies" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')
ARCH=$(lipo -info "$APP/Contents/MacOS/MegaDrive Buddies" | sed 's/.*: //')
echo "  Info.plist $PLIST_MIN / binary $BIN_MIN / $ARCH"
# macOS 11 is the first release that ran on Apple Silicon.
[ "$PLIST_MIN" = "11.0" ] || { echo "  FAIL Info.plist minimum is $PLIST_MIN, expected 11.0"; exit 1; }
[ "$BIN_MIN" = "11.0" ] || { echo "  FAIL binary minos is $BIN_MIN, expected 11.0"; exit 1; }
case "$ARCH" in *arm64*) ;; *) echo "  FAIL missing arm64 slice"; exit 1;; esac
echo "  ok   runs on every macOS that has shipped on Apple Silicon"

echo
echo "== the cast =="
swiftc -O $APPKIT $CORE $CAST $ENGINE app/Sources/Product.swift \
  tools/casttest/main.swift -o build/casttest
BUDDY_PRODUCT="products/megadrive-buddies.json" BUDDY_APP="$APP" ./build/casttest

echo
echo "== one sprite per frame =="
swiftc -O $APPKIT $CORE $CAST $ENGINE app/Sources/Product.swift \
  tools/framestest/main.swift -o build/framestest
BUDDY_APP="$APP" ./build/framestest

echo
echo "== wander logic =="
swiftc -O $APPKIT $CORE $CAST $ENGINE app/Sources/Product.swift \
  tools/wandertest/main.swift -o build/wandertest
./build/wandertest

echo
echo "== liveliness =="
swiftc -O $APPKIT $CORE $CAST $ENGINE app/Sources/Product.swift \
  tools/alivetest/main.swift -o build/alivetest
./build/alivetest

echo
echo "== volume slider =="
swiftc -O -framework AppKit app/Sources/VolumeSlider.swift tools/uitest/main.swift -o build/uitest
./build/uitest

echo
echo "== menu-bar icon =="
swiftc -O -framework AppKit $CORE app/Sources/Product.swift $CAST \
  tools/icontest/main.swift -o build/icontest
BUDDY_APP="$APP" ./build/icontest

echo
echo "== headless renders =="
swiftc -O -framework AppKit $CORE tools/render/main.swift -o build/render
for who in axel blaze max skate adam axel1 blaze1 galsia donovan eagle slum; do
  ./build/render "$APP" "$who" >/dev/null
done
echo "sheets in shots/"
