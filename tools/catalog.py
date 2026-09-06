"""Author the animation catalogue for each character.

Usage: catalog.py            (writes both)
"""
import json, os


def rng(a, b):
    return list(range(a, b + 1))


# The mouth patches per pose are visemes, not an openness ramp, so they have to
# be ordered before loudness can index them. No one measurement works for every
# character: Bonzi's open mouth is a dark cavity and barely changes in warm-pixel
# span, Peedy's open beak shows a tongue, and Max's beak is warm all over so its
# span hardly moves at all (31 to 36 pixels across a whole set) while the tongue
# behind it goes from 0 pixels to 17. So measure three ways and let each
# character's own data decide which one actually discriminates.
from PIL import Image


def _measure(who, index):
    """(warm lip/beak span, dark cavity pixels, mouth-interior pixels)."""
    im = Image.open(f"assets/{who}/rgba/{index:04d}.png").convert("RGBA")
    rows, dark, inside = set(), 0, 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if not a:
                continue
            if r > 150 and g > 80 and b < 130 and r > b + 40:
                rows.add(y)
            if r < 90 and g < 90 and b < 90:
                dark += 1
            # Pink: a tongue, or the inside of a mouth. Only visible when open.
            if r > 130 and g < 140 and b > 60 and r > g + 40 and b > g - 20:
                inside += 1
    return (max(rows) - min(rows) + 1 if rows else 0), dark, inside


def _spread(values):
    lo, hi = min(values), max(values)
    return (hi - lo) / hi if hi > 0 else 0


def measured_ramps(who, talk):
    if not talk:
        print(f"  {who}: no talk poses declared")
        return {}

    """Order every mouth set closed -> widest, using whichever metric separates
    this character's visemes more cleanly."""
    scored = {name: [_measure(who, m) for m in pose["mouths"]]
              for name, pose in talk.items()}

    best, chosen = None, 0
    for metric in (0, 1, 2):
        widest = {max(range(len(v)), key=lambda i: v[i][metric]) for v in scored.values()}
        spread = sum(_spread([x[metric] for x in v]) for v in scored.values()) / len(scored)
        # Fewest disagreements about which viseme is widest wins; ties go to
        # whichever has more dynamic range to work with.
        score = (-len(widest), spread)
        if best is None or score > best:
            best, chosen = score, metric

    print(f"  {who}: using the {['warm-span', 'dark-cavity', 'mouth-interior'][chosen]} "
          f"metric (agreement {-best[0]}, spread {best[1]:.2f})")
    return {name: [pose["mouths"][i]
                   for i in sorted(range(len(pose["mouths"])),
                                   key=lambda i: scored[name][i][chosen])]
            for name, pose in talk.items()}


# --------------------------------------------------------------------------
# Peedy - quick, fussy, theatrical.
# --------------------------------------------------------------------------
PEEDY = {
    "rest":            (rng(342, 353), 10, True),
    "blink":           ([353, (353, 354), (353, 355), (353, 354), 353], 14, False),
    "lookAround":      (rng(218, 228), 10, False),
    "surprised":       (rng(246, 260), 14, False),
    "greet":           (rng(401, 412), 14, False),
    "announce":        (rng(36, 46), 12, False),
    "shrug":           (rng(280, 286), 12, False),
    "cheer":           (rng(294, 304), 14, False),
    "flourish":        (rng(505, 513), 12, False),
    "gestureUp":       (rng(167, 172), 12, False),
    "gestureDown":     (rng(137, 144), 12, False),
    # 202-210 extends a wing to the viewer's right; mirror it to aim left.
    "point":           (rng(202, 210), 12, False),
    "wingSweep":       (rng(180, 194), 12, False),
    "arrive":          (rng(6, 28), 14, False),
    "depart":          (rng(377, 399), 14, False),
    "takeoff":         (rng(413, 421), 16, False),
    "fly":             (rng(422, 431), 16, True),
    "land":            (rng(432, 441), 16, False),
    "headphonesOn":    (rng(442, 459), 12, False),
    "listening":       (rng(460, 469), 10, True),
    "idea":            (rng(483, 497), 12, False),
    "writeStart":      (rng(521, 530), 12, False),
    "writing":         (rng(531, 543), 12, True),
    "searchStart":     (rng(575, 586), 12, False),
    "telescope":       (rng(587, 616), 14, False),
    "sunglassesOn":    (rng(617, 631), 12, False),
    "sunglassesIdle":  (rng(632, 643), 10, True),
    "proud":           (rng(644, 648), 10, False),
    "readStart":       (rng(656, 673), 12, False),
    "reading":         (rng(681, 697), 10, True),
}

PEEDY_TALK = {
    "neutral":  {"body": 28,  "mouths": rng(29, 35)},
    "reading":  {"body": 673, "mouths": rng(674, 680)},
    "writing":  {"body": 543, "mouths": rng(544, 550)},
    "proud":    {"body": 648, "mouths": rng(649, 655)},
    "announce": {"body": 60,  "mouths": rng(61, 67)},
    "idea":     {"body": 497, "mouths": rng(498, 504)},
}

# --------------------------------------------------------------------------
# Bonzi - slow, heavy, unbothered. A gorilla swings in on a vine and eats a
# banana; nothing about him is quick.
# --------------------------------------------------------------------------
BONZI = {
    "rest":            (rng(999, 1010), 8, True),
    "blink":           ([1010, (1010, 1011), (1010, 1012), (1010, 1011), 1010], 14, False),
    "lookAround":      (rng(74, 87), 10, False),
    "surprised":       (rng(481, 487), 12, False),
    "greet":           (rng(146, 155), 12, False),          # ends on a wave
    "announce":        (rng(1097, 1102), 10, False),
    "shrug":           (rng(28, 45), 11, False),
    "cheer":           (rng(481, 487), 12, False),
    "scratchHead":     (rng(88, 111), 11, False),
    "point":           (rng(125, 145), 11, False),          # arm out, viewer-right
    "handsOnHips":     (rng(112, 117), 10, False),
    # He swings in and out on a vine. Nothing else in either sprite set is
    # anywhere near as good an entrance.
    "arrive":          (rng(1140, 1162), 16, False),
    "depart":          (rng(1163, 1188), 16, False),
    "vineSwing":       (rng(1192, 1213), 14, False),
    "poof":            (rng(163, 180), 13, False),          # inflates, then puffs
    "juggle":          (rng(645, 661), 14, False),          # coconuts
    "eatBanana":       (rng(831, 872), 14, False),
    "sitDown":         (rng(495, 520), 12, False),
    "sitting":         (rng(520, 530), 7, True),
    "standUp":         (rng(531, 541), 12, False),
    "readStart":       (rng(208, 230), 12, False),          # sits and opens a book
    "reading":         (rng(233, 250), 8, True),
    "globe":           (rng(266, 312), 14, False),          # spins a globe
    "headphonesOn":    (rng(794, 802), 12, False),
    "listening":       (rng(803, 824), 9, True),
    "headphonesOff":   (rng(825, 830), 12, False),
    "sunglassesOn":    (rng(445, 455), 12, False),
    "sunglassesIdle":  (rng(455, 465), 8, True),
    "sunglassesOff":   (rng(466, 473), 12, False),
    "paper":           (rng(772, 785), 11, False),
}

BONZI_TALK = {
    "neutral":    {"body": 1102, "mouths": rng(1103, 1109)},
    "announce":   {"body": 487,  "mouths": rng(488, 494)},
    "sunglasses": {"body": 473,  "mouths": rng(474, 480)},
    "paper":      {"body": 764,  "mouths": rng(765, 771)},
    "banana":     {"body": 886,  "mouths": rng(887, 893)},
    "gesture":    {"body": 155,  "mouths": rng(156, 162)},
}

# Costume bits have no "take it off" clips; the intro played backwards undoes
# it, which is how the originals worked too.
# --------------------------------------------------------------------------
# Max - MaxALERT. A blue macaw with the same bones as the BonziBUDDY pair:
# full-body frames with viseme patches registered to eight of them. Everything
# he does is done with his wings.
# --------------------------------------------------------------------------
MAX = {
    "rest":        (rng(126, 137), 8, True),
    "blink":       ([137, (137, 138), (137, 139), (137, 138), 137], 14, False),
    "settle":      (rng(233, 244), 8, True),
    "lookAround":  (rng(223, 229), 10, False),
    "greet":       (rng(147, 155), 12, False),
    "cheer":       (rng(257, 270), 14, False),
    "flap":        (rng(156, 165), 14, True),
    "announce":    (rng(11, 17), 12, False),
    "gesture":     (rng(38, 43), 12, False),
    "explain":     (rng(64, 69), 12, False),
    "point":       (rng(77, 82), 12, False),
    "excited":     (rng(90, 95), 12, False),
    "flourish":    (rng(245, 249), 10, False),
    "wingsOut":    (rng(219, 222), 10, False),
    "arrive":      (rng(204, 218), 14, False),
    "depart":      (rng(109, 124), 14, False),
}

MAX_TALK = {
    "neutral":  {"body": 30,  "mouths": rng(31, 37)},
    "announce": {"body": 17,  "mouths": rng(18, 24)},
    "gesture":  {"body": 43,  "mouths": rng(44, 50)},
    "aside":    {"body": 56,  "mouths": rng(57, 63)},
    "explain":  {"body": 69,  "mouths": rng(70, 76)},
    "point":    {"body": 82,  "mouths": rng(83, 89)},
    "excited":  {"body": 95,  "mouths": rng(96, 102)},
}

# --------------------------------------------------------------------------
# Merlin - Microsoft Office XP. A wizard, which the sprite set takes seriously:
# he arrives by materialising out of nothing and leaves by folding up into his
# own robe. Nine viseme sets, including one for holding a book and one for
# holding a trophy.
# --------------------------------------------------------------------------
MERLIN = {
    "rest":       (rng(0, 5), 7, True),
    "blink":      ([10, (10, 11), (10, 12), (10, 11), 10], 14, False),
    "explain":    (rng(21, 25), 10, False),
    "cauldron":   (rng(33, 46), 10, False),
    "spell":      (rng(65, 87), 12, False),
    "gesture":    (rng(51, 55), 10, False),
    "greet":      (rng(95, 99), 10, False),
    "readStart":  (rng(112, 130), 11, False),
    "trophy":     (rng(139, 151), 11, False),
    "cheer":      (rng(139, 151), 11, False),
    "poof":       (rng(160, 169), 12, False),
    "idea":       (rng(183, 190), 10, False),
    "ideaEnd":    (rng(198, 205), 10, False),
    "lookAround": (rng(235, 238), 9, False),
    "flourish":   (rng(210, 212), 8, False),
    "arrive":     (rng(427, 437), 12, False),
    "depart":     (rng(438, 442), 10, False),
}

MERLIN_TALK = {
    "neutral":  {"body": 13,  "mouths": rng(14, 20)},
    "explain":  {"body": 25,  "mouths": rng(26, 32)},
    "gesture":  {"body": 87,  "mouths": rng(88, 94)},
    "book":     {"body": 131, "mouths": rng(132, 138)},
    "trophy":   {"body": 152, "mouths": rng(153, 159)},
    "idea":     {"body": 190, "mouths": rng(191, 197)},
    "aside":    {"body": 467, "mouths": rng(468, 474)},
    "settled":  {"body": 496, "mouths": rng(497, 503)},
}

REVERSALS = {
    "rover": [("arrive", "depart"), ("readEnd2", "readStart"),
              ("paperDrop", "paperFetch")],
    # Several of these rips have one of the pair and not the other: Clippy
    # folds himself away but is never seen unfolding, Earl surfs in from the
    # distance but never off. Played backwards, one is the other.
    "clippy": [("arrive", "depart"), ("headphonesOff", "headphones")],
    "earl": [("depart", "arrive"), ("sunglassesOff", "sunglasses"),
             ("pyjamasOff", "pyjamas")],
    "f1": [("depart", "arrive")],
    "manma": [("arrive", "greet"), ("depart", "greet")],
    "merlin": [("readEnd", "readStart"), ("trophyEnd", "trophy")],
    "peedy": [("headphonesOff", "headphonesOn"), ("sunglassesOff", "sunglassesOn"),
              ("readEnd", "readStart"), ("writeEnd", "writeStart"),
              ("searchEnd", "searchStart")],
    "bonzi": [("readEnd", "readStart"), ("globeEnd", "globe")],
}


def norm(steps):
    out = []
    for s in steps:
        out.append({"f": s[0], "o": s[1]} if isinstance(s, tuple) else {"f": s})
    return out


# --------------------------------------------------------------------------
# Rover - Microsoft Office XP. The search dog. His rip is finished frames with
# no overlays at all — six small frames in seven hundred, none of them a mouth
# — so he has no talk poses and gestures while he speaks instead. He does have
# a panting loop, which is the next best thing to a mouth.
# --------------------------------------------------------------------------
ROVER = {
    "rest":       (rng(149, 179), 8, True),
    "sit":        (rng(130, 148), 8, False),
    "pant":       (rng(293, 302), 10, True),
    "walk":       (rng(58, 91), 12, True),
    "sniff":      (rng(98, 125), 10, True),
    "turn":       (rng(307, 313), 10, False),
    "greet":      (rng(128, 140), 10, False),
    "fetch":      (rng(335, 340), 10, False),
    "readStart":  (rng(2, 8), 10, False),
    "reading":    (rng(9, 45), 8, True),
    "readEnd":    (rng(47, 54), 10, False),
    "paperFetch": (rng(380, 385), 10, False),
    "paper":      (rng(386, 394), 8, True),
    "depart":     (rng(319, 332), 12, False),
}

# --------------------------------------------------------------------------
# Clippit, Earl, F1 and Manma-chan - Microsoft Office XP. Ripped the same way
# as Rover: finished frames, no overlays, so no talk poses. Each has a loop
# with enough movement in it to carry a sentence.
# --------------------------------------------------------------------------
CLIPPY = {
    "rest":        (rng(7, 26), 9, True),
    "express":     (rng(27, 45), 10, True),
    "greet":       (rng(46, 67), 10, False),
    "flatten":     (rng(70, 80), 10, False),
    "spin":        (rng(152, 170), 14, False),
    "headphones":  (rng(330, 345), 11, False),
    "listening":   (rng(346, 358), 9, True),
    "write":       (rng(359, 364), 9, False),
    "depart":      (rng(174, 182), 12, False),
}

EARL = {
    "rest":        (rng(13, 29), 9, True),
    "greet":       (rng(30, 34), 9, False),
    "flourish":    (rng(388, 393), 10, False),
    "sunglasses":  (rng(394, 405), 10, False),
    "pyjamas":     (rng(407, 430), 10, False),
    "ball":        (rng(436, 448), 11, False),
    "card":        (rng(456, 467), 10, False),
    "arrive":      (rng(0, 12), 12, False),
}

F1 = {
    "rest":        (rng(13, 46), 10, True),
    "settle":      (rng(7, 10), 8, False),
    "greet":       (rng(98, 102), 10, False),
    "birdhouse":   (rng(78, 93), 10, False),
    "arrive":      (rng(2, 10), 12, False),
}

MANMA = {
    "rest":        (rng(25, 34), 9, True),
    "fidget":      (rng(35, 40), 9, True),
    "greet":       (rng(22, 24), 8, False),
    "bowl":        (rng(45, 54), 9, False),
    "writeStart":  (rng(0, 8), 10, False),
    "writing":     (rng(9, 14), 9, True),
    "writeEnd":    (rng(15, 21), 10, False),
}

# The frame that stands in for a character in the menu bar: a clear, front-on
# pose that survives being shrunk to 18 points and cut to a silhouette.
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

MAXSOR = {
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


# --------------------------------------------------------------------------
# The third batch: platformers, brawlers and one pop star.
#
# Same rule as the Sonic sheets — every range below was read off
# tools/index.py by eye, and anything not listed is a caption, a palette
# strip, or a frame with a sheet annotation sitting in it.
# --------------------------------------------------------------------------

JIM = {                                    # Earthworm Jim 2
    "rest":      (rng(25, 31), 6, True),
    "walk":      (rng(110, 121), 14, True),
    "whip":      (rng(32, 39), 12, False),
    "getUp":     (rng(60, 65), 10, False),
    "arrive":    (rng(110, 121), 14, False),
    "depart":    (rng(110, 121), 14, False),
}

PULSEMAN = {                               # Pulseman
    "rest":      (rng(9, 13), 5, True),
    "walk":      (rng(1, 3), 8, True),
    "attack":    (rng(16, 19), 11, False),
    "arrive":    (rng(1, 3), 8, False),
    "depart":    (rng(1, 3), 8, False),
}

TOEJAM = {                                 # ToeJam & Earl: Panic on Funkotron
    "rest":      (rng(20, 24), 5, True),
    "walk":      (rng(52, 59), 11, True),
    "dance":     (rng(62, 67), 9, False),
    "dash":      (rng(78, 83), 13, False),
    "arrive":    (rng(52, 59), 11, False),
    "depart":    (rng(52, 59), 11, False),
}

EARLTJE = {                                   # the other half of the double act
    "rest":      ([54, 55], 3, True),
    "walk":      (rng(56, 65), 11, True),
    "arrive":    (rng(56, 65), 11, False),
    "depart":    (rng(56, 65), 11, False),
}

ROBERT = {                                 # Art of Fighting
    "rest":      (rng(0, 3), 6, True),
    "walk":      (rng(4, 8), 9, True),
    "crouch":    ([9, 10], 8, False),
    "punch":     ([11, 12, 11], 12, False),
    "kick":      ([16, 17], 10, False),
    "jumpKick":  ([18, 19], 9, False),
    "sweep":     ([21, 22], 9, False),
    "arrive":    (rng(4, 8), 9, False),
    "depart":    (rng(4, 8), 9, False),
}

DONALD = {                                 # World of Illusion
    "rest":      (rng(0, 5), 6, True),
    "walk":      (rng(6, 11), 10, True),
    "run":       (rng(12, 17), 14, True),
    "cape":      (rng(36, 39), 8, False),
    "wave":      (rng(52, 55), 7, False),
    "arrive":    (rng(6, 11), 10, False),
    "depart":    (rng(6, 11), 10, False),
}

MOONWALKER = {                             # Michael Jackson's Moonwalker
    "rest":      ([22, 23], 3, True),
    "walk":      (rng(0, 11), 12, True),
    "dance":     (rng(43, 47), 8, False),
    "kick":      (rng(36, 41), 11, False),
    "spin":      (rng(32, 35), 10, False),
    "arrive":    (rng(0, 11), 12, False),
    "depart":    (rng(0, 11), 12, False),
}

GAMBIT = {                                 # X-Men 2: Clone Wars
    "rest":      (rng(28, 33), 6, True),
    "walk":      (rng(37, 42), 11, True),
    "crouch":    (rng(34, 36), 9, False),
    "staff":     (rng(49, 51), 11, False),
    "strike":    (rng(52, 54), 11, False),
    "arrive":    (rng(37, 42), 11, False),
    "depart":    (rng(37, 42), 11, False),
}

SKETCH = {                                 # Comix Zone
    "rest":      (rng(0, 7), 6, True),
    "walk":      (rng(36, 41), 10, True),
    "run":       (rng(42, 47), 14, True),
    "punch":     (rng(12, 15), 12, False),
    "throw":     (rng(25, 28), 12, False),
    "arrive":    (rng(36, 41), 10, False),
    "depart":    (rng(36, 41), 10, False),
}

RYU = {                                    # Street Fighter II: SCE
    "rest":      (rng(0, 3), 6, True),
    "walk":      (rng(4, 7), 8, True),
    "crouch":    ([8, 9], 8, False),
    "jump":      (rng(10, 13), 10, False),
    "punch":     ([19, 20, 19], 12, False),
    "uppercut":  (rng(28, 31), 11, False),
    "arrive":    (rng(4, 7), 8, False),
    "depart":    (rng(4, 7), 8, False),
}

MUSASHI = {                                # Shinobi III
    "rest":      (rng(0, 3), 5, True),
    "walk":      (rng(10, 16), 12, True),
    "throw":     (rng(7, 9), 12, False),
    "slash":     (rng(17, 20), 14, False),
    "strike":    (rng(21, 24), 13, False),
    "arrive":    (rng(10, 16), 12, False),
    "depart":    (rng(10, 16), 12, False),
}

SPARKSTER = {                              # Rocket Knight Adventures
    "rest":      ([12, 13, 14], 5, True),
    "walk":      (rng(28, 39), 12, True),
    "arrive":    (rng(28, 39), 12, False),
    "depart":    (rng(28, 39), 12, False),
}


# --------------------------------------------------------------------------
# The Hyperstone Heist turtles.
#
# Their sheets are the ones that needed `sheet.py --blobs`: the sprites sit at
# whatever height suits them, so bands and columns weld neighbours together.
# Frames here are numbered by the blob cut, and the idle, walk and attack rows
# were found by matching frames back to their position on the sheet.
# --------------------------------------------------------------------------

RAPHAEL = {
    "rest":      (rng(7, 10), 4, True),
    "walk":      (rng(22, 25), 10, True),
    "strike":    (rng(43, 46), 13, False),
    "arrive":    (rng(22, 25), 10, False),
    "depart":    (rng(22, 25), 10, False),
}

LEONARDO = {
    "rest":      (rng(7, 10), 4, True),
    "walk":      (rng(21, 24), 10, True),
    "strike":    (rng(39, 42), 13, False),
    "arrive":    (rng(21, 24), 10, False),
    "depart":    (rng(21, 24), 10, False),
}

MICHELANGELO = {
    "rest":      ([11, 12, 7, 15], 4, True),
    "walk":      (rng(20, 23), 10, True),
    "strike":    (rng(41, 44), 13, False),
    "arrive":    (rng(20, 23), 10, False),
    "depart":    (rng(20, 23), 10, False),
}

DONATELLO = {
    "rest":      (rng(7, 10), 4, True),
    "walk":      (rng(18, 21), 10, True),
    "strike":    (rng(42, 45), 13, False),
    "arrive":    (rng(18, 21), 10, False),
    "depart":    (rng(18, 21), 10, False),
}


# --------------------------------------------------------------------------
# Two more of a character we already have, from games we don't.
# --------------------------------------------------------------------------

AXEL3 = {                                  # Streets of Rage 3
    "rest":      (rng(0, 5), 6, True),
    "walk":      (rng(6, 12), 12, True),
    "run":       (rng(13, 17), 15, True),
    "punch":     (rng(23, 26), 13, False),
    "kick":      (rng(32, 35), 12, False),
    "knockdown": (rng(18, 21), 9, False),
    "arrive":    (rng(6, 12), 12, False),
    "depart":    (rng(6, 12), 12, False),
}

SPINBALL = {                               # Sonic Spinball
    "rest":      ([52, 53, 55], 3, True),
    "walk":      (rng(25, 31), 11, True),
    "run":       (rng(32, 39), 15, True),
    "spin":      (rng(40, 45), 14, False),
    "push":      (rng(20, 24), 9, False),
    "arrive":    (rng(32, 39), 15, False),
    "depart":    (rng(32, 39), 15, False),
}


HEROES = {"peedy": 380, "bonzi": 1159, "max": 126, "merlin": 0,
          "rover": 149, "clippy": 7, "earl": 13, "f1": 13, "manma": 25,
          # The game cast. Portraits where a sheet has them: they read far
          # better at 18pt than an action frame, which flattens to a blob.
          "axel": 157, "blaze": 181, "maxsor": 145, "skate": 88, "slum": 12,
          "sonic": 26, "tails": 145, "knuckles": 18, "robotnik": 129,
          "mecha": 12, "sonic3d": 9, "jim": 27, "pulseman": 11, "toejam": 22,
          "earltje": 54, "robert": 0, "donald": 0, "moonwalker": 22,
          "gambit": 30, "sketch": 0, "ryu": 0, "musashi": 0, "sparkster": 13,
          "ristar": 0, "terry": 0, "raphael": 7, "leonardo": 7,
          "michelangelo": 11, "donatello": 7, "axel3": 0, "spinball": 52}


def build(name, clips, talk):
    clips = dict(clips)
    for new, src in REVERSALS.get(name, []):
        steps, fps, _ = clips[src]
        clips[new] = (list(reversed(steps)), fps, False)

    ramps = measured_ramps(name, talk)
    data = {
        "animations": {n: {"steps": norm(s), "fps": f, "loop": l}
                       for n, (s, f, l) in clips.items()},
        "talk": {n: {**pose, "ramp": ramps[n]} for n, pose in talk.items()},
        "hero": HEROES.get(name, 0),
    }
    out = f"app/Resources/characters/{name}"
    os.makedirs(out, exist_ok=True)
    json.dump(data, open(f"{out}/animations.json", "w"), indent=1)
    print(f"{name}: {len(clips)} animations, {len(talk)} talk poses")


import os.path

# --------------------------------------------------------------------------
# SNES Buddies. Twenty rips from sixteen different games, so unlike the Streets
# of Rage cast there is no shared layout to lean on — each sheet was cut with
# `sheet.py` or `blobs.py`, rendered with `index.py`, and read by eye.
#
# Two things about these sheets that the Genesis rips did not have:
#
# Captions are frames. Every SNES rip here labels its animations, and those
# labels segment exactly like sprites do. On the Super Mario World sheet they
# land on their own rows, which is harmless. On Samus's they outnumber the
# sprites, and on Simon's they sit mid-row between the walk and the whip. None
# of them can be filtered by size without also throwing away a crouch, so every
# range below was read off a rendered index.
#
# Nobody has both a walk and an idle worth looping. A beat-'em-up sprite stands
# guard for eight frames because standing guard is a pose in that genre; a
# platformer hero stands on one frame and waits. So several `rest` clips here
# are a single frame held, which is what the source art is, rather than a loop
# invented by repeating frames that were never drawn to cycle.
# --------------------------------------------------------------------------

# Super Mario World. `Idle | Look Up | Duck | Walk | Run` are captioned on the
# row above their sprites, which is the only reason the two-frame walk is
# identifiable at all — 12 and 13 differ by about a shoelace.
MARIO = {
    "rest":      ([9], 4, True),
    "walk":      (rng(12, 13), 8, True),
    "run":       (rng(14, 16), 12, True),
    "duck":      ([11], 6, False),
    "lookUp":    ([10], 4, False),
    "jump":      ([33], 8, False),
    "victory":   ([45], 5, False),
    "arrive":    ([33, 9], 6, False),
    "depart":    (rng(12, 13), 8, False),
}

# Luigi, from the same All-Stars sheet laid out the same way — but not at the
# same indices, and this is the trap that caught this cast. His sheet cuts to
# twelve fewer frames, and the drift does not start at the top: 9 through 33
# are identical to Mario's, so copying the whole block across looks right and
# is right, until `victory`. Mario's is 45; at 45 Luigi has the caption
# "Hold", and his victory pose is 44.
#
# Nothing catches that. The frame exists, it is a plausible size, and it sits
# in the row the walk came from — it is simply the word "Hold" in yellow. It
# took rendering the clips with `clips.py` and looking at them.
LUIGI = {
    "rest":      ([9], 4, True),
    "walk":      (rng(12, 13), 8, True),
    "run":       (rng(14, 16), 12, True),
    "duck":      ([11], 6, False),
    "lookUp":    ([10], 4, False),
    "jump":      ([33], 8, False),
    "victory":   ([44], 5, False),
    "arrive":    ([33, 9], 6, False),
    "depart":    (rng(12, 13), 8, False),
}

# Kirby Super Star. The cleanest sheet of the twelve — no captions anywhere —
# and the puffed-up float frames at 29-32 are a second travel cycle in their
# own right, which is why he is the one character here who walks and flies.
KIRBY = {
    "rest":      ([0, 0, 0, 1], 3, True),
    "walk":      (rng(7, 10), 10, True),
    "float":     (rng(29, 32), 6, True),
    "inhale":    (rng(14, 16), 8, False),
    "jump":      ([13], 8, False),
    "shout":     ([6], 6, False),
    "squash":    ([11], 6, False),
    "arrive":    (rng(29, 32), 6, False),
    "depart":    (rng(7, 10), 10, False),
}

# Super Metroid. A 6496x4384 sheet that is more caption than sprite: the rip
# labels every animation index, so 917 of its components are text and get
# dropped by size. What survives is clean, and 114-117 is the walk.
#
# `rest` is 63 and not the front-facing 58 it started as. Both are Samus
# standing still and 58 is the better drawing, but everything else she does here
# is in profile, so a face-on idle would turn ninety degrees the moment she took
# a step. She keeps the face-on pose as `stand`, where turning towards you is
# deliberate and reads as a flourish rather than a snap.
SAMUS = {
    "rest":      ([63], 4, True),
    "walk":      (rng(114, 117), 10, True),
    "aimUp":     ([85], 6, False),
    "crouch":    ([95], 6, False),
    "stand":     ([58], 4, False),
    "arrive":    ([58, 63], 4, False),
    "depart":    (rng(114, 117), 10, False),
}

# The last Metroid, from the same game. It has no walk because it has no legs:
# the sheet is one creature at three membrane sizes, cycling colour. The pulse
# is made by stepping across those sizes rather than along a row.
METROID = {
    "rest":      ([0, 10, 20, 10], 5, True),
    "float":     ([0, 10, 20, 10], 5, True),
    "flash":     ([4, 14, 24], 8, False),
    "arrive":    ([20, 10, 0], 6, False),
    "depart":    ([0, 10, 20], 6, False),
}

# Mega Man X. The sheet draws every armour part in bordered panels, and those
# borders weld the whole 1420x3294 image into one component — it cuts to
# exactly one frame with `sheet.py`. `blobs.py` with the panel colour keyed is
# the only reason he is in this cast.
MEGAMANX = {
    "rest":      ([13], 4, True),
    "walk":      (rng(76, 83), 14, True),
    "dash":      ([26], 8, False),
    "shoot":     ([44, 46], 10, False),
    "attack":    ([44, 46], 10, False),
    "jump":      ([62], 8, False),
    "charge":    (rng(30, 33), 10, False),
    "arrive":    ([62, 13], 6, False),
    "depart":    (rng(76, 83), 14, False),
}

# Donkey Kong Country. The biggest sprite here by a wide margin, and he walks
# on his knuckles, so the walk is the four-legged gait rather than anything
# upright.
#
# The gait alternates: he gathers (73, 74, 76, 78, at 38-44 wide) and then
# lunges onto his hands (75, 77, 79, 82, at 52-66 wide). Reading the row that
# looked like one animation, the first guess was 72-83 — but 72 is still the
# upright stance he pushes off from, so it would drop a standing frame into the
# gait once per cycle. The walk starts at 73. The gallop at 84-95 is the same
# alternation stretched further, which is why it reads as a run.
DK = {
    "rest":      (rng(0, 10), 8, True),
    "walk":      (rng(73, 83), 10, True),
    "run":       (rng(84, 95), 14, True),
    "chestBeat": (rng(26, 33), 10, False),
    "clap":      (rng(38, 46), 10, False),
    "arrive":    (rng(26, 33), 10, False),
    "depart":    (rng(73, 83), 10, False),
}

# Diddy Kong, same rip. `Walking` and `Running` are captioned as separate 32x9
# frames at 42 and 43, which is what makes 44 the first frame of the walk and
# not the last of the idle. The idle stops at 8: from 9 he starts a second,
# wider fidget that does not join back onto the first, so looping the two
# together would put a jump between two stances in the middle of the cycle.
DIDDY = {
    "rest":      (rng(1, 8), 8, True),
    "walk":      (rng(44, 51), 12, True),
    "cartwheel": (rng(73, 80), 14, False),
    "jump":      ([95], 8, False),
    "arrive":    (rng(73, 80), 14, False),
    "depart":    (rng(44, 51), 12, False),
}

# Dixie Kong, Diddy's Kong Quest. Twelve frames of idle — she flicks her
# ponytail while standing, which is the longest genuine idle loop in this cast.
DIXIE = {
    "rest":      (rng(0, 11), 8, True),
    "walk":      (rng(51, 62), 12, True),
    # 65 is two sprites the cutter joined into one frame, so the run skips it
    # rather than showing a double Dixie once a cycle.
    "run":       (rng(66, 74), 14, True),
    "jump":      ([79], 8, False),
    "arrive":    (rng(66, 74), 14, False),
    "depart":    (rng(51, 62), 12, False),
}

# Squawks the parrot. A four-frame flap and very little else — the rest of his
# sheet is the DKC3 recolour and the purple Quawks. The flap is his idle and
# his cruise both, because a hovering parrot never stops flapping.
SQUAWKS = {
    "rest":      (rng(0, 3), 8, True),
    "flap":      (rng(0, 3), 11, True),
    "takeoff":   (rng(0, 1), 10, False),
    "land":      (rng(2, 3), 10, False),
    "arrive":    (rng(0, 3), 11, False),
    "depart":    (rng(0, 3), 11, False),
}

# Super Castlevania IV. Six captions on their own row name the six blocks in
# the row above: idle, ducking, jumping, six frames of walk, then the stairs.
SIMON = {
    "rest":      ([0], 4, True),
    "walk":      (rng(3, 8), 10, True),
    "duck":      ([1], 6, False),
    "jump":      ([2], 8, False),
    "whip":      (rng(52, 57), 12, False),
    "attack":    (rng(52, 57), 12, False),   # the whip, by its sparring name
    "arrive":    (rng(52, 57), 12, False),
    "depart":    (rng(3, 8), 10, False),
}

# Earthworm Jim, out of the suit (SNES). He has no legs either, but unlike the Metroid
# he travels: `Squirming` at 15-22 is a whole-body crawl, and it is by some way
# the best-looking walk cycle in this cast.
JIMWORM = {
    "rest":      (rng(0, 2), 4, True),
    "squirm":    (rng(15, 22), 12, True),
    "walk":      (rng(15, 22), 12, True),
    "jump":      (rng(24, 29), 12, False),
    "spin":      (rng(46, 49), 12, False),
    "arrive":    (rng(24, 29), 12, False),
    "depart":    (rng(15, 22), 12, False),
}


# --------------------------------------------------------------------------
# The second wave: four Turtles, two brawlers, a Belmont and a Pac-Man.
#
# Every one of these came off a sheet that needed its own dilation setting,
# which is the thing the first twelve did not teach. `--gap 3` joins a sprite's
# detached parts, and that is usually right — but in Turtles in Time two
# neighbouring frames sit close enough that the dilation welds *them*, so Leo's
# eight-frame walk cut as seven with a double-turtle in the middle. Dropping to
# `--gap 1` splits them cleanly.
#
# It is not a better setting, it is a different trade. At `--gap 1` Michelangelo
# loses his nunchucks: they hang a pixel clear of his hands and become eleven
# little orange splinters with their own frame numbers. He is cut at 3 and the
# others at 1, from sheets drawn by the same artists for the same game.
# --------------------------------------------------------------------------

# Final Fight 3. His idle row and his run row overlap vertically on the sheet,
# so the cutter reads them as one band and interleaves them left to right:
# 16, 18, 20 are the standing frames and 17, 19, 21 the running ones, alternating
# all the way along. Taking 16-23 as a range would have him flickering between
# standing still and sprinting.
GUY = {
    "rest":      ([16, 18, 20], 6, True),
    "walk":      ([22, 24, 27, 29, 31, 34], 10, True),
    "run":       ([17, 19, 21, 23, 25, 28], 14, True),
    # 43-45 are a jumping knee and a flying kick, not a punch — named
    # for what they are after rendering them.
    "jumpKick":  (rng(43, 45), 12, False),
    "kick":      (rng(46, 47), 10, False),
    "arrive":    ([20, 16], 6, False),
    "depart":    ([22, 24, 27, 29, 31, 34], 10, False),
}

# Castlevania: Dracula X. The captions sit above their sprites and only two of
# the five survived the cut, so the boundary between idle and walk is read off
# the sprites themselves: 2-5 stand with the cape moving, 6-11 have his legs
# apart.
RICHTER = {
    "rest":      (rng(2, 5), 6, True),
    "walk":      (rng(6, 11), 10, True),
    "whip":      (rng(26, 29), 12, False),
    "attack":    (rng(26, 29), 12, False),
    "arrive":    (rng(26, 29), 12, False),
    "depart":    (rng(6, 11), 10, False),
}

# Pac-Man 2. The rip is ordered by the game's own pattern tester, which its
# author described as utterly nonsensical, and it is: the walk is at 0-7 and the
# idle is 74 frames later. He also has a back view — 40-47 are Pac-Man from
# behind, faceless and easy to mistake for a pose.
PACMAN = {
    "rest":      ([74, 75], 4, True),
    "walk":      (rng(0, 7), 12, True),
    "cheer":     (rng(76, 79), 8, False),
    "arrive":    (rng(76, 79), 8, False),
    "depart":    (rng(0, 7), 12, False),
}

# Turtles in Time. Four sheets, four different offsets — the same lesson Luigi
# taught, learned again four times over. Their idles all face the viewer, which
# is the beat-'em-up convention, and their walks are all in profile.
LEO = {
    "rest":      (rng(2, 6), 7, True),
    "walk":      (rng(7, 14), 12, True),
    "jump":      ([17], 8, False),
    "attack":    (rng(36, 38), 12, False),
    "roll":      (rng(19, 21), 12, False),
    "arrive":    (rng(19, 21), 12, False),
    "depart":    (rng(7, 14), 12, False),
}

RAPH = {
    "rest":      (rng(3, 8), 7, True),
    "walk":      (rng(9, 16), 12, True),
    "jump":      ([19], 8, False),
    # 31 is him rolled into his shell; 32 is the sai actually out.
    "attack":    ([32], 8, False),
    "arrive":    ([19, 21], 8, False),
    "depart":    (rng(9, 16), 12, False),
}

MIKEY = {
    "rest":      (rng(2, 5), 7, True),
    "walk":      (rng(8, 15), 12, True),
    "swing":     (rng(6, 7), 10, False),
    "attack":    (rng(6, 7), 10, False),
    "flip":      (rng(18, 21), 12, False),
    "arrive":    (rng(18, 21), 12, False),
    "depart":    (rng(8, 15), 12, False),
}

# Donatello's sheet is the odd one of the four: 699x3924 and forty-six rows,
# with his walk sitting at 33-40 rather than up with the idle. His idle is two
# frames, which is all the rip gives him.
DONNIE = {
    "rest":      ([2, 3], 4, True),
    "walk":      (rng(33, 40), 12, True),
    "swing":     ([4], 8, False),
    "attack":    ([4], 8, False),
    "spin":      (rng(14, 16), 12, False),
    "arrive":    (rng(14, 16), 12, False),
    "depart":    (rng(33, 40), 12, False),
}

# Earthworm Jim, in the suit this time. He and the worm at `jim` are the same
# character out of the same game, from two different rips — so the suit keeps
# the name and the worm becomes "Jim (No Suit)", the way the two Axels are told
# apart in the other app.
EWJ = {
    "rest":      (rng(2, 4), 5, True),
    "walk":      (rng(10, 13), 11, True),
    "whip":      ([16], 8, False),
    # 19 is Jim lunging forward, not firing — a real frame, wrong beat.
    "shoot":     ([17, 18, 20], 10, False),
    "attack":    ([17, 18, 20], 10, False),
    "jump":      ([47], 8, False),
    "arrive":    ([17, 18, 20], 10, False),
    "depart":    (rng(10, 13), 11, False),
}


GAMES = [("axel", AXEL), ("blaze", BLAZE), ("maxsor", MAXSOR), ("skate", SKATE),
         ("adam", ADAM), ("axel1", AXEL1), ("blaze1", BLAZE1), ("axel3", AXEL3),
         ("galsia", GALSIA), ("donovan", DONOVAN), ("eagle", EAGLE), ("slum", SLUM),
         ("sonic", SONIC), ("tails", TAILS), ("knuckles", KNUCKLES),
         ("robotnik", ROBOTNIK), ("mecha", MECHA), ("sonic3d", SONIC3D),
         ("spinball", SPINBALL), ("ristar", RISTAR), ("terry", TERRY),
         ("jim", JIM), ("pulseman", PULSEMAN), ("toejam", TOEJAM),
         ("earltje", EARLTJE), ("donald", DONALD), ("moonwalker", MOONWALKER),
         ("sparkster", SPARKSTER), ("robert", ROBERT), ("ryu", RYU),
         ("musashi", MUSASHI), ("gambit", GAMBIT), ("sketch", SKETCH),
         ("raphael", RAPHAEL), ("leonardo", LEONARDO),
         ("michelangelo", MICHELANGELO), ("donatello", DONATELLO)]

# The SNES shelf, kept as its own list so a product manifest can
# pick from it without wading through the Mega Drive one.
SNES = [("mario", MARIO), ("luigi", LUIGI), ("kirby", KIRBY),
        ("samus", SAMUS), ("metroid", METROID), ("megamanx", MEGAMANX),
        ("dk", DK), ("diddy", DIDDY), ("dixie", DIXIE),
        ("squawks", SQUAWKS), ("simon", SIMON), ("jimworm", JIMWORM),
        ("guy", GUY), ("richter", RICHTER), ("pacman", PACMAN),
        ("leo", LEO), ("raph", RAPH), ("mikey", MIKEY), ("donnie", DONNIE),
        ("ewj", EWJ)]

for name, clips, talk in [("peedy", PEEDY, PEEDY_TALK), ("bonzi", BONZI, BONZI_TALK),
                          ("max", MAX, MAX_TALK),
                          ("merlin", MERLIN, MERLIN_TALK),
                          ("rover", ROVER, {}), ("clippy", CLIPPY, {}),
                          ("earl", EARL, {}), ("f1", F1, {}),
                          ("manma", MANMA, {})] + [(n, c, {}) for n, c in GAMES + SNES]:
    # Bonzi is optional; skip anyone whose sprites haven't been imported.
    if not os.path.isdir(f"assets/{name}/rgba") and not os.path.isdir(
            f"app/Resources/characters/{name}/frames"):
        print(f"{name}: no sprites imported, skipping")
        continue
    # Viseme ramps are *measured* off the raw frames, which `assets/` holds and
    # the repository does not ship. A character with mouth patches therefore
    # can't be rebuilt from a clone — only from the source dumps setup.sh
    # unpacks. Skip rather than crash: their animations.json is committed and
    # current, and stopping here took the whole run down with it, including
    # every character that needs no measuring at all.
    if talk and not os.path.isdir(f"assets/{name}/rgba"):
        print(f"{name}: needs the raw dump to measure visemes "
              f"(./setup.sh), keeping the committed catalogue")
        continue
    build(name, clips, talk)
