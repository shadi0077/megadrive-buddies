"""Cut a spriters-resource style sheet into frames.

A rip is a single sheet with frames laid out in irregular rows, so it needs
segmenting: find bands of content, then columns within each band, then split
each column at its own vertical gaps.

Usage: sheet.py <character> <sheet.png> [key_r,key_g,key_b | alpha] [y0:y1]

Caveat worth knowing before authoring animations: a caption printed directly
beside a sprite ends up inside that frame, because the column containing both
is one run of content. Those frames look normal by size, so they can't be
filtered out automatically — render the numbered index (tools/index.py) and
look. Blaze's walk cycle
starts two frames later than it appears to for exactly this reason.
"""
from PIL import Image
import json, os, shutil, sys

name = sys.argv[1]
src = sys.argv[2]
key_arg = sys.argv[3] if len(sys.argv) > 3 else "204,255,204"
# Optional "y0:y1" to take a horizontal slice, for sheets carrying more than
# one character.
slice_arg = sys.argv[4] if len(sys.argv) > 4 else None

im = Image.open(src).convert("RGBA")
if slice_arg:
    y0, y1 = (int(v) for v in slice_arg.split(":"))
    im = im.crop((0, y0, im.width, y1))
W, H = im.size
px = im.load()

# Some rips key the background by colour, others leave it genuinely
# transparent. Decide from the file rather than from the argument.
transparent = sum(1 for _ in range(0, W, 7) for y in range(0, H, 7)
                  if px[_, y][3] == 0)
use_alpha = key_arg == "alpha" or transparent > (W // 7) * (H // 7) * 0.3
key = None if use_alpha else tuple(int(v) for v in key_arg.split(","))


def is_background(x, y):
    p = px[x, y]
    return p[3] == 0 if key is None else p[:3] == key

# Bands: horizontal runs that contain any non-key pixel.
bands = []
run = None
for y in range(H):
    filled = any(not is_background(x, y) for x in range(W))
    if filled and run is None:
        run = y
    elif not filled and run is not None:
        bands.append((run, y - 1))
        run = None
if run is not None:
    bands.append((run, H - 1))

# Frames: within a band, vertical runs of content, then trimmed to their own
# bounding box so a tall band doesn't pad every frame in it.
frames = []          # (band, x0, y0, x1, y1)
for b, (y0, y1) in enumerate(bands):
    cols, run = [], None
    for x in range(W):
        filled = any(not is_background(x, y) for y in range(y0, y1 + 1))
        if filled and run is None:
            run = x
        elif not filled and run is not None:
            if x - run > 3:
                cols.append((run, x - 1))
            run = None
    if run is not None and W - run > 3:
        cols.append((run, W - 1))

    for (x0, x1) in cols:
        ys = [y for y in range(y0, y1 + 1)
              if any(not is_background(x, y) for x in range(x0, x1 + 1))]
        if not ys:
            continue
        # A band is a run of content across the whole sheet, so a column inside
        # it can still hold two sprites stacked vertically — that happens
        # wherever the sheet packs a short second row. Split the column at its
        # own gaps, or the two end up in one frame and the character renders
        # with a second body growing out of his head. (Galsia did.)
        runs, start, prev = [], ys[0], ys[0]
        for y in ys[1:]:
            if y - prev > 4:
                runs.append((start, prev))
                start = y
            prev = y
        runs.append((start, prev))

        for (top, bottom) in runs:
            if (x1 - x0 + 1) < 8 or (bottom - top + 1) < 8:
                continue      # ruler marks and stray pixels, not frames
            frames.append((b, x0, top, x1, bottom))

# One canvas for everyone, anchored bottom-centre so his feet stay planted.
cw = max(f[3] - f[1] + 1 for f in frames) + 8
ch = max(f[4] - f[2] + 1 for f in frames) + 8

out = f"app/Resources/characters/{name}"
if os.path.isdir(f"{out}/frames"):
    shutil.rmtree(f"{out}/frames")
os.makedirs(f"{out}/frames", exist_ok=True)

manifest, index = [], []
for i, (b, x0, y0, x1, y1) in enumerate(frames):
    w, h = x1 - x0 + 1, y1 - y0 + 1
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    cp = crop.load()
    for y in range(h):
        for x in range(w):
            if key is not None and cp[x, y][:3] == key:
                cp[x, y] = (0, 0, 0, 0)
    crop.save(f"{out}/frames/{i:04d}.png", optimize=True)
    manifest.append(dict(x=(cw - w) // 2, y=ch - h - 4, w=w, h=h))
    index.append(dict(i=i, band=b, w=w, h=h))

json.dump(dict(canvas=dict(w=cw, h=ch), frames=manifest),
          open(f"{out}/frames.json", "w"))
os.makedirs("tools/out", exist_ok=True)
json.dump(dict(bands=len(bands), frames=index), open(f"tools/out/{name}-sheet.json", "w"))

total = sum(os.path.getsize(f"{out}/frames/{f}") for f in os.listdir(f"{out}/frames"))
print(f"{name}: {len(frames)} frames from {len(bands)} bands "
      f"({'alpha' if key is None else 'key ' + str(key)}), "
      f"canvas {cw}x{ch}, {total/1024:.0f} KB")
for b in range(len(bands)):
    n = sum(1 for f in index if f["band"] == b)
    if n:
        print(f"   band {b:2d}: frames {min(f['i'] for f in index if f['band']==b)}"
              f"-{max(f['i'] for f in index if f['band']==b)}  ({n})")
