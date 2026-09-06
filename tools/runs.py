"""Find where one animation stops and the next begins, and draw the result.

The BonziBUDDY dumps interleave overlay patches between animations, so the
patches themselves mark the boundaries. The Office assistant sheets have far
fewer patches — several have none at all — leaving one unbroken run of several
hundred frames, which no contact strip can show usefully.

So boundaries are found from the art instead: consecutive frames inside an
animation look alike, and the frame after the last one usually doesn't. Cutting
where the frame-to-frame difference spikes recovers the animations. Checked
against Peedy, whose ranges were identified by hand, this lands within a frame
or two of most of them.

Usage: runs.py <character> [sensitivity]   default 0.6; lower cuts more often
"""
from PIL import Image
import json, os, statistics, sys
from PIL import ImageDraw, ImageFont

name = sys.argv[1]
sensitivity = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
meta = json.load(open(f"tools/out/{name}-meta.json"))
kinds = json.load(open(f"tools/out/{name}-kinds.json"))
frames = [f["i"] for f in meta["frames"] if f["px"] and kinds[str(f["i"])] == "F"]

TH = 40
thumbs = {}
for i in frames:
    im = Image.open(f"assets/{name}/rgba/{i:04d}.png").convert("RGBA")
    flat = Image.new("RGB", im.size, (0, 0, 0))
    flat.paste(im, (0, 0), im)
    thumbs[i] = flat.resize((TH, TH), Image.BILINEAR).getdata()


def distance(a, b):
    pa, pb = thumbs[a], thumbs[b]
    return sum(abs(x[0] - y[0]) + abs(x[1] - y[1]) + abs(x[2] - y[2])
               for x, y in zip(pa, pb)) / (len(pa) * 3)


gaps = [(frames[k], distance(frames[k - 1], frames[k])) for k in range(1, len(frames))]
scores = sorted(g for _, g in gaps)
med = statistics.median(scores)
# Median absolute deviation: robust to the handful of enormous jumps.
mad = statistics.median([abs(g - med) for g in scores]) or 1
cut = (med + 6 * mad) * sensitivity

bounds = {i for i, g in gaps if g > cut}
# A frame that isn't adjacent to the previous one starts a run whatever it looks
# like — those are the patch groups the other tool would have cut at.
bounds |= {frames[k] for k in range(1, len(frames)) if frames[k] != frames[k - 1] + 1}

runs, start = [], frames[0]
for k in range(1, len(frames)):
    if frames[k] in bounds:
        runs.append((start, frames[k - 1])); start = frames[k]
runs.append((start, frames[-1]))

json.dump(runs, open(f"tools/out/{name}-runs.json", "w"))

out_dir = f"sheets/{name}/runs"
os.makedirs(out_dir, exist_ok=True)
for f in os.listdir(out_dir):
    os.remove(os.path.join(out_dir, f))
TW, THMB, PAD, COLS, BATCH = 92, 74, 16, 12, 10
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 12)
except Exception:
    font = ImageFont.load_default()


def sample(a, b, n=COLS):
    idx = list(range(a, b + 1))
    if len(idx) <= n:
        return idx
    return [idx[round(j * (len(idx) - 1) / (n - 1))] for j in range(n)]


for start_i in range(0, len(runs), BATCH):
    group = runs[start_i:start_i + BATCH]
    W = COLS * (TW + 4) + 150
    H = len(group) * (THMB + PAD + 6) + 10
    sheet = Image.new("RGB", (W, H), (38, 38, 54))
    d = ImageDraw.Draw(sheet)
    for r, (a, b) in enumerate(group):
        y = 10 + r * (THMB + PAD + 6)
        d.text((6, y + THMB // 2 - 8), f"{a}-{b}\n({b - a + 1}f)", font=font,
               fill=(255, 220, 120))
        for c, fi in enumerate(sample(a, b)):
            im = Image.open(f"assets/{name}/rgba/{fi:04d}.png").convert("RGBA")
            im.thumbnail((TW, THMB), Image.LANCZOS)
            bg = Image.new("RGB", (TW, THMB), (60, 60, 80))
            bg.paste(im, ((TW - im.width) // 2, (THMB - im.height) // 2), im)
            x = 140 + c * (TW + 4)
            sheet.paste(bg, (x, y))
            d.text((x + 2, y + THMB + 1), str(fi), font=font, fill=(180, 200, 255))
    sheet.save(f"{out_dir}/runs_{start_i:03d}.png")

print(f"{name}: {len(runs)} runs -> {(len(runs) + BATCH - 1) // BATCH} sheets in {out_dir}")
