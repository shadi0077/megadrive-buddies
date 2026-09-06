"""Trim keyed frames to their opaque bounds and emit a manifest.

Usage: pack.py <character>
"""
from PIL import Image
import json, os, shutil, sys, glob

name = sys.argv[1]
SRC = f"assets/{name}/rgba"
OUT = f"app/Resources/characters/{name}/frames"
if os.path.isdir(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT, exist_ok=True)

paths = sorted(glob.glob(f"{SRC}/*.png"))
indices = [int(os.path.splitext(os.path.basename(p))[0]) for p in paths]
size = Image.open(paths[0]).size

# Indexed by frame number, so the catalogue can refer to frames directly.
frames = [None] * (max(indices) + 1)
for path, index in zip(paths, indices):
    im = Image.open(path).convert("RGBA")
    bb = im.getbbox()
    if bb is None:
        continue
    x0, y0, x1, y1 = bb
    im.crop(bb).save(f"{OUT}/{index:04d}.png", optimize=True)
    frames[index] = dict(x=x0, y=y0, w=x1 - x0, h=y1 - y0)

json.dump(dict(canvas=dict(w=size[0], h=size[1]), frames=frames),
          open(f"app/Resources/characters/{name}/frames.json", "w"))
total = sum(os.path.getsize(f"{OUT}/{f}") for f in os.listdir(OUT))
print(f"{name}: {sum(1 for f in frames if f)} frames, canvas {size[0]}x{size[1]}, "
      f"{total / 1024 / 1024:.2f} MB")
