"""Labelled contact strips, one row per run of full-body frames.

Usage: strips.py <character>
"""
from PIL import Image, ImageDraw, ImageFont
import json, os, sys

name = sys.argv[1] if len(sys.argv) > 1 else "peedy"
kinds = {int(k): v for k, v in json.load(open(f"tools/out/{name}-kinds.json")).items()}
order = sorted(kinds)

runs = []
for i in order:
    k = kinds[i]
    if runs and runs[-1][0] == k and runs[-1][2] == i - 1:
        runs[-1][2] = i
    else:
        runs.append([k, i, i])
full = [(a, b) for k, a, b in runs if k == "F"]

out_dir = f"sheets/{name}/runs"
os.makedirs(out_dir, exist_ok=True)
TW, TH, PAD, COLS, BATCH = 92, 74, 16, 12, 10
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 12)
except Exception:
    font = ImageFont.load_default()


def sample(a, b, n=COLS):
    idx = list(range(a, b + 1))
    if len(idx) <= n:
        return idx
    return [idx[round(j * (len(idx) - 1) / (n - 1))] for j in range(n)]


for start in range(0, len(full), BATCH):
    group = full[start:start + BATCH]
    W = COLS * (TW + 4) + 150
    H = len(group) * (TH + PAD + 6) + 10
    sheet = Image.new("RGB", (W, H), (38, 38, 54))
    d = ImageDraw.Draw(sheet)
    for r, (a, b) in enumerate(group):
        y = 10 + r * (TH + PAD + 6)
        d.text((6, y + TH // 2 - 8), f"{a}-{b}\n({b - a + 1}f)", font=font, fill=(255, 220, 120))
        for c, fi in enumerate(sample(a, b)):
            im = Image.open(f"assets/{name}/rgba/{fi:04d}.png").convert("RGBA")
            im = im.resize((TW, TH), Image.LANCZOS)
            bg = Image.new("RGB", (TW, TH), (60, 60, 80))
            bg.paste(im, (0, 0), im)
            x = 140 + c * (TW + 4)
            sheet.paste(bg, (x, y))
            d.text((x + 2, y + TH + 1), str(fi), font=font, fill=(180, 200, 255))
    sheet.save(f"{out_dir}/runs_{start:03d}.png")

print(f"{name}: {len(full)} full runs -> {(len(full) + BATCH - 1) // BATCH} sheets")
