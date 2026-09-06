import AVFoundation
import AppKit
_ = NSApplication.shared

// Every Arabic line must render at a normal rate. A line the voice can't handle
// shows up as a wildly higher ms/char — that's the signature of it spelling
// something out instead of reading it.
func msPerChar(_ t: String, rate: Float) -> Double {
    let s = AVSpeechSynthesizer(); let u = AVSpeechUtterance(string: t)
    u.voice = AVSpeechSynthesisVoice(identifier: Voice.bestVoice(forLocale: "ar-001") ?? "")
    u.rate = rate
    var n = 0; var sr = 0.0; var done = false
    s.write(u) { b in
        guard let p = b as? AVAudioPCMBuffer else { return }
        if p.frameLength == 0 { done = true; return }
        sr = p.format.sampleRate; n += Int(p.frameLength)
    }
    let dl = Date().addingTimeInterval(25)
    while !done, Date() < dl { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.004)) }
    return sr > 0 ? Double(n) / sr * 1000 / Double(t.count) : -1
}

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

// Every character in the Arabic packs must be Arabic script, punctuation or
// digits — a stray Latin word would be read out letter by letter.
func isPlausibleArabic(_ s: String) -> Bool {
    s.unicodeScalars.allSatisfy { u in
        let v = Int(u.value)
        return (0x0600...0x06FF).contains(v) || (0x0750...0x077F).contains(v)
            || v == 0x20 || (0x21...0x40).contains(v) || v == 0x2026 || v == 0x060C
            || (0x2018...0x201D).contains(v)
            // Guillemets are the ordinary quotation marks in Arabic
            // typography, and Majed reads a quoted word at the same rate as an
            // unquoted one.
            || v == 0x00AB || v == 0x00BB
    }
}

var worst = (0.0, "")
var checked = 0
for p in Personality.all where p.speaks {
    guard let pack = p.pack(.arabic) else { continue }
    let lines = pack.greetings + pack.idle + pack.poked + pack.pokedAgain
        + pack.dropped + pack.leaving + pack.welcomeBack + pack.noticed
        + pack.timeOfDay + pack.byBit.values.flatMap { $0 }
        + pack.jokes.flatMap { [$0.setup, $0.punchline] }
        + pack.facts + pack.riddles.flatMap { [$0.question, $0.answer] }
        + pack.twisters + pack.songs.map(\.intro)
    var slow: [String] = []
    for line in lines {
        let m = msPerChar(line, rate: pack.rate)
        checked += 1
        if m > worst.0 { worst = (m, line) }
        if m > 200 { slow.append(String(format: "%.0f ms/char: %@", m, line)) }
    }
    check("\(pack.name): all \(lines.count) lines read at a normal rate",
          slow.isEmpty, slow.first ?? "")
    let latin = lines.filter { !isPlausibleArabic($0) }
    check("\(pack.name): no stray Latin text in the Arabic pack",
          latin.isEmpty, latin.first ?? "")
    check("\(pack.name): resolves an Arabic voice",
          pack.preferredVoice.map { Voice.canSpeak($0, .arabic) } ?? false)
}
print(String(format: "\n        %d lines checked, slowest %.0f ms/char", checked, worst.0))

// The two must stay distinguishable, since they share the one Arabic voice.
let pa = Personality.peedy.pack(.arabic)!, ba = Personality.bonzi.pack(.arabic)!
check("they share the same voice", pa.preferredVoice == ba.preferredVoice)
check("so pitch has to separate them",
      pa.pitch.rawValue > ba.pitch.rawValue + 0.5,
      "\(pa.pitch.rawValue) vs \(ba.pitch.rawValue)")
check("and pace", ba.rate < pa.rate - 0.05, "\(ba.rate) vs \(pa.rate)")

// Dialect, not textbook Arabic: the giveaway words should be present and the
// stiff MSA equivalents largely absent.
let allPeedy = (pa.greetings + pa.idle + pa.jokes.map(\.setup)
                + pa.jokes.map(\.punchline)).joined(separator: " ")
check("written in dialect", ["وش", "أبغى", "زين", "شوي", "تدري"]
      .allSatisfy { allPeedy.contains($0) })
check("riddles are asked the way people ask them",
      pa.riddles.allSatisfy { $0.question.contains("وش") })

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
