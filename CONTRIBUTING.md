# Contributing

Thanks for looking. This is a small project with a clear shape, so a bit of
orientation goes a long way.

## Getting it running

You need macOS and the Xcode command line tools. The sprites are committed, so
a clone builds and runs directly:

```bash
./build.sh && open "build/MegaDrive Buddies.app"
```

There is no Xcode project. `build.sh` compiles the sources with `swiftc` and
assembles the `.app` itself.

## Before you open a PR

```bash
./test.sh
```

Everything should pass. It takes under a minute.

`BUDDY_DEBUG=1` traces behaviour decisions to stderr, and `BUDDY_TURN=fight`
starts a scrap on launch rather than waiting for two of them to wander together:

```bash
BUDDY_DEBUG=1 BUDDY_TURN=fight "./build/MegaDrive Buddies.app/Contents/MacOS/MegaDrive Buddies"
```

## What tends to go wrong

Three failure modes have bitten repeatedly. If you're changing anything nearby,
these are worth knowing:

**A clip that doesn't exist is silent, not loud.** The rips don't cover the same
ground: the Streets of Rage 2 four have a dozen moves each, an enemy sprite has
three. Naming a clip directly means a character without it performs nothing at
all — Axel spent an afternoon doing `cheer`, which he hasn't got. Shared
routines go through `Brain.move(_:)`, which drops what a character lacks and
falls back to its own flourishes, and `tools/casttest` fails on any clip named
in a `Personality` that the sprite set doesn't have.

**Long sequences hand back through deferred callbacks.** A bit — guard then
punch, knocked down then up — owns its character across intro, loop and outro.
Drop the callback and the character is stranded mid-bit forever. Every such
sequence carries a generation token, and `Brain.tick` has a 60-second backstop
because this has genuinely happened three times. The third was a looping clip
used as a flourish: `Animator.play` only calls back for a clip that finishes,
so Sonic performed his run cycle and stood there running for a minute. Play
clips through `Brain.playOnce`, never `animator.play`, unless you are handling
the loop yourself.

**The sheet is not as regular as it looks.** Captions land inside frames,
colour swatches sit among the sprites, one column can hold two stacked sprites,
and the Streets of Rage 1 rips have no whole-body walk. None of it is
detectable from frame sizes. Render `tools/index.py` and look before authoring
ranges, and read the traps listed in the README.

## Adding a character

1. `./setup.sh <name> <sheet.png>` cuts the sheet and renders a numbered index.
2. Open `tools/out/<name>-index.png` and work out which frames are which.
3. Declare the clip ranges in `tools/catalog.py` and run it.
4. Add a `Personality` in `app/Sources/SoRPersonalities.swift` — the `brawler`
   helper covers most of it: scale, beat range, speed, distance, restlessness,
   the moves they reach for, and their bits.
5. Add the id to the `cast` in `products/megadrive-buddies.json`. A character
   in no product's cast is compiled but never ships.
6. Give them a menu-bar frame in `AppDelegate.statusIcon()` if their sheet has
   portrait art — it reads much better at 18pt than an action frame.

One sheet is cut with nothing authored for it, and it's the interesting one:

`headdy` — Dynamite Headdy. His sheet is sectioned BODY 1 and HEAD 1, and it
contains no complete figure anywhere: every sprite is a part. Compositing does
look right — try body 21 with head 61 — but shipping him needs a per-frame
pairing of head to body and a step that renders the composites into a normal
frame pack. That's authoring rather than cutting, which is why he isn't in.

The Hyperstone Heist turtles used to be on this list. They needed
`sheet.py --blobs`, which segments by connected pixels rather than by bands and
columns — see the README for what that fixes and what it breaks.

## Adding an app

A product is a manifest in `products/`: an id, a name, a bundle identifier and a
cast. Copy one, run `python3 tools/icon.py <id>` and `./build.sh <id>`. No
target, no project file, and nothing in the Swift sources needs to know it
exists.

## Style

Match the surrounding code. Comments explain *why*, especially where something
looks odd — most of the odd-looking code is odd because the obvious version was
measured and found wanting.
