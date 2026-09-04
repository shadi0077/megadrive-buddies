"""Author the animation catalogue for every character.

Usage: catalog.py

Clip ranges are hand-authored, because they have to be: a band of a sprite
sheet maps *almost* one-to-one onto an animation, and the exceptions — a
caption baked into a frame, a colour swatch, a pose that belongs to the
previous move — are only findable by rendering the numbered index and looking.
`tools/index.py` renders that index.
"""
import json, os


def rng(a, b):
    return list(range(a, b + 1))


def build(name, clips):
    data = {"animations": {n: {"steps": [{"f": f} for f in steps],
                               "fps": fps, "loop": loop}
                           for n, (steps, fps, loop) in clips.items()}}
    out = f"app/Resources/characters/{name}"
    os.makedirs(out, exist_ok=True)
    json.dump(data, open(f"{out}/animations.json", "w"), indent=1)
    print(f"{name}: {len(clips)} animations")


# --------------------------------------------------------------------------
# Axel - Streets of Rage 2. A beat-'em-up sprite rip: no mouth, no visemes,
# and nothing to say. He punches, and the game's own sound effects do the
# talking.
# --------------------------------------------------------------------------
AXEL = {
    "rest":        (rng(0, 8), 8, True),          # standing guard
    "walk":        (rng(92, 101), 12, True),
    "stretch":     (rng(9, 12), 8, False),
    "jumpKick":    (rng(13, 16), 10, False),
    "punch":       (rng(102, 108), 14, False),
    "jab":         (rng(17, 21), 14, False),
    "kick":        (rng(109, 114), 12, False),
    "highKick":    (rng(22, 27), 12, False),
    "knee":        (rng(144, 149), 12, False),
    "grandUpper":  (rng(51, 55), 12, False),      # the flaming uppercut
    "flameArc":    (rng(76, 81), 12, False),
    "uppercut":    (rng(129, 137), 12, False),
    "celebrate":   (rng(120, 122), 6, False),
    "guard":       (rng(115, 119), 10, False),
    "knockdown":   (rng(88, 90), 8, False),
    "getUp":       (rng(153, 156), 8, False),
    "arrive":      (rng(115, 122), 10, False),
    "depart":      (rng(92, 101), 12, False),
}

# The rest of the Streets of Rage 2 roster. Same sheet format, same bands-are-
# animations structure, so these were read off the frame index the same way.
BLAZE = {
    "rest":       (rng(0, 8), 8, True),
    "walk":       (rng(105, 111), 12, True),
    "punch":      (rng(114, 119), 14, False),
    "kick":       (rng(24, 28), 12, False),
    "highKick":   (rng(128, 131), 12, False),
    "flip":       (rng(34, 40), 14, False),
    "projectile": (rng(50, 57), 12, False),
    "spin":       (rng(59, 63), 12, False),
    "knockdown":  (rng(99, 101), 8, False),
    "arrive":     (rng(34, 40), 14, False),
    "depart":     (rng(105, 111), 12, False),
}

MAX = {
    "rest":       (rng(0, 9), 7, True),
    "walk":       (rng(80, 90), 10, True),
    "punch":      (rng(96, 102), 12, False),
    "flex":       (rng(10, 17), 8, False),
    "grapple":    (rng(39, 47), 12, False),
    "slam":       (rng(48, 55), 12, False),
    "knockdown":  (rng(35, 38), 8, False),
    "arrive":     (rng(10, 17), 8, False),
    "depart":     (rng(80, 90), 10, False),
}

SKATE = {
    "rest":       (rng(0, 11), 9, True),
    "walk":       (rng(96, 103), 13, True),
    "punch":      (rng(104, 110), 14, False),
    "kick":       (rng(16, 18), 12, False),
    "flip":       (rng(35, 43), 14, False),
    "spin":       (rng(57, 66), 14, False),
    "dash":       (rng(67, 73), 14, False),
    "knockdown":  (rng(84, 86), 8, False),
    "arrive":     (rng(44, 47), 10, False),
    "depart":     (rng(96, 103), 13, False),
}

# The Streets of Rage 1 trio, sliced out of one shared sheet, and the enemies.
# The enemy rips are small — a handful of poses each — and several carry a
# palette swatch and a "RIPPED BY ..." caption that read as frames. Those are
# simply not referenced.
# The Streets of Rage 1 rips composite a walk from separate torso and leg
# sprites, so frames 3-10 of each are disembodied legs and there is no whole-body
# walk cycle to use. Those three glide on their idle instead, and roam less to
# make up for it — better than animating a pair of trousers across the desktop.
ADAM = {
    "rest":      (rng(0, 2), 6, True),
    "walk":      (rng(0, 2), 6, True),
    "punch":     (rng(11, 14), 12, False),
    "kick":      (rng(16, 19), 12, False),
    "flip":      (rng(28, 31), 12, False),
    "knockdown": (rng(51, 53), 8, False),
    "arrive":    (rng(11, 14), 10, False),
    "depart":    (rng(0, 2), 6, False),
}

AXEL1 = {
    "rest":      (rng(0, 2), 6, True),
    "walk":      (rng(0, 2), 6, True),
    "punch":     (rng(11, 14), 12, False),
    "kick":      (rng(16, 19), 12, False),
    "flip":      (rng(28, 31), 12, False),
    "knockdown": (rng(50, 51), 8, False),
    "arrive":    (rng(11, 14), 10, False),
    "depart":    (rng(0, 2), 6, False),
}

BLAZE1 = {
    "rest":      (rng(0, 2), 6, True),
    "walk":      (rng(0, 2), 6, True),
    "punch":     (rng(11, 14), 12, False),
    "kick":      (rng(15, 19), 12, False),
    "flip":      (rng(24, 29), 12, False),
    "knockdown": (rng(51, 53), 8, False),
    "arrive":    (rng(11, 14), 10, False),
    "depart":    (rng(0, 2), 6, False),
}

# Galsia's sheet packs two rows of sprites into one band, so the first cut gave
# him frames holding two bodies each — on the desktop he was a man with a
# second man growing out of his head. The frames are split at the gaps now;
# these ranges are against the split numbering.
GALSIA = {
    "rest":      ([0, 2], 3, True),
    "walk":      (rng(11, 13), 10, True),
    "punch":     ([0, 14, 14], 9, False),
    "knockdown": ([6, 3, 7], 8, False),
    "getUp":     ([8, 9, 4], 7, False),
    "arrive":    (rng(11, 13), 10, False),
    "depart":    (rng(11, 13), 10, False),
}

DONOVAN = {
    "rest":      (rng(0, 4), 6, True),
    "walk":      (rng(13, 16), 9, True),
    "punch":     (rng(10, 11), 9, False),
    "flex":      (rng(12, 13), 6, False),
    "knockdown": (rng(6, 8), 6, False),
    "arrive":    (rng(12, 13), 6, False),
    "depart":    (rng(13, 16), 9, False),
}

EAGLE = {
    "rest":      (rng(0, 6), 7, True),
    "walk":      (rng(0, 6), 10, True),      # his sheet has no separate walk
    "kick":      (rng(7, 8), 9, False),
    "highKick":  (rng(15, 16), 8, False),
    "knockdown": (rng(12, 13), 6, False),
    "arrive":    (rng(15, 16), 8, False),
    "depart":    (rng(0, 6), 10, False),
}

SLUM = {
    "rest":      (rng(12, 15), 7, True),
    "walk":      (rng(12, 15), 10, True),
    "punch":     (rng(16, 19), 11, False),
    "attack":    (rng(5, 9), 10, False),
    "knockdown": (rng(10, 11), 6, False),
    "arrive":    (rng(16, 19), 10, False),
    "depart":    (rng(12, 15), 10, False),
}


# --------------------------------------------------------------------------
# The Sonic cast, Ristar and Terry Bogard.
#
# These sheets are laid out by section rather than by band, with labels and
# palette strips among the sprites, so the ranges below were read off
# tools/index.py by eye. Anything not listed here is a caption, a colour
# swatch, or a pose with a sheet annotation sitting in it.
# --------------------------------------------------------------------------

SONIC = {                                  # Sonic the Hedgehog 2
    "rest":      ([26, 26, 26, 27], 3, True),      # idle, with a blink
    "walk":      (rng(41, 48), 12, True),
    "run":       (rng(49, 52), 16, True),
    "skid":      (rng(53, 56), 12, False),
    "bored":     (rng(28, 31), 5, False),
    "sit":       ([32, 33, 34], 5, False),         # very bored, sits down
    "lookUp":    ([35, 36, 37], 5, False),
    "crouch":    ([38, 39], 7, False),
    "arrive":    (rng(49, 52), 16, False),
    "depart":    (rng(49, 52), 16, False),
}

TAILS = {                                  # Sonic & Knuckles, lock-on
    "rest":      ([145, 146], 3, True),
    "walk":      (rng(110, 117), 12, True),
    "fly":       (rng(119, 123), 10, True),
    "roll":      (rng(154, 158), 12, False),
    "arrive":    (rng(119, 123), 10, False),
    "depart":    (rng(110, 117), 12, False),
}

KNUCKLES = {                               # Sonic & Knuckles
    "rest":      (rng(18, 22), 4, True),
    "bored":     (rng(23, 26), 5, False),
    "walk":      (rng(43, 50), 12, True),
    "run":       (rng(51, 54), 15, True),
    "roll":      (rng(55, 59), 13, False),
    "arrive":    (rng(51, 54), 15, False),
    "depart":    (rng(51, 54), 15, False),
}

ROBOTNIK = {                               # Sonic the Hedgehog, out of the pod
    "rest":      ([129, 130], 3, True),
    "laugh":     ([131, 132], 5, False),
    "hit":       ([133, 134], 6, False),
    "walk":      ([136, 137, 139], 8, True),       # 138 has a panel behind it
    "crouch":    ([140, 140], 4, False),
    "cheer":     ([141, 142, 143], 5, False),
    "arrive":    ([136, 137, 139], 8, False),
    "depart":    ([136, 137, 139], 8, False),
}

MECHA = {                                  # Mecha Sonic, Sonic the Hedgehog 2
    "rest":      (rng(11, 14), 6, True),
    "walk":      (rng(11, 14), 8, True),           # he hovers rather than walks
    "spin":      (rng(20, 22), 12, False),
    "dash":      ([27, 28, 29], 10, False),
    "arrive":    ([9, 10], 7, False),
    "depart":    ([10, 9], 7, False),
}

RISTAR = {                                 # Ristar
    "rest":      (rng(0, 4), 5, True),
    "walk":      (rng(47, 54), 12, True),
    "jump":      (rng(55, 59), 10, False),
    "roll":      (rng(61, 64), 12, False),
    "cheer":     (rng(211, 214), 8, False),
    "celebrate": (rng(221, 223), 7, False),
    "arrive":    (rng(55, 59), 10, False),
    "depart":    (rng(47, 54), 12, False),
}

SONIC3D = {                                # Sonic 3D Blast
    # The sheet ships each sprite's drop shadow as its own frame, so the
    # numbering runs sprite, sprite, ..., shadow, shadow. Only the sprites.
    "rest":      (rng(9, 15), 6, True),
    "walk":      (rng(49, 56), 12, True),
    "arrive":    (rng(49, 56), 12, False),
    "depart":    (rng(49, 56), 12, False),
}

TERRY = {                                  # Fatal Fury 2
    "rest":      (rng(0, 4), 6, True),
    "walk":      (rng(5, 7), 8, True),
    "crouch":    (rng(8, 10), 8, False),
    "jump":      (rng(11, 14), 10, False),
    "knockdown": ([15, 16], 7, False),
    "punch":     (rng(22, 26), 13, False),
    "kick":      (rng(27, 30), 13, False),
    "highKick":  ([31, 32], 10, False),
    "arrive":    (rng(5, 7), 8, False),
    "depart":    (rng(5, 7), 8, False),
}

for name, clips in [("axel", AXEL), ("blaze", BLAZE), ("max", MAX), ("skate", SKATE),
                    ("adam", ADAM), ("axel1", AXEL1), ("blaze1", BLAZE1),
                    ("galsia", GALSIA), ("donovan", DONOVAN), ("eagle", EAGLE),
                    ("slum", SLUM),
                    ("sonic", SONIC), ("tails", TAILS), ("knuckles", KNUCKLES),
                    ("robotnik", ROBOTNIK), ("mecha", MECHA), ("ristar", RISTAR),
                    ("terry", TERRY), ("sonic3d", SONIC3D)]:
    if not os.path.isdir(f"app/Resources/characters/{name}/frames"):
        print(f"{name}: no sprites imported, skipping")
        continue
    build(name, clips)
