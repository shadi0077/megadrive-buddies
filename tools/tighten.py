"""Shrink each character's canvas to the frames its animations actually use.

Usage: tighten.py [character ...]      (default: everyone in the product)

A sheet's widest frame is often something the app never plays — a whole row of
credits, a 400-pixel banner, a pose from a section nobody authored. The canvas
is sized from all of them, and the window follows the canvas, so Dr. Robotnik
ended up as a 38-pixel sprite in a 430-point window. Nothing looks wrong, but
the window's centre is nowhere near the character, and that centre is what
proximity, facing and screen-edge clamping are measured from.

Sprite size on screen is unaffected: the view scales the canvas, and a frame
keeps its proportion of it either way.
"""
import json, sys
from pathlib import Path

ROOT = Path("app/Resources/characters")
names = sys.argv[1:] or [d.name for d in sorted(ROOT.iterdir())
                         if (d / "animations.json").exists()]

for name in names:
    root = ROOT / name
    meta = json.load(open(root / "frames.json"))
    anims = json.load(open(root / "animations.json"))["animations"]
    used = sorted({s["f"] for a in anims.values() for s in a["steps"]})
    if not used:
        print(f"{name}: no animations, left alone")
        continue

    frames = meta["frames"]
    boxes = [frames[i] for i in used if i < len(frames) and frames[i]]
    cw = max(f["w"] for f in boxes) + 8
    ch = max(f["h"] for f in boxes) + 8
    was = meta["canvas"]
    if (cw, ch) == (was["w"], was["h"]):
        print(f"{name}: already tight at {cw}x{ch}")
        continue

    for f in frames:
        if not f:
            continue
        # Bottom-centre, the same anchoring the cutters use.
        f["x"] = (cw - f["w"]) // 2
        f["y"] = ch - f["h"] - 4
    meta["canvas"] = {"w": cw, "h": ch}
    json.dump(meta, open(root / "frames.json", "w"))
    print(f"{name}: canvas {was['w']}x{was['h']} -> {cw}x{ch} "
          f"({len(used)} frames in play)")
