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
check("Max is the slow one",
      Personality.all.allSatisfy { $0.id == "max" || $0.roaming.speed >= Personality.max.roaming.speed },
      "\(Personality.max.roaming.speed)")
check("Skate is the quick one",
      Personality.all.allSatisfy { $0.id == "skate" || $0.roaming.speed <= Personality.skate.roaming.speed })
for p in Personality.all {
    check("\(p.name): walks a sane distance at a sane pace",
          p.roaming.distance.lowerBound > 0
              && p.roaming.distance.upperBound <= 4000
              && (60...400).contains(p.roaming.speed)
              && p.beatRange.lowerBound > 0,
          "\(p.roaming.speed) pt/s, \(p.roaming.distance)")
}

print("\nnobody talks; everybody makes a noise:")
for p in Personality.all {
    guard let store = stores[p.id] else { continue }
    check("\(p.name): the sprite set has no mouth frames to sync",
          store.animations["talk"] == nil)
    guard let bank = SoundBank(set: p.soundSet, bundle: bundle) else {
        check("\(p.name): has a sound bank", false); continue
    }
    check("\(p.name): has a sound bank", true)
    for kind in SoundBank.Kind.allCases {
        check("\(p.name): has \(kind.rawValue) sounds", bank.has(kind))
    }
}

print("\nsparring:")
// Two of them is the whole premise; one character can't square up with anyone.
check("more than one of them ships", Personality.all.count > 1)
let canFight = Personality.all.filter { p in
    guard let store = stores[p.id] else { return false }
    return ["punch", "kick", "jab", "attack", "highKick", "slam", "flip"]
        .contains { store.animation($0) != nil }
}
check("everybody can throw or take a swing", canFight.count == Personality.all.count,
      Set(ids).subtracting(canFight.map(\.id)).joined(separator: ", "))

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
