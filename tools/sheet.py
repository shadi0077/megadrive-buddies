"""Cut a spriters-resource style sheet into frames.

A rip is a single sheet with frames laid out in irregular rows, so it needs
segmenting: find bands of content, then columns within each band, then split
each column at its own vertical gaps.

Usage: sheet.py <character> <sheet.png> [keys | alpha | auto] [y0:y1] [--blobs]

`--blobs` segments by connected pixels instead of by bands and columns. Use it
for a sheet whose rows aren't rows: the Hyperstone Heist turtles sit at
whatever height suits them, so a band spans several sprites at different
offsets, the gaps between two of them are covered by a third sitting higher,
and column projection welds the lot into one frame. Blobs don't care about
rows. They are slower and they split a sprite from anything it isn't touching
— a thrown weapon becomes its own frame — so they aren't the default.

`keys` is one or more background colours, "r,g,b" separated by "+". The
Spriters Resource sheets for the Sonic games use two — a page colour and a
per-frame panel colour — and keying only one of them leaves every sprite
welded to its box. "auto" takes the two most common colours in the image,
which is right for those sheets and wrong for a sheet with a big flat
sprite, so look at the index afterwards either way.

Caveat worth knowing before authoring animations: a caption printed directly
beside a sprite ends up inside that frame, because the column containing both
is one run of content. Those frames look normal by size, so they can't be
filtered out automatically — render the numbered index (tools/index.py) and
look. Blaze's walk cycle
starts two frames later than it appears to for exactly this reason.
"""
from PIL import Image
import json, os, shutil, sys

argv = [a for a in sys.argv if a != "--blobs"]
blobs = len(argv) != len(sys.argv)

name = argv[1]
src = argv[2]
key_arg = argv[3] if len(argv) > 3 else "204,255,204"
# Optional "y0:y1" to take a horizontal slice, for sheets carrying more than
# one character.
slice_arg = argv[4] if len(argv) > 4 else None

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

counts = {}
for p in im.getdata():
    counts[p[:3]] = counts.get(p[:3], 0) + 1
ranked = sorted(counts.items(), key=lambda kv: -kv[1])

if use_alpha:
    keys = set()
elif key_arg == "auto":
    # Two colours only when the second really is a background: a page and its
    # frame panels are both enormous, a sprite colour never is.
    keys = {ranked[0][0]}
    if len(ranked) > 1 and ranked[1][1] > W * H * 0.12:
        keys.add(ranked[1][0])
else:
    keys = {tuple(int(v) for v in part.split(",")) for part in key_arg.split("+")}

# Sheets annotate themselves, and an annotation drawn between two cells welds
# them into one frame — two Sonics in one sprite.
#
# These three are the MS Paint colours the rippers mark frames with ("place
# between other frames"), and no Mega Drive sprite uses them: the hardware's
# palette puts every channel on a multiple of 36 and none of these land there.
#
# Tried and rejected: treating *every* off-grid colour as annotation. It reads
# well and it is wrong — several of these sheets were saved through a palette
# that shifted the sprites off the grid too, and the rule quietly keyed out
# Mecha Sonic's jet flames.
for marker in [(34, 177, 76), (168, 230, 29), (153, 217, 234)]:
    if counts.get(marker, 0) > 200:
        keys.add(marker)

# Rules: a line of one colour running nearly the full width or height of the
# sheet is furniture. Ristar's sheet separates its sections with white rules,
# and one rule welds a whole row of sprites into a single 900-pixel frame. The
# colour can't be keyed out — those rules are the same white as his gloves — so
# it is the *pixels* that get ignored.
furniture = set()
for y in range(H):
    row = {}
    for x in range(W):
        c = px[x, y][:3]
        if c not in keys:
            row[c] = row.get(c, 0) + 1
    if row:
        colour, n = max(row.items(), key=lambda kv: kv[1])
        if n > W * 0.7:
            furniture.update((x, y) for x in range(W) if px[x, y][:3] == colour)
for x in range(W):
    col = {}
    for y in range(H):
        c = px[x, y][:3]
        if c not in keys:
            col[c] = col.get(c, 0) + 1
    if col:
        colour, n = max(col.items(), key=lambda kv: kv[1])
        if n > H * 0.7:
            furniture.update((x, y) for y in range(H) if px[x, y][:3] == colour)


def is_background(x, y):
    if (x, y) in furniture:
        return True
    p = px[x, y]
    return p[3] == 0 if not keys else p[:3] in keys

def segment_by_blobs():
    """Frames as connected pixels, with near neighbours joined back up.

    A sprite is one blob, except where the art has detached parts — a raised
    sword, a shadow under the feet, a spark. Those are joined back on by
    merging boxes that overlap or nearly touch, which is also why this can't
    simply be the default: the same rule would join two characters standing
    shoulder to shoulder.
    """
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    labels, prev = {}, []
    for y in range(H):
        runs, start = [], None
        for x in range(W):
            if not is_background(x, y):
                if start is None:
                    start = x
            elif start is not None:
                runs.append((start, x - 1))
                start = None
        if start is not None:
            runs.append((start, W - 1))

        current = []
        for (x0, x1) in runs:
            key = (y, x0)
            parent[key] = key
            for (px0, px1, pkey) in prev:
                if px0 <= x1 + 1 and x0 <= px1 + 1:      # 8-connected
                    union(pkey, key)
            labels[key] = (x0, x1, y)
            current.append((x0, x1, key))
        prev = current

    boxes = {}
    for key, (x0, x1, y) in labels.items():
        root = find(key)
        if root in boxes:
            a, b, c, d = boxes[root]
            boxes[root] = (min(a, x0), min(b, y), max(c, x1), max(d, y))
        else:
            boxes[root] = (x0, y, x1, y)

    # Join a sprite back to its detached parts — a raised sword, a shadow, a
    # spark — without joining it to its neighbours.
    #
    # Proximity alone chains: on a busy sheet every blob is within a few pixels
    # of the next one, and the whole top of the Leonardo sheet came out as a
    # single 636x406 frame. So a near-miss merge also has to be lopsided. Two
    # boxes of comparable size sitting next to each other are two sprites, no
    # matter how close they are; a small box beside a large one is a part of it.
    near = 4

    def part(b):
        """Small enough, or thin enough, to be a piece of something else.

        A blade, a shadow, a spark. Absolute rather than relative to its
        neighbour: judged in proportion, a 40x55 turtle counts as a detail
        beside a 649x335 piece of title art, and Raphael's entire sheet came
        out as one frame."""
        w, h = b[2] - b[0] + 1, b[3] - b[1] + 1
        return w * h < 1500 and min(w, h) <= 18

    def joins(a, b):
        if a[0] <= b[2] and b[0] <= a[2] and a[1] <= b[3] and b[1] <= a[3]:
            return True                       # overlapping is one thing
        close = (a[0] <= b[2] + near and b[0] <= a[2] + near
                 and a[1] <= b[3] + near and b[1] <= a[3] + near)
        return close and (part(a) or part(b))

    merged, changed = sorted(boxes.values()), True
    while changed:
        changed = False
        out = []
        for box in merged:
            for i, other in enumerate(out):
                if joins(box, other):
                    out[i] = (min(box[0], other[0]), min(box[1], other[1]),
                              max(box[2], other[2]), max(box[3], other[3]))
                    changed = True
                    break
            else:
                out.append(box)
        merged = sorted(out)

    merged = [b for b in merged
              if b[2] - b[0] >= 7 and b[3] - b[1] >= 7]
    # Reading order, in rough rows.
    merged.sort(key=lambda b: (b[1] // 24, b[0]))
    return [(0, x0, y0, x1, y1) for (x0, y0, x1, y1) in merged]


if blobs:
    frames = segment_by_blobs()
    bands = [None]
else:
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
            if cp[x, y][:3] in keys or (x0 + x, y0 + y) in furniture:
                cp[x, y] = (0, 0, 0, 0)
    crop.save(f"{out}/frames/{i:04d}.png", optimize=True)
    manifest.append(dict(x=(cw - w) // 2, y=ch - h - 4, w=w, h=h))
    # Where it came from on the sheet, which is how you find "the four frames
    # in the second row" once the frames are numbered.
    index.append(dict(i=i, band=b, w=w, h=h, sx=x0, sy=y0))

json.dump(dict(canvas=dict(w=cw, h=ch), frames=manifest),
          open(f"{out}/frames.json", "w"))
os.makedirs("tools/out", exist_ok=True)
json.dump(dict(bands=len(bands), frames=index), open(f"tools/out/{name}-sheet.json", "w"))

total = sum(os.path.getsize(f"{out}/frames/{f}") for f in os.listdir(f"{out}/frames"))
print(f"{name}: {len(frames)} frames from {len(bands)} bands "
      f"({'alpha' if not keys else 'keys ' + str(sorted(keys))}), "
      f"canvas {cw}x{ch}, {total/1024:.0f} KB")
for b in range(len(bands)):
    n = sum(1 for f in index if f["band"] == b)
    if n:
        print(f"   band {b:2d}: frames {min(f['i'] for f in index if f['band']==b)}"
              f"-{max(f['i'] for f in index if f['band']==b)}  ({n})")
