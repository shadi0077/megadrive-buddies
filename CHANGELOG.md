# Changelog

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
which is now just the parrot and the gorilla. The engine started there; the
speech half of it is gone, because nobody here has anything to say.

### Fixed on the way out

- Galsia's frames each held two sprites — a column of his sheet packs two
  stacked poses, and the cutter took the pair as one frame, so he rendered as a
  man with a second man growing out of his head. The cutter splits columns at
  their own gaps now, and a test checks every shipped frame holds one sprite.
