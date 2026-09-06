import AppKit
import AVFoundation

// Does he actually sing — a melody with distinct pitches and the lyric cues
// landing on the right beats — or just talk at one pitch?
_ = NSApplication.shared
let id = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"
let lang = Language(rawValue: CommandLine.arguments.count > 2
                    ? CommandLine.arguments[2] : "en") ?? .english
guard let who = Personality.named(id).pack(lang) else { print("no pack"); exit(0) }
print("— \(who.name) (\(lang.rawValue))")
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}
func pump(_ s: TimeInterval, while active: () -> Bool = { true }) {
    let dl = Date().addingTimeInterval(s)
    while Date() < dl, active() {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.008))
    }
}

print("content:")
check("jokes have both halves",
      who.jokes.allSatisfy { !$0.setup.isEmpty && !$0.punchline.isEmpty })
check("no duplicate jokes",
      Set(who.jokes.map(\.setup)).count == who.jokes.count)
check("no duplicate facts",
      Set(who.facts).count == who.facts.count)
check("riddles all have answers",
      who.riddles.allSatisfy { !$0.answer.isEmpty })
check("everything is short enough for a bubble",
      (who.facts + who.twisters
        + who.jokes.map(\.setup) + who.jokes.map(\.punchline))
          .allSatisfy { $0.count < 130 })
print("        \(who.jokes.count) jokes, \(who.facts.count) facts, "
      + "\(who.riddles.count) riddles, \(who.twisters.count) twisters, "
      + "\(who.songs.count) songs")

print("\nsongs are well formed:")
for song in who.songs {
    let notes = song.phrases.flatMap(\.notes)
    check("\(song.title): has notes", !notes.isEmpty)
    // Uses the shipped transposition, so this fails if a song out-grows it.
    let tonic = Voice.tonic(for: song, speaking: Voice.Pitch.high.rawValue)
    let pitches = notes.map { tonic * Float(pow(2.0, Double($0.step) / 12.0)) }
    check("\(song.title): every note fits the 0.5...2.0 pitch range",
          pitches.allSatisfy { $0 >= 0.5 && $0 <= 2.0 },
          String(format: "%.2f...%.2f", pitches.min() ?? 0, pitches.max() ?? 0))
    check("\(song.title): no note is pinned at the ceiling",
          pitches.filter { $0 > 1.99 }.count <= 1,
          "\(pitches.filter { $0 > 1.99 }.count) at the cap")
    check("\(song.title): is an actual melody, not one note",
          Set(notes.map(\.step)).count >= 3, "\(Set(notes.map(\.step)).count) distinct")
    let beats = notes.reduce(0.0) { $0 + $1.beats }
    check("\(song.title): is a sensible length",
          beats * song.secondsPerBeat > 3 && beats * song.secondsPerBeat < 40,
          String(format: "%.1fs", beats * song.secondsPerBeat))
}

print("\nevery song, rendered:")
for s in who.songs {
    let written = s.phrases.flatMap(\.notes).reduce(0.0) { $0 + $1.beats } * s.secondsPerBeat
    let v = Voice()
    v.volume = 0.03
    var got: TimeInterval = -1
    var over = false
    v.sing(s) { _ in } onStart: { got = $0 } onFinish: { over = true }
    pump(20) { got < 0 }
    check("\(s.title): renders", got > 0)
    // Silence trimming should keep this close to the written score; a big
    // overshoot means padding is stretching the tempo again.
    // Every note is rebuilt at exactly its beat length, so this is no longer
    // approximate: the sung length should equal the score.
    check("\(s.title): sung length matches the score",
          abs(got - written) < 0.05,
          String(format: "%.2fs sung vs %.2fs written", got, written))
    v.stop()
    _ = over
}

print("\nsinging one:")
let voice = Voice()
voice.volume = 0.03
let song = who.songs[min(1, who.songs.count - 1)]           // Twinkle: a melody everyone knows
var duration: TimeInterval = -1
var finished = false
var cues: [Int] = []
var levels: [Float] = []

voice.sing(song) { cues.append($0) } onStart: { duration = $0 } onFinish: { finished = true }
pump(12) { duration < 0 }
check("rendered and started", duration > 0, "\(duration)")
let writtenBeats = song.phrases.flatMap(\.notes).reduce(0.0) { $0 + $1.beats }
check("length matches the score exactly",
      abs(duration - writtenBeats * song.secondsPerBeat) < 0.05,
      String(format: "%.2fs sung vs %.2fs written", duration,
             writtenBeats * song.secondsPerBeat))

print("\nrhythm survives slow syllables:")
for s in who.songs {
    let notes = s.phrases.flatMap(\.notes)
    // Every syllable renders long — the case that used to flatten the rhythm.
    let slow = notes.map { _ in 0.55 }
    let beat = Voice.secondsPerBeat(for: s, noteDurations: slow)
    check("\(s.title): tempo stretches to fit", beat >= s.secondsPerBeat)
    check("\(s.title): every note still fits its beat",
          zip(notes, slow).allSatisfy { $0.beats * beat >= $1 - 1e-9 })
    // The point of the stretch: long notes stay proportionally long.
    if let one = notes.first(where: { $0.beats == 1 }),
       let two = notes.first(where: { $0.beats == 2 }) {
        let ratio = (two.beats * beat) / (one.beats * beat)
        check("\(s.title): a two-beat note is still twice a one-beat note",
              abs(ratio - 2) < 0.001, String(format: "%.3f", ratio))
    }
    check("\(s.title): fast syllables leave the written tempo alone",
          Voice.secondsPerBeat(for: s, noteDurations: notes.map { _ in 0.01 })
              == s.secondsPerBeat)
}

// Bounded: a hang here would wedge the whole suite instead of reporting.
let sampleDeadline = Date().addingTimeInterval(max(duration, 1) + 6)
while !finished, voice.isSpeaking, Date() < sampleDeadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.016))
    levels.append(voice.level)
}
pump(4) { !finished }
check("finished", finished)
check("every lyric line was cued", cues.count == song.phrases.count, "\(cues)")
check("lyrics come in order", cues == Array(0..<song.phrases.count))
check("beak moves through the song",
      (levels.max() ?? 0) > 0.7 && (levels.min() ?? 1) < 0.35,
      "min \(levels.min() ?? -1) max \(levels.max() ?? -1)")

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
