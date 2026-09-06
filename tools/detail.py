"""Every frame in a range, labelled. Usage: detail.py <character> <a> <b> <name>"""
from PIL import Image, ImageDraw, ImageFont
import sys, os

name, a, b, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
TW, TH, COLS, PAD = 104, 84, 10, 18
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 12)
except Exception:
    font = ImageFont.load_default()
idx = list(range(a, b + 1))
rows = (len(idx) + COLS - 1) // COLS
sheet = Image.new("RGB", (COLS * (TW + 4) + 8, rows * (TH + PAD) + 8), (38, 38, 54))
d = ImageDraw.Draw(sheet)
for n, fi in enumerate(idx):
    r, c = divmod(n, COLS)
    x, y = 6 + c * (TW + 4), 6 + r * (TH + PAD)
    try:
        im = Image.open(f"assets/{name}/rgba/{fi:04d}.png").convert("RGBA").resize((TW, TH), Image.LANCZOS)
    except FileNotFoundError:
        continue
    bg = Image.new("RGB", (TW, TH), (60, 60, 80))
    bg.paste(im, (0, 0), im)
    sheet.paste(bg, (x, y))
    d.text((x + 2, y + TH + 2), str(fi), font=font, fill=(255, 220, 120))
os.makedirs(f"sheets/{name}/detail", exist_ok=True)
sheet.save(f"sheets/{name}/detail/{out}.png")
print("ok")
