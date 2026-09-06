import AVFoundation
import AppKit

// What does the current singing actually produce? Render each note the way
// Voice.sing does and measure it: does the pitch track the written melody, is
// each note a steady tone, and do the notes join up?
_ = NSApplication.shared

let id = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"
let who = Personality.named(id)
let song = who.songs.first(where: { $0.title.contains("Twinkle") }) ?? who.songs[0]

func render(_ text: String, pitch: Float, rate: Float) -> ([Float], Double) {
    let synth = AVSpeechSynthesizer()
    let u = AVSpeechUtterance(string: text)
    u.voice = AVSpeechSynthesisVoice(identifier: who.preferredVoice)
    u.rate = rate
    u.pitchMultiplier = min(max(pitch, 0.5), 2.0)
    var all: [Float] = []; var sr: Double = 0; var done = false
    synth.write(u) { buf in
        guard let pcm = buf as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { done = true; return }
        sr = pcm.format.sampleRate
        if let ch = pcm.floatChannelData {
            all.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(pcm.frameLength)))
        }
    }
    let dl = Date().addingTimeInterval(5)
    while !done, Date() < dl { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005)) }
    return (all, sr)
}

/// How strongly a signal repeats at exactly `period` samples.
///
/// A direct test of "is this note at the pitch we asked for", which sidesteps
/// pitch *detection* entirely — estimators octave-double on syllables with a
/// weak fundamental, and that showed up as phantom errors of exactly +12.00
/// semitones on notes that were in fact correct.
func periodicity(_ x: [Float], lag: Int) -> Double {
    guard lag > 1, x.count > lag * 3 else { return 0 }
    var acc = 0.0, ea = 0.0, eb = 0.0
    for j in 0..<(x.count - lag) {
        acc += Double(x[j]) * Double(x[j + lag])
        ea += Double(x[j]) * Double(x[j])
        eb += Double(x[j + lag]) * Double(x[j + lag])
    }
    let denom = (ea * eb).squareRoot()
    return denom > 0 ? acc / denom : 0
}

/// F0 per window, for reporting drift only.
func contour(_ x: [Float], _ sr: Double) -> [Double] {
    let win = Int(sr * 0.08)
    guard x.count > win else { return [] }
    var out: [Double] = []
    var i = 0
    while i + win <= x.count {
        if let p = Voice.period(of: Array(x[i..<(i + win)]), sampleRate: sr) { out.append(sr / p) }
        i += win / 2
    }
    return out
}

func semitones(_ a: Double, _ b: Double) -> Double { 12 * log2(a / b) }

let root = song.root ?? who.singingRoot
let notes = song.phrases.flatMap(\.notes)
print("\(who.name) — \"\(song.title)\"   sung root \(Int(root)) Hz\n")
// Measure this voice's natural pitch the same way the app does.
var natural = 116.0
do {
    let (probe, rate) = render("we all know how the low winds roll along", pitch: 1, rate: 0.5)
    let win = Int(rate * 0.08)
    var found: [Double] = []
    var i = 0
    while i + win <= probe.count {
        if let p = Voice.period(of: Array(probe[i..<(i + win)]), sampleRate: rate) {
            found.append(rate / p)
        }
        i += win / 2
    }
    if !found.isEmpty { found.sort(); natural = found[found.count / 2] }
}
print(String(format: "voice's natural pitch: %.0f Hz\n", natural))
var minMatch = 1.0, weak = 0, offOctave = 0
print("note   want    target    measured   error     match    octave-up")

var all: [Float] = []
var sr: Double = 22050
for note in notes {
    let target = root * pow(2.0, Double(note.step) / 12.0)
    let coarse = min(max(target / natural, 0.5), 2.0)
    let (raw, rate) = render(note.text, pitch: Float(coarse), rate: 0.5)
    sr = rate
    // Same trim + resynth the app does.
    var lo = 0, hi = raw.count - 1
    while lo < raw.count, abs(raw[lo]) < 0.004 { lo += 1 }
    while hi > lo, abs(raw[hi]) < 0.004 { hi -= 1 }
    let trimmed = lo < hi ? Array(raw[lo...hi]) : raw
    let seconds = note.beats * song.secondsPerBeat
    let srcF0: Double? = natural * coarse
    let x = Voice.resynth(trimmed, sampleRate: rate, frequency: target,
                          duration: seconds, sourceF0: natural * coarse)
    all.append(contentsOf: x)

    // Correlate against the exact period we asked for. Note that a signal
    // periodic at T is trivially also periodic at 2T, so a strong reading an
    // octave *down* proves nothing — only a stronger reading an octave *up*
    // would mean the note actually landed in the wrong place.
    let lag = Int((rate / target).rounded())
    let atTarget = periodicity(x, lag: lag)
    let atOctaveUp = periodicity(x, lag: max(2, lag / 2))

    // Steadiness, measured the same reliable way: does it stay locked to that
    // period across the whole note, rather than swooping through it?
    let wrongOctave = atOctaveUp > atTarget
    if wrongOctave { offOctave += 1 }
    if atTarget < 0.5 { weak += 1 }
    minMatch = min(minMatch, atTarget)
    let f0 = contour(x, rate).sorted()
    let measured = f0.isEmpty ? 0 : f0[f0.count / 2]
    let err = measured > 0 ? semitones(measured, target) : 0
    print(String(format: "%-6@ +%2d st  %6.1f Hz  %6.1f Hz  %+5.2f st   match %.2f   octave-up %+.2f %@",
                 note.text as NSString, note.step, target, measured, err, atTarget, atOctaveUp,
                 wrongOctave ? "  <-- wrong octave" : (atTarget < 0.5 ? "  <-- weak" : "")))
}

print(String(format: "\nweakest match to its own period: %.2f   wrong octave: %d   weak: %d",
             minMatch, offOctave, weak))
print(String(format: "total: %.2fs, silence %.0f%%",
             Double(all.count) / sr,
             Double(all.filter { abs($0) < 0.01 }.count) / Double(max(all.count, 1)) * 100))
