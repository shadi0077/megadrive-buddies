"""Curate a sound set into the app bundle.

Usage: sounds.py <set-name> <source-dir>

Neither rip says what its sounds are, so both are grouped by inference — but
by different evidence, because the rips are different.

The Streets of Rage rip names voice clips V00..V52 and effects 00..49. Nobody
wrote down which grunt is which, so the grouping is by that convention plus
duration: short voice clips are exertion, short effects are impacts, longer
voice clips are shouts.

The Sonic rips are numbered by sound-test index and nothing else —
the ripper says so in his readme, and deliberately: "I did not name any of the
sound files by concept". So those are grouped by measuring the audio. A short
burst with no pitch to it is an impact; a sweep that rises is effort — a jump,
a spring, a spin-dash winding up; the bright tonal ones left over are shouts.
Ring collection lands in "shout", which is exactly where you want it.

Ristar's rip is his voice and only his voice, so measuring it is pointless:
every clip is the same kind of noise. Those go by length, the way the Streets
of Rage voice clips do.

It is an inference every way, not a transcription. What makes it safe is that
the three kinds are coarse and a wrong guess is merely a different noise.

Sounds are converted to mono at 22.05 kHz on the way in. The rips are 44.1 kHz
stereo, which for three sets is sixteen megabytes of a nineteen-megabyte app,
and none of it is stereo in any meaningful sense — the Mega Drive's FM chip
barely reaches 11 kHz to begin with.
"""
from pathlib import Path
import array, json, shutil, subprocess, sys, wave

name, src = sys.argv[1], Path(sys.argv[2])
out = Path(f"app/Resources/characters/{name}/sounds")
if out.is_dir():
    shutil.rmtree(out)
out.mkdir(parents=True, exist_ok=True)


def measure(p):
    """Duration, level, rough pitch, and whether that pitch rises or falls."""
    try:
        with wave.open(str(p)) as w:
            n, ch, width, rate = (w.getnframes(), w.getnchannels(),
                                  w.getsampwidth(), w.getframerate())
            if width != 2 or n == 0:
                return None
            raw = w.readframes(n)
    except Exception:
        return None
    x = array.array("h")
    x.frombytes(raw)
    if ch == 2:
        x = x[0::2]
    if not len(x):
        return None
    # These rips carry a DC offset on some sounds; without removing it a
    # perfectly ordinary sound reads as having no zero crossings at all.
    mid = sum(x[::11]) / len(x[::11])
    peak = max(abs(v - mid) for v in x[::3]) / 32768

    def pitch(seg):
        if len(seg) < 64:
            return 0.0
        crossings = sum(1 for a, b in zip(seg, seg[1:])
                        if (a >= mid) != (b >= mid))
        return crossings / len(seg) * rate / 2

    third = max(64, len(x) // 3)
    return dict(dur=len(x) / rate, peak=peak, hz=pitch(x),
                slope=pitch(x[-third:]) - pitch(x[:third]))


groups = {"effort": [], "impact": [], "shout": []}
named = any(p.stem.upper().startswith("V") for p in src.glob("*.wav"))
voice_rip = "voice" in str(src).lower() or all(
    "vc" in p.stem.lower() for p in src.rglob("*.wav"))

for p in sorted(src.rglob("*.wav")):
    m = measure(p)
    if m is None or m["peak"] < 0.05:
        continue
    if m["dur"] < 0.06 or m["dur"] > 2.2:
        continue                      # clicks, and jingles that outstay a beat
    if voice_rip:
        groups["effort" if m["dur"] <= 0.8 else "shout"].append(p)
    elif named:
        voice = p.stem.upper().startswith("V")
        if voice and m["dur"] <= 0.9:
            groups["effort"].append(p)
        elif voice:
            groups["shout"].append(p)
        elif m["dur"] <= 0.7:
            groups["impact"].append(p)
    else:
        if m["hz"] < 900 or (m["slope"] < -600 and m["dur"] <= 0.6):
            groups["impact"].append(p)      # thuds, bumps, falling stings
        elif m["slope"] > 300:
            groups["effort"].append(p)      # jumps, springs, spin-dashes
        else:
            groups["shout"].append(p)       # rings, chimes, the bright ones

# A handful from each is plenty; too many and nothing feels characteristic.
manifest = {}
for group, paths in groups.items():
    manifest[group] = []
    for i, p in enumerate(paths[:14]):
        target = f"{group}{i:02d}.wav"
        done = subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@22050",
                               "-c", "1", str(p), str(out / target)],
                              capture_output=True)
        if done.returncode != 0:            # no afconvert: ship what we have
            shutil.copy(p, out / target)
        manifest[group].append(target)

manifest = {k: v for k, v in manifest.items() if v}
json.dump(manifest, open(f"app/Resources/characters/{name}/sounds.json", "w"), indent=1)
total = sum(f.stat().st_size for f in out.iterdir())
print(f"{name}: " + ", ".join(f"{len(v)} {k}" for k, v in manifest.items())
      + f"  ({total/1024:.0f} KB)")
