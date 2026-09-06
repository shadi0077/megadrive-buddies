"""Build a product's AppIcon.icns from one of its character's frames.

Usage: icon.py <product-id>
"""
from PIL import Image
import json, os, shutil, subprocess, sys

pid = sys.argv[1]
manifest = json.load(open(f"products/{pid}.json"))
who, frame = manifest["iconCharacter"], manifest["iconFrame"]

src = f"app/Resources/characters/{who}/frames/{frame:04d}.png"
if not os.path.exists(src):
    raise SystemExit(f"no such frame: {src}")

art = Image.open(src).convert("RGBA")
art = art.crop(art.getbbox())

work = f"build/{pid}.iconset"
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)

# Pixel art stays crisp; the rendered characters get smoothed.
pixel = who not in ("peedy", "bonzi")
resample = Image.NEAREST if pixel else Image.LANCZOS

for size in (16, 32, 64, 128, 256, 512, 1024):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Leave a margin so it doesn't crowd the edges of the tile.
    inner = int(size * 0.82)
    scale = min(inner / art.width, inner / art.height)
    w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
    canvas.paste(art.resize((w, h), resample), ((size - w) // 2, (size - h) // 2))
    for name, px in [(f"icon_{size}x{size}.png", size),
                     (f"icon_{size // 2}x{size // 2}@2x.png", size)]:
        if px == size and (name.endswith("@2x.png") and size == 16):
            continue
        canvas.save(f"{work}/{name}")

subprocess.run(["iconutil", "-c", "icns", work,
                "-o", f"app/Resources/{pid}.icns"], check=True)
shutil.rmtree(work, ignore_errors=True)
print(f"{pid}: icon from {who} frame {frame}")
