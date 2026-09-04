# About the sprites

The character artwork and sound under `app/Resources/characters/` is **not
covered by this project's MIT licence**.

Axel, Blaze, Max, Skate, Adam, Galsia, Donovan, Eagle and Slum, and the sound
effects that go with them, are from **Streets of Rage** (*Bare Knuckle* in
Japan) and belong to Sega, with music and sound by Yuzo Koshiro and Ancient.

Sonic, Tails, Knuckles, Dr. Robotnik and Mecha Sonic are from the **Sonic the
Hedgehog** games and **Ristar** is from *Ristar*, both Sega. **Terry Bogard** is
from *Fatal Fury 2* and belongs to SNK; the Mega Drive conversion was published
by Takara.

The sheets are community rips, of the kind archived on The Spriters Resource,
and the rippers are credited on the sheets themselves.

The sound effects are Sega's too — from Streets of Rage 2, Sonic 1, Sonic 2,
Sonic 3 & Knuckles, Sonic 3D Blast and Ristar. The Sonic and Ristar sets come
from Mr Lange's sound-test rips, which ask for credit rather than require it;
this is that credit.

They are included here so the app runs straight from a clone, but no rights to
any of it are granted with it, and none of it is mine to license.

The MIT licence in `LICENSE` covers the Swift source, the Python tooling, and
the documentation.

**If you are a rights holder** and would like this removed, open an issue or
contact the maintainer and it will be taken down promptly.

## What's committed

| | |
|---|---|
| `app/Resources/characters/<name>/frames/` | The cut sprites the app loads — trimmed, alpha PNGs |
| `app/Resources/characters/<name>/frames.json` | Frame offsets on a shared canvas, so their feet stay planted |
| `app/Resources/characters/<name>/animations.json` | Clip ranges, frame rates, loop flags |
| `app/Resources/characters/_sor2/` | The sound effects, shared by the whole cast |
| `assets/`, `sheets/` | The source sheets and working images. **Not committed** — regenerable |

Everything the app needs is committed, so a clone builds and runs. You only need
the source sheets to add a character or redo one from a different rip.

## Cutting a sheet

```bash
./setup.sh <name> <sheet.png> [key_r,key_g,key_b | alpha] [y0:y1]
```

`tools/sheet.py` finds horizontal bands of content, then columns within each
band, then splits each column at its own vertical gaps, and trims every frame to
its bounding box. Some rips key the background by colour (`204,255,204` is
common) and others leave it genuinely transparent; it detects which from the
file rather than trusting the argument. The optional `y0:y1` takes a horizontal
slice, for sheets carrying more than one character.

Then render the numbered index and *look at it* before authoring anything:

```bash
python3 tools/index.py <name>
```

This is not optional diligence. Captions printed beside a sprite end up inside
its frame at a perfectly normal size, colour swatches sit in the middle of the
sheet, and the Streets of Rage 1 rips have no whole-body walk at all — their
walk frames are disembodied legs, because the game composited a walk from
separate torso and leg sprites. None of that is detectable automatically. The
README's "Cutting the sheets" section lists the traps found so far.

## Adding your own character

1. `./setup.sh <name> <sheet.png>` — cuts the sheet and renders the index.
2. Open `tools/out/<name>-index.png` and note which frames belong to which
   animation.
3. Declare the clip ranges in `tools/catalog.py`, then run it.
4. Add a `Personality` to `app/Sources/SoRPersonalities.swift` — scale, pace,
   reach, and which moves they reach for.
5. Add the id to the `cast` in `products/megadrive-buddies.json`, or they won't
   ship.

`./test.sh` will tell you if you've named a clip that doesn't exist, or if any
frame ended up holding two sprites.
