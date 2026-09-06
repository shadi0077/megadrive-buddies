"""Cut a Microsoft Agent sheet laid out as a uniform grid into numbered frames.

Some of these characters arrive as one image with every frame in a grid rather
than as a folder of numbered files. The cell *is* the character's canvas: each
frame sits at its true position inside its cell, which is what keeps a mouth
patch registered to the one body frame it was drawn for. So each cell is
written out whole — background and all — and the rest of the pipeline treats
the result exactly like a numbered dump.

Usage: grid.py <name> <sheet.png> [<cellw>x<cellh>]

The grid is measured rather than assumed. Some sheets draw their gridlines,
which is unambiguous; the rest are found from the fully-background rows and
columns between frames. Where that leaves more than one candidate — 3813 pixels
is both 41 rows of 93 and 31 rows of 123 — the tie is broken by counting frames
whose content runs into the cell border, since a wrong grid slices bodies in
half and a right one almost never touches an edge.
"""
from PIL import Image
from collections import Counter
import os, shutil, sys

name, src = sys.argv[1], sys.argv[2]
forced = sys.argv[3] if len(sys.argv) > 3 else None

im = Image.open(src).convert("RGB")
W, H = im.size
px = im.load()
bg = Counter(px[x, y] for x in range(0, W, 7)
             for y in range(0, H, 7)).most_common(1)[0][0]


def drawn_lines(axis):
    """Positions of gridlines actually painted on the sheet, if there are any."""
    n, other = (W, H) if axis == 0 else (H, W)
    hits = []
    for i in range(n):
        c = px[i, 0] if axis == 0 else px[0, i]
        if c == bg:
            continue
        same = (all(px[i, j] == c for j in range(0, other, 5)) if axis == 0
                else all(px[j, i] == c for j in range(0, other, 5)))
        if same:
            hits.append(i)
    if len(hits) < 4:
        return None
    gaps = Counter(b - a for a, b in zip(hits, hits[1:]))
    pitch, count = gaps.most_common(1)[0]
    # Every gap the same size, or it isn't a grid. The line itself belongs to
    # neither neighbour, so the usable cell is one pixel smaller than the pitch.
    return (hits[0] + 1, pitch - 1, pitch) if count >= len(hits) - 2 else None


def blank_lines(axis):
    """Rows or columns that are entirely background — the gaps between cells."""
    if axis == 0:
        return [x for x in range(W) if all(px[x, y] == bg for y in range(H))]
    return [y for y in range(H) if all(px[x, y] == bg for x in range(W))]


def candidates(axis):
    """Plausible (origin, cell size) pairs for one axis, best guess first."""
    span = W if axis == 0 else H
    drawn = drawn_lines(axis)
    if drawn:
        return [drawn]
    blanks = blank_lines(axis)
    out = []
    if blanks:
        # Cell boundaries are the first blank column of each run.
        starts = [b for i, b in enumerate(blanks) if i == 0 or b != blanks[i - 1] + 1]
        gaps = Counter(b - a for a, b in zip(starts, starts[1:]))
        out += [(0, p, p) for p, n in gaps.most_common(4) if n > 1 and p > 20]
    # Anything that divides the sheet evenly is worth scoring too: sprites can
    # touch the cell edge often enough to hide the gap on one axis.
    out += [(0, p, p) for p in range(40, 260) if span % p == 0]
    seen, uniq = set(), []
    for pair in out:
        if pair not in seen:
            seen.add(pair); uniq.append(pair)
    return uniq


def edge_contact(ox, cw, sx, oy, ch, sy):
    """How often content runs into the cell border, per non-empty cell."""
    cols, rows = max(1, (W - ox) // sx), max(1, (H - oy) // sy)
    touched = live = 0
    for r in range(rows):
        for c in range(cols):
            x0, y0 = ox + c * sx, oy + r * sy
            x1, y1 = min(x0 + cw, W) - 1, min(y0 + ch, H) - 1
            if x1 <= x0 or y1 <= y0:
                continue
            ring = ([(x, y0) for x in range(x0, x1 + 1, 2)]
                    + [(x, y1) for x in range(x0, x1 + 1, 2)]
                    + [(x0, y) for y in range(y0, y1 + 1, 2)]
                    + [(x1, y) for y in range(y0, y1 + 1, 2)])
            inside = any(px[x, y] != bg
                         for y in range(y0 + 2, y1 - 1, 3)
                         for x in range(x0 + 2, x1 - 1, 3))
            if not inside:
                continue
            live += 1
            if any(px[x, y] != bg for x, y in ring):
                touched += 1
    return (touched / live if live else 1.0), live


if forced:
    cw, ch = (int(v) for v in forced.lower().split("x"))
    ox = oy = 0
    sx, sy = cw, ch
    print(f"cell {cw}x{ch} (given)")
else:
    best = None
    for ox, cw, sx in candidates(0)[:6]:
        for oy, ch, sy in candidates(1)[:6]:
            if not (0.5 < cw / ch < 2.5):
                continue
            score, live = edge_contact(ox, cw, sx, oy, ch, sy)
            if live < 20:
                continue
            if best is None or score < best[0]:
                best = (score, ox, cw, sx, oy, ch, sy)
    if best is None:
        raise SystemExit("could not find a grid — pass one as <cellw>x<cellh>")
    # Nudge: a sheet whose last column is clipped has a cell size that doesn't
    # divide its width, so the exact answer can be a pixel or two off whatever
    # the gaps suggested. Merlin is 128 wide in a 3590-pixel sheet.
    _, ox, cw, sx, oy, ch, sy = best
    for dw in (-3, -2, -1, 0, 1, 2, 3):
        for dh in (-3, -2, -1, 0, 1, 2, 3):
            w, h = cw + dw, ch + dh
            if w < 20 or h < 20:
                continue
            score, live = edge_contact(ox, w, w, oy, h, h)
            if live >= 20 and score < best[0]:
                best = (score, ox, w, w, oy, h, h)
    _, ox, cw, sx, oy, ch, sy = best
    print(f"cell {cw}x{ch} at ({ox},{oy})  "
          f"({best[0] * 100:.1f}% of frames touch a cell edge)")

cols, rows = max(1, (W - ox) // sx), max(1, (H - oy) // sy)
out = f"assets/{name}/frames"
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)

# A sheet whose last column or row is clipped still has every frame at the
# right offset; pad it back to the full canvas so every frame shares one.
kept = 0
for r in range(rows):
    for c in range(cols):
        cell = Image.new("RGB", (cw, ch), bg)
        x0, y0 = ox + c * sx, oy + r * sy
        part = im.crop((x0, y0, min(x0 + cw, W), min(y0 + ch, H)))
        cell.paste(part, (0, 0))
        if not part.getbbox() or all(p == bg for p in part.getdata()):
            continue          # trailing blanks aren't frames
        cell.save(f"{out}/{kept:04d}.png")
        kept += 1

print(f"{name}: {kept} frames from a {cols}x{rows} grid, canvas {cw}x{ch}")
