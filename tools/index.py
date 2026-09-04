"""Render a numbered contact sheet of a character's packed frames.

Usage: index.py <character> [columns]

The only reliable way to author animation ranges from a game rip: cut the
sheet, render every frame with its index under it, and look. Captions printed
above a sprite end up inside its frame and are a normal size, so no filter
catches them — you have to see them.
"""
from PIL import Image, ImageDraw, ImageFont
import json, sys
from pathlib import Path

name = sys.argv[1]
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 12

root = Path("app/Resources/characters") / name
frames = json.load(open(root / "frames.json"))["frames"]
count = len(frames)
FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 13)

cell_w = max(f["w"] for f in frames if f) + 12
cell_h = max(f["h"] for f in frames if f) + 26
rows = (count + cols - 1) // cols

sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (28, 28, 32, 255))
draw = ImageDraw.Draw(sheet)
for i in range(count):
    path = root / "frames" / f"{i:04d}.png"
    if not path.exists():
        continue
    art = Image.open(path).convert("RGBA")
    x, y = (i % cols) * cell_w, (i // cols) * cell_h
    sheet.alpha_composite(art, (x + (cell_w - art.width) // 2,
                                y + (cell_h - 20 - art.height)))
    draw.text((x + cell_w / 2, y + cell_h - 17), str(i),
              font=FONT, fill=(150, 150, 158, 255), anchor="ma")

Path("tools/out").mkdir(parents=True, exist_ok=True)
out = Path("tools/out") / f"{name}-index.png"
sheet.save(out)
print(f"{out}  {count} frames, {cols} per row")
