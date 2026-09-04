import AppKit

// The liveliness rules: energy response, poke habituation, weighted beat
// choice, and no-immediate-repeat picking.
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

print("energy baseline follows whether anyone is there:")
let atDesk = Brain.energyBaseline(userIdleSeconds: 3)
let away = Brain.energyBaseline(userIdleSeconds: 600)
check("winds down when the user is away", away < atDesk, "\(away) vs \(atDesk)")
check("stays in range", (0...1).contains(atDesk) && (0...1).contains(away))
check("a brief pause is not 'away'",
      Brain.energyBaseline(userIdleSeconds: 30) == atDesk)

print("\npoke habituation:")
let sequence = (1...9).map { Brain.reaction(forStreak: $0) }
check("first poke startles him", sequence[0] == .startled)
check("a couple more are playful", sequence[1] == .playful && sequence[2] == .playful)
check("then he tires of it", sequence[4] == .tiring)
check("eventually he stops responding", sequence[7] == .hadEnough)
check("never goes backwards",
      zip(sequence, sequence.dropFirst()).allSatisfy { order($0) <= order($1) })
func order(_ r: Brain.Reaction) -> Int {
    switch r {
    case .startled: return 0
    case .playful: return 1
    case .tiring: return 2
    case .hadEnough: return 3
    }
}

print("\nweighted beat choice:")
check("zero-weight options never come up",
      (0..<200).allSatisfy {
          Brain.weightedPick([("a", 1.0), ("never", 0.0)],
                             roll: Double($0) / 200) != "never"
      })
check("a lone option always wins",
      Brain.weightedPick([("only", 1.0)], roll: 0.99) == "only")
check("out-of-range rolls are safe",
      Brain.weightedPick([("a", 1.0), ("b", 1.0)], roll: -3) != nil
          && Brain.weightedPick([("a", 1.0), ("b", 1.0)], roll: 4) != nil)
check("all-zero weights still return something",
      Brain.weightedPick([("a", 0.0), ("b", 0.0)], roll: 0.5) != nil)
// Proportions should roughly track the weights.
var hits: [String: Int] = [:]
for i in 0..<3000 {
    let v = Brain.weightedPick([("quiet", 3.0), ("loud", 1.0)],
                               roll: Double(i) / 3000)!
    hits[v, default: 0] += 1
}
let ratio = Double(hits["quiet"] ?? 0) / Double(max(hits["loud"] ?? 1, 1))
check("3:1 weights land near 3:1", ratio > 2.6 && ratio < 3.4, String(format: "%.2f", ratio))

print("\nenergy changes the mix:")
func mix(energy: Double) -> [String: Int] {
    var out: [String: Int] = [:]
    let settled = 1 - energy
    for i in 0..<2000 {
        let v = Brain.weightedPick([("settle", 0.10 + 0.45 * settled),
                                    ("wander", 0.08 + 0.34 * energy),
                                    ("bit", 0.26),
                                    ("flourish", 0.10 + 0.30 * energy)],
                                   roll: Double(i) / 2000)!
        out[v, default: 0] += 1
    }
    return out
}
let low = mix(energy: 0.12), high = mix(energy: 0.95)
check("low energy settles more", low["settle"]! > high["settle"]!,
      "\(low["settle"]!) vs \(high["settle"]!)")
check("high energy wanders more", high["wander"]! > low["wander"]!,
      "\(high["wander"]!) vs \(low["wander"]!)")
check("bits happen either way", low["bit"]! > 100 && high["bit"]! > 100)

print("\nnoticing the cursor:")
let bird = NSRect(x: 1000, y: 100, width: 184, height: 148)
let onHim = NSPoint(x: bird.midX, y: bird.midY)
let faraway = NSPoint(x: 200, y: 700)

let arriving = Brain.noticesCursor(at: onHim, frame: bird, wasNear: false, speed: 400)
check("notices a cursor arriving", arriving.notice && arriving.near)

let staying = Brain.noticesCursor(at: onHim, frame: bird, wasNear: true, speed: 400)
check("does not re-notice one already there", !staying.notice && staying.near)

// The bug this replaced: a parked cursor greeted on a timer, forever.
let parked = Brain.noticesCursor(at: onHim, frame: bird, wasNear: false, speed: 0)
check("ignores a motionless cursor", !parked.notice)

let gone = Brain.noticesCursor(at: faraway, frame: bird, wasNear: true, speed: 900)
check("registers it leaving", !gone.notice && !gone.near)

// Leaving and coming back should notice again.
var wasNear = false
var notices = 0
for point in [faraway, onHim, onHim, onHim, faraway, faraway, onHim] {
    let r = Brain.noticesCursor(at: point, frame: bird, wasNear: wasNear, speed: 500)
    wasNear = r.near
    if r.notice { notices += 1 }
}
check("notices once per approach, not per frame", notices == 2, "\(notices)")

print("\nliveliness scales pacing without flattening it:")
// The point of a multiplier rather than a fixed interval: Max stays slower
// than Skate at every setting.
for level in Liveliness.allCases {
    let slow = Personality.max.beatRange.lowerBound * level.pace
    let quick = Personality.skate.beatRange.lowerBound * level.pace
    check("\(level.title): Max is still slower than Skate", slow > quick,
          String(format: "%.1f vs %.1f", slow, quick))
}
check("calm is slower than restless", Liveliness.calm.pace > Liveliness.restless.pace)

print("\nno immediate repeats:")
var picks = RecentPicks(limit: 4)
let pool = ["a", "b", "c", "d", "e", "f"]
var chosen: [String] = []
for _ in 0..<300 { chosen.append(picks.pick(from: pool)) }
check("never repeats back to back",
      zip(chosen, chosen.dropFirst()).allSatisfy { $0 != $1 })
check("uses the whole pool", Set(chosen).count == pool.count)
// The real failure this guards: a tiny pool going round in a rut.
var tiny = RecentPicks(limit: 8)
let two = ["x", "y"]
let alt = (0..<40).map { _ in tiny.pick(from: two) }
check("copes when the pool is smaller than the memory",
      zip(alt, alt.dropFirst()).allSatisfy { $0 != $1 } && Set(alt).count == 2)
var single = RecentPicks(limit: 4)
check("a one-item pool still returns it", single.pick(from: ["only"]) == "only")
check("an empty pool is safe", single.pick(from: []) == "")

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
