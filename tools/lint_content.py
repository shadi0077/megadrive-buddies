"""Checks the written content that don't need the sprites, so CI can run them.

Verifies the two characters stay distinct and that nothing in the dialogue
refers to a character or an animation that no longer exists.
"""
import json
import re
import sys
from pathlib import Path

SRC = Path("app/Sources")
failures = []


def check(label, ok, detail=""):
    print(f"  {'ok  ' if ok else 'FAIL'}  {label}{'  ' + detail if detail and not ok else ''}")
    if not ok:
        failures.append(label)


def swift(name):
    return (SRC / name).read_text()


# Animation names the catalogue declares, per character.
catalog = Path("tools/catalog.py").read_text()
cast = json.load(open("products/desktop-buddies.json"))["cast"]


def clip_names(block):
    if f"{block} = {{" not in catalog:
        return set()
    section = catalog.split(f"{block} = {{", 1)[1].split("\n}", 1)[0]
    names = set(re.findall(r'^\s*"([A-Za-z0-9]+)":', section, re.M))
    return names


# Reversals add a clip under a new name, so they count as declared.
reversals = {}
block = catalog.split("REVERSALS = {", 1)[1].split("\n}", 1)[0]
for who, body in re.findall(r'"(\w+)":\s*\[(.*?)\]', block, re.S):
    reversals[who] = re.findall(r'\("(\w+)", "(\w+)"\)', body)

clips = {}
for who in cast:
    names = clip_names(who.upper())
    for new, src in reversals.get(who, []):
        if src in names:
            names.add(new)
    clips[who] = names
    check(f"catalogue declares clips for {who}", len(names) >= 5, str(len(names)))

# Every gesture used in dialogue must exist for whoever performs it.
banter = swift("Banter.swift")
lines = re.findall(r'BanterLine\("(\w+)",\s*"((?:[^"\\]|\\.)*)"(?:,\s*"(\w+)")?\)', banter)
check("dialogue has lines", len(lines) > 30, str(len(lines)))
# "A" and "B" are the placeholders in the any-pair exchanges, substituted for
# whoever is on screen. They carry no gestures, precisely because a clip one
# character has is not one the other necessarily does.
placeholders = {"A", "B"}
bad = [f"{who}:{move}" for who, _, move in lines
       if move and move not in clips.get(who, set())]
check("every dialogue gesture exists for its speaker", not bad, ", ".join(bad))
check("dialogue only names known characters",
      all(who in clips or who in placeholders for who, _, _ in lines))
check("any-pair dialogue carries no gestures",
      not [m for who, _, m in lines if who in placeholders and m])

# The personalities must not quietly converge into one character.
sources = {}
for who in cast:
    for name in [f"{who.capitalize()}Personality.swift", f"{who.upper()}Personality.swift",
                 f"{who}Personality.swift"]:
        if (SRC / name).exists():
            sources[who] = swift(name)
            break
check("every character has a personality file", len(sources) == len(cast),
      ", ".join(sorted(set(cast) - set(sources))))


def pool(src, field):
    if f"{field}: [" not in src:
        return set()
    body = src.split(f"{field}: [", 1)[1]
    depth, out = 1, []
    for i, ch in enumerate(body):
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                out = body[:i]
                break
    return set(re.findall(r'"((?:[^"\\]|\\.)*)"', out))


overlaps = []
for field in ["greetings", "idle", "poked", "dropped", "leaving"]:
    for i, a in enumerate(sorted(sources)):
        for b in sorted(sources)[i + 1:]:
            shared = pool(sources[a], field) & pool(sources[b], field)
            if shared:
                overlaps.append(f"{a}/{b} {field}: {list(shared)[0]}")
check("no two characters share a line", not overlaps, "; ".join(overlaps[:3]))

setups = {who: set(re.findall(r'setup: "((?:[^"\\]|\\.)*)"', src))
          for who, src in sources.items()}
shared_jokes = [f"{a}/{b}" for i, a in enumerate(sorted(setups))
                for b in sorted(setups)[i + 1:] if setups[a] & setups[b]]
check("no two characters share a joke", not shared_jokes, ", ".join(shared_jokes[:3]))

# They must be told apart by ear as well as by eye.
roots = {who: re.search(r"singingRoot: (\d+)", src).group(1) for who, src in sources.items()}
check("they all sing in different registers", len(set(roots.values())) == len(roots),
      str(sorted(roots.items(), key=lambda kv: kv[1])))
rates = {who: float(re.search(r"rate: ([\d.]+)", src).group(1)) for who, src in sources.items()}
# The original pair are built as opposites, so that one holds whoever else
# joins; the cast as a whole only has to not be uniform.
check("Bonzi speaks more slowly than Peedy", rates["bonzi"] < rates["peedy"],
      f'{rates["bonzi"]} vs {rates["peedy"]}')
check("the cast varies in pace", len(set(rates.values())) >= max(3, len(rates) - 2),
      str(sorted(rates.values())))

# Every menu string the app asks for must exist in every language, or the menu
# comes out half translated — which is worse than not translating it at all.
lang_src = swift("Language.swift")
arabic_keys = set(re.findall(r'^\s*"([^"]+)":', lang_src, re.M))
used = set()
for name in ["AppDelegate.swift"]:
    src = swift(name)
    used |= set(re.findall(r'\bt\("((?:[^"\\]|\\.)*)"\)', src))
# Menu levels are localised through the same table.
for enum_field in re.findall(r'case \.\w+: return "([^"]+)"', swift("Brain.swift")):
    used.add(enum_field)
for enum_field in re.findall(r'case \.\w+: return "([^"]+)"', swift("Voice.swift")):
    used.add(enum_field)
for enum_field in re.findall(r'case \.\w+: return "([^"]+)"', swift("AppDelegate.swift")):
    used.add(enum_field)
missing = sorted(k for k in used if k not in arabic_keys)
check("every menu string has an Arabic translation", not missing,
      ", ".join(missing[:6]))
print(f"        {len(used)} strings used, {len(arabic_keys)} translated")

# Every character must be able to speak both languages, or the cast is
# half-translated — which is worse than not translating it at all.
for who in cast:
    name = None
    for candidate in [f"{who.capitalize()}Arabic.swift", f"{who.upper()}Arabic.swift"]:
        if (SRC / candidate).exists():
            name = candidate
            break
    if name is None:
        check(f"{who} has an Arabic pack", False)
        continue
    ar = swift(name)
    check(f"{who} has an Arabic pack", "SpeechPack(" in ar)
    arabic_chars = sum(1 for ch in ar if "\u0600" <= ch <= "\u06ff")
    check(f"{who}'s Arabic pack is written in Arabic", arabic_chars > 1200,
          f"{arabic_chars} Arabic characters")

print("\nall checks passed" if not failures else f"\n{len(failures)} FAILED")
sys.exit(0 if not failures else 1)
