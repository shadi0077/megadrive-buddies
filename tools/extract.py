"""Key out the flat background and measure every frame.

Usage: extract.py <character> [r,g,b]

The key differs per dump — cyan for the BonziBUDDY pair, magenta or green or
a flat orange for the Office assistants — so it's read off the art rather than
assumed: the colour filling the corners of a frame with plenty of empty space
around the character.
"""
from PIL import Image
from collections import Counter
import json, os, sys, glob

name = sys.argv[1] if len(sys.argv) > 1 else "peedy"
SRC = f"assets/{name}/frames"
OUT = f"assets/{name}/rgba"
os.makedirs(OUT, exist_ok=True)

paths = sorted(glob.glob(f"{SRC}/*.png"))
if not paths:
    raise SystemExit(f"no frames in {SRC}")


def detect_key():
    """The background colour, from the corners of a sample of frames."""
    votes = Counter()
    for path in paths[::max(1, len(paths) // 40)]:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
            votes[im.getpixel((x, y))] += 1
    return votes.most_common(1)[0][0]


KEY = (tuple(int(v) for v in sys.argv[2].split(",")) if len(sys.argv) > 2
       else detect_key())
print(f"{name}: keying out rgb{KEY}")

meta = []
for path in paths:
    index = int(os.path.splitext(os.path.basename(path))[0])
    im = Image.open(path).convert("RGBA")
    px = im.load()
    W, H = im.size
    minx, miny, maxx, maxy, count = W, H, -1, -1, 0
    for y in range(H):
        for x in range(W):
            r, g, b, _ = px[x, y]
            if (r, g, b) == KEY:
                px[x, y] = (0, 0, 0, 0)
            else:
                count += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
    im.save(f"{OUT}/{index:04d}.png")
    if maxx < 0:
        meta.append(dict(i=index, x=0, y=0, w=0, h=0, px=0))
    else:
        meta.append(dict(i=index, x=minx, y=miny,
                         w=maxx - minx + 1, h=maxy - miny + 1, px=count))

os.makedirs("tools/out", exist_ok=True)
json.dump(dict(canvas=dict(w=W, h=H), frames=meta),
          open(f"tools/out/{name}-meta.json", "w"))
print(f"{name}: {len(meta)} frames, canvas {W}x{H}")
