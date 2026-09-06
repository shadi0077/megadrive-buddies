"""Cut a sheet whose frames are packed too tightly for `sheet.py`.

`sheet.py` splits a sheet into horizontal bands and then columns. That is the
right shape for a rip laid out in generous rows — Streets of Rage — and it is
still the tool to reach for first, because bands map almost one-to-one onto
animations and the frame order comes out in a sensible reading order for free.

It fails on two layouts that are common in SNES rips:

  Packed.  Sprites sit close enough that no fully-background row separates the
           rows, or no fully-background column separates neighbours. One band
           swallows the sheet. Chrono Trigger's Crono cuts to 19 frames on a
           483x659 canvas — the whole sheet, essentially, in three pieces.

  Boxed.   Every frame is drawn inside a panel, or captions sit on coloured
           bars, and that chrome is continuous across the sheet. Mega Man X
           cuts to exactly one frame, because the panel borders join every
           sprite on the sheet into a single run of content.

This cutter works from connected components instead:

  1. Build a foreground mask by keying out the background *and any chrome* —
     `--keys auto` takes the dominant colour, plus any other colour covering
     more than `--chrome` of the sheet, which is what catches the panel fills
     and caption bars on a boxed sheet.

     The threshold is deliberately high. An early version treated anything over
     2% as chrome and punched holes in Crono, whose red palette covers more of
     his own small sheet than a panel fill covers a large one. Frequency alone
     does not distinguish chrome from a character's favourite colour; being
     *most* of the sheet does. Anything subtler than that is better passed
     explicitly, after looking.
  2. Dilate the mask by `--gap`, so a sprite's detached parts — a thrown
     barrel, the gap between a hat and a head — join up, while genuinely
     separate sprites stay apart.
  3. Label connected components on the dilated mask, and take each component's
     bounding box back on the *undilated* pixels so nothing is fattened.
  4. Drop components smaller than `--min` — ruler marks, stray pixels, and the
     debris colour-keying leaves behind — and larger than `--max`, which is the
     signature of chrome that survived step 1 and welded a whole region
     together.

     A *minimum* size filter is the one MEGADRIVE.md warns against, and that
     warning stands: it throws away legitimate short poses. A *maximum* is a
     different claim. No sprite in a 16-bit rip is 1400 pixels wide, so a
     component that size is not a frame that came out badly, it is several
     frames joined by something that should have been keyed. Dropped
     components are reported with their sizes rather than discarded quietly,
     because their number is the signal that the keys are wrong.
  5. Sort into reading order, and report groups of frames that share a row so
     the output is comparable with `sheet.py`'s bands.

Everything is Pillow and the standard library, like the rest of the pipeline —
`MaxFilter` does the dilation at C speed, and the labelling runs over
run-length rows rather than pixels, which keeps a 28-megapixel sheet in the
seconds rather than the minutes.

Usage:
    blobs.py <character> <sheet.png> [--keys auto|r,g,b;r,g,b|alpha]
                                     [--gap 5] [--min 8] [--max 400]
                                     [--chrome 0.10] [--slice y0:y1]

The same caveat as `sheet.py` applies and is worth repeating: a caption printed
close to a sprite lands inside that frame, and no filter catches it. Render the
numbered index with `tools/index.py` and look.
"""
from PIL import Image, ImageChops, ImageFilter
from collections import Counter
import json, os, shutil, sys

Image.MAX_IMAGE_PIXELS = None


def parse_args(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    opts = {"keys": "auto", "gap": 5, "min": 8, "max": 400,
            "chrome": 0.10, "slice": None}
    rest = argv[3:]
    i = 0
    while i < len(rest):
        k = rest[i].lstrip("-")
        if k not in opts:
            sys.exit(f"unknown option: {rest[i]}")
        opts[k] = rest[i + 1]
        i += 2
    for k in ("gap", "min", "max"):
        opts[k] = int(opts[k])
    opts["chrome"] = float(opts["chrome"])
    return argv[1], argv[2], opts


def load(path, slice_arg):
    im = Image.open(path).convert("RGBA")
    if slice_arg:
        y0, y1 = (int(v) for v in slice_arg.split(":"))
        im = im.crop((0, y0, im.width, y1))
    return im


def background_colours(im, spec, chrome):
    """Which colours count as background.

    `alpha` trusts the alpha channel. An explicit list is taken as given.
    `auto` takes every colour covering more than `chrome` of a sampled grid —
    one entry for a plain sheet, several for a sheet with panels and caption
    bars, which is exactly the case this cutter exists for.
    """
    if spec == "alpha":
        return None
    if spec != "auto":
        return [tuple(int(v) for v in group.split(",")) for group in spec.split(";")]

    w, h = im.size
    px = im.load()
    step_x, step_y = max(1, w // 200), max(1, h // 200)
    counts = Counter(px[x, y][:3]
                     for x in range(0, w, step_x)
                     for y in range(0, h, step_y))
    total = sum(counts.values())
    # Transparent sheets have no dominant colour worth keying.
    opaque = sum(1 for x in range(0, w, step_x) for y in range(0, h, step_y)
                 if px[x, y][3] != 0)
    if opaque < total * 0.5:
        return None
    ranked = counts.most_common(8)
    # The dominant colour is the background whatever its share; the rest have
    # to earn it by covering most of the sheet.
    return [ranked[0][0]] + [c for c, n in ranked[1:] if n / total > chrome]


def foreground_mask(im, keys):
    """An 8-bit mask, 255 where a sprite is."""
    if keys is None:
        return im.getchannel("A").point(lambda v: 255 if v > 8 else 0)

    rgb = im.convert("RGB")
    # Start all-foreground, then knock out each background colour. Comparing
    # per channel and keeping the largest difference avoids the trap of
    # averaging, where a colour differing in one channel only reads as equal.
    mask = Image.new("L", im.size, 255)
    for key in keys:
        solid = Image.new("RGB", im.size, key)
        diff = ImageChops.difference(rgb, solid)
        r, g, b = diff.split()
        near = ImageChops.lighter(ImageChops.lighter(r, g), b)
        mask = ImageChops.darker(mask, near.point(lambda v: 255 if v > 12 else 0))

    if im.mode == "RGBA":
        mask = ImageChops.darker(mask, im.getchannel("A").point(
            lambda v: 255 if v > 8 else 0))
    return mask


def rows_to_runs(data, w, h):
    """Foreground runs per row, found with `bytes.split` at C speed."""
    runs = []
    for y in range(h):
        row = data[y * w:(y + 1) * w]
        out, x = [], 0
        for seg in row.split(b"\x00"):
            if seg:
                out.append((x, x + len(seg) - 1))
            x += len(seg) + 1
        runs.append(out)
    return runs


def label(runs):
    """Union-find over runs; returns a label per run.

    Runs, not pixels: a sheet has millions of the latter and thousands of the
    former, and only the former have to be touched in Python.
    """
    parent = []

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    ids, prev = [], []
    for row in runs:
        cur = []
        for (x0, x1) in row:
            parent.append(len(parent))
            me = len(parent) - 1
            cur.append(me)
            # 8-connectivity: touching at a corner still counts as joined.
            for (px0, px1, pid) in prev:
                if px0 <= x1 + 1 and x0 <= px1 + 1:
                    union(me, pid)
        ids.append(cur)
        prev = [(row[i][0], row[i][1], cur[i]) for i in range(len(row))]

    return [[find(i) for i in row] for row in ids]


def components(runs, labels):
    """Bounding box per label."""
    boxes = {}
    for y, row in enumerate(runs):
        for i, (x0, x1) in enumerate(row):
            key = labels[y][i]
            b = boxes.get(key)
            if b is None:
                boxes[key] = [x0, y, x1, y]
            else:
                if x0 < b[0]: b[0] = x0
                if x1 > b[2]: b[2] = x1
                b[3] = y
    return boxes


def main():
    name, src, opts = parse_args(sys.argv)
    im = load(src, opts["slice"])
    W, H = im.size

    keys = background_colours(im, opts["keys"], opts["chrome"])
    mask = foreground_mask(im, keys)

    # Dilate so a sprite's detached parts join, then label. The boxes come back
    # from the dilated mask, so they are fat by up to `gap`; they get trimmed
    # against the real mask below.
    grow = opts["gap"] | 1
    dilated = mask.filter(ImageFilter.MaxFilter(grow)) if grow > 1 else mask

    runs = rows_to_runs(dilated.tobytes(), W, H)
    boxes = components(runs, label(runs))

    # Trim each fattened box back to the true extent of the sprite inside it.
    tight = []
    for (x0, y0, x1, y1) in boxes.values():
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(W - 1, x1), min(H - 1, y1)
        bbox = mask.crop((x0, y0, x1 + 1, y1 + 1)).getbbox()
        if bbox is None:
            continue
        bx0, by0, bx1, by1 = bbox
        tight.append((x0 + bx0, y0 + by0, x0 + bx1 - 1, y0 + by1 - 1))

    frames, oversized = [], []
    for f in tight:
        w, h = f[2] - f[0] + 1, f[3] - f[1] + 1
        if w < opts["min"] or h < opts["min"]:
            continue
        if w > opts["max"] or h > opts["max"]:
            oversized.append((w, h))
            continue
        frames.append(f)
    if not frames:
        sys.exit(f"{name}: nothing survived the filters")

    # Reading order. Group into rows first: a frame belongs to the current row
    # while it overlaps that row's vertical span, which keeps a short sprite
    # beside a tall one in the same row rather than sorting it away.
    frames.sort(key=lambda f: (f[1], f[0]))
    rows, cur, top, bottom = [], [], None, None
    for f in frames:
        if cur and f[1] > bottom:
            rows.append(cur)
            cur, top, bottom = [], None, None
        if not cur:
            top, bottom = f[1], f[3]
        else:
            bottom = max(bottom, f[3])
        cur.append(f)
    if cur:
        rows.append(cur)
    ordered = [f for row in rows for f in sorted(row, key=lambda f: f[0])]
    band_of = {f: b for b, row in enumerate(rows) for f in row}

    cw = max(f[2] - f[0] + 1 for f in ordered) + 8
    ch = max(f[3] - f[1] + 1 for f in ordered) + 8

    out = f"app/Resources/characters/{name}"
    if os.path.isdir(f"{out}/frames"):
        shutil.rmtree(f"{out}/frames")
    os.makedirs(f"{out}/frames", exist_ok=True)

    manifest, index = [], []
    for i, f in enumerate(ordered):
        x0, y0, x1, y1 = f
        w, h = x1 - x0 + 1, y1 - y0 + 1
        crop = im.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGBA")
        # Key out through the mask, so a sprite keeps any pixel that happens to
        # match the background colour inside its own outline.
        sub = mask.crop((x0, y0, x1 + 1, y1 + 1))
        crop.putalpha(ImageChops.darker(crop.getchannel("A"), sub))
        crop.save(f"{out}/frames/{i:04d}.png", optimize=True)
        manifest.append(dict(x=(cw - w) // 2, y=ch - h - 4, w=w, h=h))
        index.append(dict(i=i, band=band_of[f], w=w, h=h))

    json.dump(dict(canvas=dict(w=cw, h=ch), frames=manifest),
              open(f"{out}/frames.json", "w"))
    os.makedirs("tools/out", exist_ok=True)
    json.dump(dict(bands=len(rows), frames=index),
              open(f"tools/out/{name}-sheet.json", "w"))

    total = sum(os.path.getsize(f"{out}/frames/{f}")
                for f in os.listdir(f"{out}/frames"))
    keytxt = "alpha" if keys is None else " ".join(
        "#%02x%02x%02x" % k for k in keys)
    print(f"{name}: {len(ordered)} frames in {len(rows)} rows "
          f"(gap {grow}, keys {keytxt}), canvas {cw}x{ch}, {total/1024:.0f} KB")
    if oversized:
        big = ", ".join(f"{w}x{h}" for w, h in sorted(oversized, reverse=True)[:4])
        print(f"   dropped {len(oversized)} over {opts['max']}px: {big}"
              f"{' ...' if len(oversized) > 4 else ''}")
        print("   (several frames welded together — try more --keys, "
              "or a smaller --gap)")


if __name__ == "__main__":
    main()
