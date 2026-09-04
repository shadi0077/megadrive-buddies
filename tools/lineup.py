"""Render a product's cast as one lineup image, for the docs.

Usage: lineup.py <product-id> [clip] [out.png] [per-row]

One frame per character, bottom-aligned on a shared baseline within each row,
so the size differences between them are the real ones — a Mega Drive Sonic
really is half the height of Terry Bogard. Names underneath, scaled
nearest-neighbour, at the same per-character scale the app uses.
"""
from PIL import Image, ImageDraw, ImageFont
import json, sys
from pathlib import Path

pid = sys.argv[1]
clip = sys.argv[2] if len(sys.argv) > 2 else "walk"
out = Path(sys.argv[3] if len(sys.argv) > 3 else f"docs/img/{pid}.png")

manifest = json.load(open(f"products/{pid}.json"))
cast = [c for c in manifest["cast"] if not c.startswith("_")]

# Mirrors `Personality.title` where the id isn't presentable on its own.
TITLES = {"axel1": "Axel (1991)", "blaze1": "Blaze (1991)",
          "robotnik": "Dr. Robotnik", "mecha": "Mecha Sonic",
          "sonic3d": "Sonic (3D Blast)", "terry": "Terry Bogard"}

# Mirrors `Personality.scale`, so the lineup shows them at the sizes they
# actually stand at next to each other.
SCALES = {"axel": 1.55, "blaze": 1.55, "max": 1.55, "skate": 1.55,
          "adam": 1.7, "axel1": 1.7, "blaze1": 1.7, "galsia": 1.7,
          "donovan": 1.6, "eagle": 1.6, "slum": 1.6,
          "sonic": 2.4, "tails": 2.6, "knuckles": 2.4, "robotnik": 1.9,
          "mecha": 1.8, "ristar": 2.4, "terry": 1.3, "sonic3d": 2.0}

PAD, GAP, LABEL = 18, 14, 22
PER_ROW = int(sys.argv[4]) if len(sys.argv) > 4 else 10
FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 15)

art = []
for who in cast:
    root = Path("app/Resources/characters") / who
    anims = json.load(open(root / "animations.json"))["animations"]
    steps = (anims.get(clip) or anims["rest"])["steps"]
    # Mid-clip: the extremes of a walk cycle are the least representative frame.
    frame = steps[len(steps) // 2]["f"]
    img = Image.open(root / "frames" / f"{frame:04d}.png").convert("RGBA")
    img = img.crop(img.getbbox())
    k = SCALES.get(who, 1.6) * 1.15
    img = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))),
                     Image.NEAREST)
    art.append((who, img))

measure = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
def cell_width(who, img):
    # A cell is at least as wide as its caption, or "Sonic (3D Blast)" lands on
    # top of the character beside it.
    label = TITLES.get(who, who.capitalize())
    text = measure.textbbox((0, 0), label, font=FONT)[2]
    return max(img.width, text + 6)

rows = [art[i:i + PER_ROW] for i in range(0, len(art), PER_ROW)]
row_h = [max(i.height for _, i in r) + LABEL + GAP for r in rows]
width = PAD * 2 + max(sum(cell_width(w, i) for w, i in r) + GAP * (len(r) - 1)
                      for r in rows)
sheet = Image.new("RGBA", (width, PAD * 2 + sum(row_h)), (0, 0, 0, 0))
draw = ImageDraw.Draw(sheet)

y = PAD
for row, height in zip(rows, row_h):
    tall = height - LABEL - GAP
    x = PAD
    for who, img in row:
        cw = cell_width(who, img)
        sheet.alpha_composite(img, (x + (cw - img.width) // 2, y + tall - img.height))
        draw.text((x + cw / 2, y + tall + 6), TITLES.get(who, who.capitalize()),
                  font=FONT, fill=(122, 122, 128, 255), anchor="ma")
        x += cw + GAP
    y += height

out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"{out}  {sheet.width}x{sheet.height}  {len(art)} characters")
