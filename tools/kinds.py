"""Sort a dump's frames into full bodies and overlay patches.

A Microsoft Agent character isn't a flipbook. Roughly a third of its frames are
small patches meant to be composited over a held pose — groups of seven are
lip-sync visemes, groups of two are eye blinks — and they are interleaved with
the full-body frames rather than kept apart. Everything downstream needs to
know which is which.

Area alone doesn't decide it. A character flying away into the distance is a
full body a few pixels across, and Peedy's dump has eleven such frames in a row
— by size they look exactly like mouth patches. What separates them is drift: a
viseme set is drawn to sit in one place, so its frames barely move or change
size, while anything animating moves. So small frames are grouped into runs and
a run is called patches only if it holds still (this reproduces the hand-made
classification of Peedy's dump on 688 of its 705 frames, erring towards
calling a doubtful run a body).

The area threshold itself is taken from the character's own frames rather than
fixed, because these dumps range from an 80x80 dog to a 168x142 robot.

Usage: kinds.py <character>          writes tools/out/<character>-kinds.json
"""
import json, statistics, sys

name = sys.argv[1]
meta = json.load(open(f"tools/out/{name}-meta.json"))
frames = meta["frames"]
canvas = meta["canvas"]["w"] * meta["canvas"]["h"]

areas = sorted(f["w"] * f["h"] for f in frames if f["px"])
body = statistics.median(areas[len(areas) // 2:])     # median of the larger half
cut = body * 0.28

by_i = {f["i"]: f for f in frames}
kinds = {f["i"]: ("E" if not f["px"] else "F") for f in frames}

# Runs of small frames, then: does this run hold still?
run = []
def settle(run):
    if not run:
        return
    xs = [by_i[i]["x"] for i in run]
    ys = [by_i[i]["y"] for i in run]
    ws = [by_i[i]["w"] for i in run]
    hs = [by_i[i]["h"] for i in run]
    still = (max(xs) - min(xs) <= 8 and max(ys) - min(ys) <= 24
             and max(ws) - min(ws) <= 8 and max(hs) - min(hs) <= 12)
    if still:
        for i in run:
            kinds[i] = "O"

for i in sorted(by_i):
    f = by_i[i]
    if f["px"] and f["w"] * f["h"] < cut:
        run.append(i)
    else:
        settle(run); run = []
settle(run)

counts = {k: sum(1 for v in kinds.values() if v == k) for k in "FOE"}
json.dump({str(k): v for k, v in kinds.items()},
          open(f"tools/out/{name}-kinds.json", "w"))

# Patches come in sets — seven visemes, two blink frames. Runs of other lengths
# are worth a look, since they usually mean the threshold caught a body.
runs, order = [], sorted(kinds)
for i in order:
    k = kinds[i]
    if runs and runs[-1][0] == k and runs[-1][2] == i - 1:
        runs[-1][2] = i
    else:
        runs.append([k, i, i])
patch_runs = [(a, b - a + 1) for k, a, b in runs if k == "O"]
sizes = {}
for _, n in patch_runs:
    sizes[n] = sizes.get(n, 0) + 1
print(f"{name}: {counts['F']} bodies, {counts['O']} patches, {counts['E']} empty "
      f"(cut at {cut:.0f} of {canvas} px canvas)")
print(f"  patch runs by length: {dict(sorted(sizes.items()))}")
