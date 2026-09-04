import AppKit

// The roster: everybody loads, every clip a personality names exists, and
// everybody has a noise to make. Runs against the built app bundle, so it
// checks what actually ships rather than what is in the source tree.
_ = NSApplication.shared
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

let bundle = Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"]
                    ?? "build/MegaDrive Buddies.app")!
print("\(Product.current.name): \(Personality.all.count) characters\n")

print("everyone in the manifest loads:")
check("the manifest and the roster agree",
      Personality.all.map(\.id) == Product.current.cast,
      "\(Personality.all.map(\.id)) vs \(Product.current.cast)")
var stores: [String: SpriteStore] = [:]
for p in Personality.all {
    guard let store = SpriteStore(character: p.id, bundle: bundle) else {
        check("\(p.name) loads", false); continue
    }
    stores[p.id] = store
    check("\(p.name) loads (\(store.animations.count) clips, canvas "
          + "\(Int(store.canvas.width))x\(Int(store.canvas.height)))", true)
}

print("\nevery clip a personality names actually exists:")
for p in Personality.all {
    guard let store = stores[p.id] else { continue }
    var missing: [String] = []
    for name in p.flourishes where store.animation(name) == nil { missing.append(name) }
    for bit in p.bits {
        for name in [bit.intro, bit.loop, bit.outro].compactMap({ $0 })
        where store.animation(name) == nil { missing.append(name) }
    }
    // Whatever else they lack, they must be able to stand, arrive, leave and
    // move: those four are named directly rather than through move().
    for name in ["rest", "arrive", "depart", p.walk]
    where store.animation(name) == nil { missing.append(name) }
    check("\(p.name): no dangling clip names", missing.isEmpty, missing.joined(separator: ", "))
    check("\(p.name): has something to throw",
          p.flourishes.contains { store.animation($0) != nil })
}

print("\nthey are told apart by how they move:")
let ids = Personality.all.map(\.id)
check("ids are unique", Set(ids).count == ids.count)
check("names are unique", Set(Personality.all.map(\.name)).count == ids.count)
check("both Axels are distinguishable",
      Personality.axel.name != Personality.axel1.name,
      "\(Personality.axel.name) / \(Personality.axel1.name)")
check("Sonic is the fastest thing here",
      Personality.all.allSatisfy { $0.id == "sonic" || $0.roaming.speed <= Personality.sonic.roaming.speed },
      "\(Personality.sonic.roaming.speed)")
// Pace is characterisation, so the pairs that are *about* pace have to hold:
// a lumbering Max against a teenager on rollerblades, and Earl, whose entire
// character is that he does not hurry.
check("Max is slower than Skate",
      Personality.max.roaming.speed < Personality.skate.roaming.speed)
check("Earl does not hurry",
      Personality.earl.roaming.speed < Personality.toejam.roaming.speed
          && Personality.earl.beatRange.lowerBound > Personality.toejam.beatRange.lowerBound)
// The point of per-character roaming: the spread has to be wide enough to
// read as different characters rather than one speed with noise on it.
let paces = Personality.all.map(\.roaming.speed)
check("the roster spans a real range of paces",
      (paces.max() ?? 0) > (paces.min() ?? 0) * 3,
      "\(paces.min() ?? 0)...\(paces.max() ?? 0)")
for p in Personality.all {
    check("\(p.name): walks a sane distance at a sane pace",
          p.roaming.distance.lowerBound > 0
              && p.roaming.distance.upperBound <= 4000
              && (60...500).contains(p.roaming.speed)
              && p.beatRange.lowerBound > 0,
          "\(p.roaming.speed) pt/s, \(p.roaming.distance)")
}

print("\nnobody talks; everybody makes a noise:")
for p in Personality.all {
    guard let store = stores[p.id] else { continue }
    check("\(p.name): the sprite set has no mouth frames to sync",
          store.animations["talk"] == nil)
    // Only the characters whose game we have a sound rip from make a noise.
    // The rest are silent by design, which the app has to cope with.
    guard let set = p.soundSet else {
        check("\(p.name): silent, and says so", true); continue
    }
    guard let bank = SoundBank(set: set, bundle: bundle) else {
        check("\(p.name): has a sound bank", false); continue
    }
    let kinds = SoundBank.Kind.allCases.filter { bank.has($0) }
    check("\(p.name): has a sound bank (\(kinds.map(\.rawValue).joined(separator: ", ")))",
          !kinds.isEmpty)
    // A rip needn't cover all three kinds — Ristar's is his voice and nothing
    // else — but every kind must still produce a noise, or a character goes
    // quiet at exactly the moment one is called for.
    for kind in SoundBank.Kind.allCases {
        check("\(p.name): \(kind.rawValue) finds a sound", bank.play(kind))
    }
    bank.stop()
}

print("\nsquaring up:")
// Two of them is the whole premise; one character can't square up with anyone.
check("more than one of them ships", Personality.all.count > 1)
// Half this cast came out of a beat-'em-up and half out of a platformer, so
// not everybody has a punch. What everybody must have is *something* to do
// when the other one swings, or an exchange is one character performing to a
// statue: move() falls back to a character's own flourishes, so those have to
// exist and have to be clips the sprite set really has.
for p in Personality.all {
    guard let store = stores[p.id] else { continue }
    let usable = p.flourishes.filter { store.animation($0) != nil }
    check("\(p.name): has something to do when squared up", !usable.isEmpty)
}
let fighters = Personality.all.filter { p in
    guard let store = stores[p.id] else { return false }
    return ["punch", "kick", "jab", "attack", "highKick", "slam"]
        .contains { store.animation($0) != nil }
}
check("some of them can actually throw a punch", fighters.count >= 8,
      "\(fighters.count)")

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
