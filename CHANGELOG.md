# Changelog

## 1.5

- **The Hyperstone Heist turtles.** Raphael, Leonardo, Michelangelo and
  Donatello — thirty-five characters now. They keep the Streets of Rage sound
  set and have their own lines about four-player cabinets and pizza.
- `sheet.py --blobs` segments a sheet by connected pixels instead of bands and
  columns, for sheets whose rows aren't rows. That's what the turtles needed.
- **Sound no longer runs on the main thread.** `AVAudioPlayer.play()` makes a
  blocking XPC call to the audio server, and when that server is unhappy it
  never returns — which froze every character mid-step, with no menu and no
  trace. Found by sampling a silent, motionless app. A hung audio server is now
  somebody else's problem; the characters keep walking, in silence.
- The cast test no longer plays a hundred sounds to prove they exist. It asks
  which clip a kind resolves to, which is the actual logic, and doesn't wedge
  the machine's audio service on the way past.

## 1.4

- **They talk.** Speech bubbles — no voices — with forty-five facts, twenty-six
  jokes, twenty-two passing remarks and twenty-two two-hander exchanges, all
  about video games up to 1997 and nothing after.
- Jokes are told with a beat between setup and punchline, and a flourish on the
  punchline.
- **Chattiness** (Quiet / Occasional / Chatty) is separate from Liveliness:
  pacing about and talking are different appetites.
- Two of them standing near each other fall into conversation. Exchanges
  written for a specific pair only run when that pair is out; the rest of the
  pool is unattributed and alternates speakers, so any two characters have
  something to say.
- The bubble is square-cornered with a hard border and a hard shadow, because a
  soft modern balloon over a 16-bit sprite looks like an app stuck to its head.

## 1.3

- **Twelve more characters, from twelve more games.** Earthworm Jim, Pulseman,
  Sparkster, Donald Duck, ToeJam and Earl, Michael Jackson, Ryu, Robert Garcia,
  Joe Musashi, Gambit and Sketch Turner. Thirty-one in all.
- The fighters share the Streets of Rage sound set — a grunt suits a man
  throwing a punch whichever game he came out of. The cartoon characters stay
  silent rather than borrowing another game's effects.
- Earl is now the slowest thing on the desktop, at 110 pt/s against Sonic's 420,
  which is his entire character.
- The sheet cutter learned to handle status-coloured frames: Rocket Knight's
  sheet marks each frame as sprite area, reused or unused with a coloured
  backing rectangle, and all three had to be keyed out or every sprite came out
  glued to its box.

## 1.2

- **Everybody makes a noise now.** Sound sets from Sonic 1, Sonic 2, Sonic 3 &
  Knuckles (with the handful of sounds unique to 3D Blast folded in) and
  Ristar's voice rip, on top of the Streets of Rage one. Sonic and Mecha Sonic
  take Sonic 2's, Tails, Knuckles and the 3D Blast Sonic take Sonic 3's,
  Robotnik takes Sonic 1's, and Ristar has his own voice.
- None of the rips says what its sounds are — they're numbered by sound-test
  index — so the Sonic sets are grouped by measuring the audio: unpitched
  bursts are impacts, rising sweeps are effort, the bright tonal ones are
  shouts.
- Ristar's set has no impacts, because his rip is ten clips of his voice.
  `SoundBank` falls back to whatever a set does have, and the tests now assert
  that every kind produces a sound rather than that the bank merely exists.
- Sounds ship as 22.05 kHz mono. At the rips' 44.1 kHz stereo they would have
  been sixteen megabytes of a nineteen-megabyte app.

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
