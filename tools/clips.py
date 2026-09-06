"""Render every authored clip as a labelled strip, one row per animation.

`index.py` answers "what is on the sheet". This answers the next question, and
the one that actually ships: "did the ranges I wrote in `catalog.py` land on
the frames I meant". Those are different failures. A clip can name frames that
all exist, sit in the right row, and still be four frames of a caption, the
tail of the previous animation, or a walk cycle that starts one frame late and
limps.

Nothing catches that but looking at the clip itself, in order, as a strip.

Usage: clips.py <character> [scale]

Writes sheets/<character>/clips.png — every animation the character has, in
`animations.json` order, each row labelled with the clip name, its frame rate,
whether it loops, and the frame numbers it plays.
"""
from PIL import Image, ImageDraw, ImageFont
import json, os, sys

name = sys.argv[1]
scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0

anims = json.load(open(f"app/Resources/characters/{name}/animations.json"))["animations"]
src = f"app/Resources/characters/{name}/frames"

CELL = int(76 * scale)
GUTTER = 190
PAD, LABEL = 4, 13
MAX_COLS = 16

try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 11)
    head = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 13)
except Exception:
    font = head = ImageFont.load_default()

rows = []
for clip, d in anims.items():
    frames = [s["f"] for s in d["steps"]]
    # A long clip is sampled rather than truncated: the end of a walk cycle is
    # exactly where it goes wrong, so it has to be on screen.
    shown = frames if len(frames) <= MAX_COLS else [
        frames[round(i * (len(frames) - 1) / (MAX_COLS - 1))] for i in range(MAX_COLS)]
    rows.append((clip, d, frames, shown))

W = GUTTER + MAX_COLS * (CELL + PAD) + PAD
H = 30 + len(rows) * (CELL + LABEL + PAD) + PAD
sheet = Image.new("RGB", (W, H), (26, 26, 36))
d = ImageDraw.Draw(sheet)
d.text((8, 9), f"{name}  —  {len(rows)} clips", font=head, fill=(255, 225, 140))

for r, (clip, meta, frames, shown) in enumerate(rows):
    y = 30 + r * (CELL + LABEL + PAD)
    loop = "loop" if meta["loop"] else "once"
    d.text((8, y + 4), clip, font=head, fill=(255, 210, 120))
    d.text((8, y + 20), f"{int(meta['fps'])} fps · {loop}", font=font, fill=(150, 170, 210))
    d.text((8, y + 34), f"{len(frames)}f", font=font, fill=(150, 170, 210))
    span = f"{frames[0]}-{frames[-1]}" if len(frames) > 1 else str(frames[0])
    d.text((8, y + 48), span, font=font, fill=(120, 140, 175))
    if len(shown) < len(frames):
        d.text((8, y + 62), "sampled", font=font, fill=(190, 140, 110))

    tint = (48, 52, 72) if r % 2 == 0 else (42, 58, 54)
    for c, fi in enumerate(shown):
        x = GUTTER + c * (CELL + PAD)
        cell = Image.new("RGB", (CELL, CELL), tint)
        path = f"{src}/{fi:04d}.png"
        if os.path.exists(path):
            im = Image.open(path).convert("RGBA")
            k = min(CELL / im.width, CELL / im.height, 3.0)
            im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))),
                           Image.NEAREST)
            # Bottom-aligned, the way the app anchors them, so a frame that
            # sits at the wrong height in the cycle is visible as a bob.
            cell.paste(im, ((CELL - im.width) // 2, CELL - im.height), im)
        else:
            d.text((x + 6, y + CELL // 2), "missing", font=font, fill=(255, 120, 120))
        sheet.paste(cell, (x, y))
        d.text((x + 2, y + CELL + 1), str(fi), font=font, fill=(170, 195, 235))

os.makedirs(f"sheets/{name}", exist_ok=True)
sheet.save(f"sheets/{name}/clips.png")
print(f"{name}: {len(rows)} clips -> sheets/{name}/clips.png")
