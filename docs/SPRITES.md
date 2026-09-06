# About the sprites

None of the character artwork or sound under `app/Resources/characters/` is
**covered by this project's MIT licence**. The MIT licence in `LICENSE` covers
the Swift source, the Python tooling, and the documentation — nothing else.

All of it is included here so both apps run straight from a clone, but no rights
to any of these characters are granted with it, and none of it is mine to
license.

**If you are a rights holder** and would like this removed, open an issue or
contact the maintainer and it will be taken down promptly.

## Desktop Buddies

Peedy (the parrot) and Bonzi (the gorilla) are Microsoft Agent characters. The
artwork belongs to its respective owners — Microsoft for the Agent character
set, and Bonzi Software for Bonzi.

Clippit, Rover, Merlin, F1, Earl and Manma-chan are the **Microsoft Office XP**
assistants, and Max is from **MaxALERT**. Same position: the artwork belongs to
its owners.

## MegaDrive Buddies

Axel, Blaze, Max, Skate, Adam, Galsia, Donovan, Eagle and Slum, and the sound
effects that go with them, are from **Streets of Rage** (*Bare Knuckle* in
Japan) and belong to Sega, with music and sound by Yuzo Koshiro and Ancient.

Sonic, Tails, Knuckles, Dr. Robotnik and Mecha Sonic are from the **Sonic the
Hedgehog** games and **Ristar** is from *Ristar*, both Sega. **ToeJam and Earl**
are Sega's too, and so is **Michael Jackson's Moonwalker** — the likeness there
is the estate's business, not Sega's.

The rest belong to other publishers: **Earthworm Jim** to Interplay and
Shiny, **Pulseman** to Sega and Game Freak, **Sparkster** to Konami,
**Donald Duck** to Disney and Sega, **Terry Bogard** and **Robert Garcia** to
SNK, **Ryu** to Capcom, **Joe Musashi** to Sega, **Gambit** to Marvel and
Sega, **Sketch Turner** to Sega, and the four **Teenage Mutant Ninja Turtles**
to Konami and Nickelodeon.

The sheets are community rips, of the kind archived on The Spriters Resource,
and the rippers are credited on the sheets themselves.

The sound effects are Sega's too — from Streets of Rage 2, Sonic 1, Sonic 2,
Sonic 3 & Knuckles, Sonic 3D Blast and Ristar. The Sonic and Ristar sets come
from Mr Lange's sound-test rips, which ask for credit rather than require it;
this is that credit.

## What's committed, and what isn't

| | |
|---|---|
| `app/Resources/characters/<name>/frames/` | The packed sprites the apps load — trimmed, alpha PNGs. Committed. |
| `app/Resources/characters/<name>/frames.json` | Frame offsets on a shared canvas, so trimmed frames stay registered with each other and feet stay planted. Committed. |
| `app/Resources/characters/<name>/animations.json` | Clip ranges, frame rates, loop flags, talk poses, viseme ramps. Committed. |
| `app/Resources/characters/_sor2/`, `_sonic1/`, `_sonic2/`, `_sonic3k/`, `_ristar/` | The sound sets, shared across the game cast. Committed. |
| `assets/`, `sheets/` | The raw sprite dumps, the game sheets, and the keyed intermediates. **Not committed** — regenerable from the source artwork. |

Everything either app needs is committed, so a clone builds and runs. You only
need the source artwork to add a character, to redo one from a different rip, or
to change the pipeline.

## Rebuilding a Desktop Buddies character

The source dumps are widely archived as "BonziBUDDY - Characters - Peedy" and
"- Bonzi", each a zip of numbered PNG frames on a cyan (`#00FFFF`) background.

```bash
./setup.sh agent ~/Downloads/peedy.zip ~/Downloads/bonzi.zip
```

That unpacks them, keys out the cyan, trims every frame, measures the visemes,
writes the asset pack, and builds the app.

### From a single gridded sheet

Several of these characters arrive as one image with every frame in a grid
rather than as numbered files:

```bash
python3 tools/grid.py <name> <sheet.png>
```

The cell *is* the character's canvas — each frame sits at its true position
inside it, which is what keeps a mouth patch registered to the body it belongs
to — so every cell is written out whole, background and all, and the rest of the
pipeline treats the result exactly like a numbered dump. The grid is measured
rather than assumed; see the tool's own notes for how, and for what happens when
a sheet's cell size doesn't divide its width.

### Adding your own

1. Get a sprite dump on a flat colour-key background.
2. `python3 tools/extract.py <name>` — keys it out, measures every frame.
3. `python3 tools/strips.py <name>` — renders labelled contact strips into
   `sheets/`. Runs of full-body frames are almost always one animation each;
   the small patches between them are mouth visemes and eye blinks.
4. Declare the clip ranges and talk poses in `tools/catalog.py`.
5. `python3 tools/pack.py <name>` — writes the asset pack.
6. Add a `Personality` in `app/Sources/` — voice, pacing, clips, and what they say.
7. Add exchanges to `Banter.swift` if they should talk to the others.
8. Add the id to the `cast` of a manifest in `products/`, or they won't ship
   with either app.

`tools/casttest` will tell you if you've named a clip that doesn't exist.

## Cutting a MegaDrive Buddies sheet

```bash
./setup.sh sheet <name> <sheet.png> [key_r,key_g,key_b | alpha] [y0:y1]
```

`tools/sheet.py` finds horizontal bands of content, then columns within each
band, then splits each column at its own vertical gaps, and trims every frame to
its bounding box. Some rips key the background by colour (`204,255,204` is
common) and others leave it genuinely transparent; it detects which from the
file rather than trusting the argument. The optional `y0:y1` takes a horizontal
slice, for sheets carrying more than one character. Sheets whose sprites don't
sit in rows at all need `--blobs`, which segments by connected pixels instead.

Then render the numbered index and *look at it* before authoring anything:

```bash
python3 tools/index.py <name>
```

This is not optional diligence. Captions printed beside a sprite end up inside
its frame at a perfectly normal size, colour swatches sit in the middle of the
sheet, MS Paint marker bars weld two cells into one, and the Streets of Rage 1
rips have no whole-body walk at all — their walk frames are disembodied legs,
because the game composited a walk from separate torso and leg sprites. None of
that is detectable automatically. The [MegaDrive Buddies
documentation](megadrive-buddies.md#cutting-the-sheets) lists the traps found so
far.

### Adding your own

1. `./setup.sh sheet <name> <sheet.png>` — cuts the sheet and renders the index.
2. Open `tools/out/<name>-index.png` and note which frames belong to which
   animation.
3. Declare the clip ranges in `tools/catalog.py`, then run it.
4. Add a `Personality` to one of `SoRPersonalities.swift`,
   `SonicPersonalities.swift` or `ArcadePersonalities.swift` — scale, pace,
   reach, and which moves they reach for.
5. Give them lines in `GameTalk.swift`; a character with none of its own is a
   stranger reciting trivia, and the test suite says so.
6. Add the id to the `cast` in `products/megadrive-buddies.json`, or they won't
   ship.

`./test.sh` will tell you if you've named a clip that doesn't exist, or if any
frame ended up holding two sprites.
