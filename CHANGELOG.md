# Changelog

## 1.1

- **Eight more characters, from four more games.** Sonic, Tails, Knuckles,
  Dr. Robotnik and Mecha Sonic from the Sonic games, a second Sonic from
  3D Blast (pre-rendered rather than drawn, and unmistakably so next to the
  other one), Ristar, and Terry Bogard out of Fatal Fury 2. Nineteen in all.
- Sizes are per character and deliberately uneven: a Mega Drive Sonic is 38
  pixels tall and Terry Bogard is 92, so levelling them would make a hedgehog
  the size of a man.
- Sonic travels at 420 pt/s on his run cycle — the fastest thing here, and the
  reason travel animation is chosen per character rather than fixed.
- **Silence is now a supported state.** Only the Streets of Rage rip came with
  sound, so `soundSet` is optional: the Sonic cast and Ristar make no noise at
  all, and the tests assert that rather than treating it as a missing bank.
- The sheet cutter learned to survive annotated sheets — marker bars between
  cells, full-width rules, and per-frame panels — because every one of those
  welds neighbouring sprites into a single frame.

## 1.0

First release.

- **Eleven Streets of Rage characters.** Axel, Blaze, Max and Skate from the
  second game; Adam, Axel and Blaze from the first; and Galsia, Donovan, Eagle
  and Slum. Have one, or all of them.
- **They walk.** At their own pace, over their own distances, the length of the
  screen — a heavy Max and a Skate on rollerblades stay recognisably different.
- **They square up.** Two within 420 points of each other stop wandering and
  trade blows, taking turns and facing each other, with whoever isn't swinging
  turning to watch.
- **The game's own sound effects**, chosen by move: specials shout, knockdowns
  thud, everything else grunts. Their own volume, independent of the system's.
- **Alive rather than looping.** Energy that rises with attention and decays
  without it, cursor awareness, poke habituation, and awareness of whether
  you're at the keyboard at all.
- macOS 11 and later on Apple Silicon.

Split out of [desktop-buddies](https://github.com/shadi0077/desktop-buddies),
which keeps the characters who talk. The engine started there; the speech half
of it is gone from this repo, because nobody here has anything to say.

### Fixed on the way out

- Galsia's frames each held two sprites — a column of his sheet packs two
  stacked poses, and the cutter took the pair as one frame, so he rendered as a
  man with a second man growing out of his head. The cutter splits columns at
  their own gaps now, and a test checks every shipped frame holds one sprite.
