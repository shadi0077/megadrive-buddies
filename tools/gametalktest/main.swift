import Foundation

// What the game characters say: no repeats, nothing too long for a box, every
// named speaker exists, and nothing from after 1997.
//
// Named for the file it checks, GameTalk — tools/talktest next door is about
// lip-sync registration, which is a different sort of talking entirely.
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

let everything = GameTalk.facts + GameTalk.idle
    + GameTalk.jokes.flatMap { [$0.setup, $0.punchline] }
    + GameTalk.exchanges.flatMap { $0.map(\.text) }
    + GameTalk.personal.values.flatMap { $0 }

print("there is enough to say:")
// Floors, not targets. They exist so the repertoire can't quietly shrink back
// to the size where a character repeats itself inside a morning.
check("\(GameTalk.facts.count) facts", GameTalk.facts.count >= 60)
check("\(GameTalk.jokes.count) jokes", GameTalk.jokes.count >= 85)
check("\(GameTalk.idle.count) passing remarks", GameTalk.idle.count >= 70)
// These two scale with the cast, because they can be split. A repository
// exported for one product carries only the exchanges its own characters are
// named in and only their personal lines, so a corpus-wide floor would fail an
// app that is complete for what it ships. Facts, jokes and remarks above are
// shared by everybody and never subset, so their floors stay absolute.
//
// 46 of the exchanges name nobody and are usable by any pair, which is the
// floor here; the real guarantee — that every pair has something to draw on —
// is checked per pair further down.
check("\(GameTalk.exchanges.count) exchanges", GameTalk.exchanges.count >= 40)
check("\(GameTalk.personal.values.flatMap { $0 }.count) lines belonging to somebody",
      GameTalk.personal.values.flatMap { $0 }.count >= 3 * Personality.all.count,
      "need \(3 * Personality.all.count) for \(Personality.all.count) characters")

print("\nnothing repeats:")
check("no two facts are the same", Set(GameTalk.facts).count == GameTalk.facts.count)
check("no two setups are the same",
      Set(GameTalk.jokes.map(\.setup)).count == GameTalk.jokes.count)
check("no two punchlines are the same",
      Set(GameTalk.jokes.map(\.punchline)).count == GameTalk.jokes.count)
check("no two exchanges open the same way",
      Set(GameTalk.exchanges.map { $0[0].text }).count == GameTalk.exchanges.count)
let personalLines = GameTalk.personal.values.flatMap { $0 }
check("no personal line is also in the shared pool",
      Set(personalLines).isDisjoint(with: Set(GameTalk.idle)))

// The whole conceit is that these are 16-bit characters who stopped paying
// attention in 1997. A stray later year gives the game away, and it is the
// sort of thing that creeps in one fact at a time.
print("\nnothing after 1997:")
var offenders: [String] = []
for line in everything {
    for match in line.split(whereSeparator: { !$0.isNumber }) where match.count == 4 {
        if let year = Int(match), (1900...2100).contains(year), year > 1997 {
            offenders.append("\(year): \(line.prefix(50))…")
        }
    }
}
check("no line mentions a year after 1997", offenders.isEmpty,
      offenders.joined(separator: " / "))

print("\nevery line fits in a bubble:")
check("nothing runs past 190 characters",
      everything.allSatisfy { $0.count <= 190 },
      everything.first { $0.count > 190 } ?? "")
check("nothing is blank", everything.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })

print("\nexchanges are exchanges:")
let known = Set(Personality.everyone.map(\.id))
var unknown: [String] = []
for exchange in GameTalk.exchanges {
    for line in exchange {
        if let who = line.who, !known.contains(who) { unknown.append(who) }
    }
}
check("no exchange names a character who doesn't exist", unknown.isEmpty,
      unknown.joined(separator: ", "))
check("every exchange has at least two lines",
      GameTalk.exchanges.allSatisfy { $0.count >= 2 })
check("every exchange that names anyone names at least two",
      GameTalk.exchanges.allSatisfy { lines in
          let named = Set(lines.compactMap(\.who))
          return named.isEmpty || named.count >= 2
      })
check("personal lines only name characters who exist",
      Set(GameTalk.personal.keys).isSubset(of: known),
      Set(GameTalk.personal.keys).subtracting(known).joined(separator: ", "))

print("\neverybody has something of their own to say:")
// Shared remarks are about games; personal lines are about being *that*
// character, and a character with none is a stranger reciting trivia.
var voiceless: [String] = []
for p in Personality.all where (GameTalk.personal[p.id] ?? []).count < 3 {
    voiceless.append("\(p.id)(\((GameTalk.personal[p.id] ?? []).count))")
}
check("every character in the cast has at least three lines of its own",
      voiceless.isEmpty, voiceless.joined(separator: ", "))

// How long before a character starts repeating itself: the pool it draws on
// when it simply has something to say.
let smallest = Personality.all.map { GameTalk.smallTalk(for: $0.id).count }.min() ?? 0
check("the thinnest character still has \(smallest) things to say", smallest >= 70)

print("\nany two characters can hold a conversation:")
// If a pair has nothing to say, the Cast finds no exchange and the two of
// them stand there — so the unattributed pool has to carry every pair.
let ids = Personality.all.map(\.id)
var mute: [String] = []
for a in ids {
    for b in ids where a < b {
        if GameTalk.exchanges(for: (a, b)).count < 5 { mute.append("\(a)+\(b)") }
    }
}
check("every pair has at least five exchanges to draw on", mute.isEmpty,
      mute.prefix(4).joined(separator: ", "))
// And the pairs written for each other really are extra, not a replacement.
// Only where both are shipped: a repository exported for another product keeps
// the generic exchanges and none of the ones naming these two, so the
// comparison would be between two zeroes.
if Set(ids).isSuperset(of: ["sonic", "knuckles", "earltje"]) {
    check("Sonic and Knuckles have more to say to each other than to a stranger",
          GameTalk.exchanges(for: ("sonic", "knuckles")).count
              > GameTalk.exchanges(for: ("sonic", "earltje")).count)
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
