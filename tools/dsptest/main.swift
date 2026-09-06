import Foundation

// Validate the pitch resynthesis on signals whose answer is known, so a
// failure here is unambiguously the DSP and not the speech synthesiser.
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

let sr = 22050.0

/// A glottal-pulse-like source: a few harmonics, so it has a real waveform
/// shape to find pulses in rather than a bare sine.
func buzz(_ f0: Double, seconds: Double) -> [Float] {
    let n = Int(seconds * sr)
    return (0..<n).map { i in
        let t = Double(i) / sr
        var v = 0.0
        for h in 1...6 { v += sin(2 * .pi * f0 * Double(h) * t) / Double(h) }
        return Float(v * 0.3)
    }
}

/// Estimate F0 by counting how far apart the strongest correlation lag sits.
func measureF0(_ x: [Float], from: Double = 0.25, to: Double = 0.75) -> Double? {
    let lo = Int(Double(x.count) * from), hi = Int(Double(x.count) * to)
    guard hi - lo > 512 else { return nil }
    return Voice.period(of: Array(x[lo..<hi]), sampleRate: sr).map { sr / $0 }
}

print("period detection:")
for f in [90.0, 130.0, 196.0, 300.0] {
    guard let got = Voice.period(of: buzz(f, seconds: 0.4), sampleRate: sr).map({ sr / $0 })
    else { check("finds \(Int(f)) Hz", false); continue }
    check("finds \(Int(f)) Hz", abs(12 * log2(got / f)) < 0.35,
          String(format: "got %.1f Hz", got))
}
check("reports nothing for silence",
      Voice.period(of: [Float](repeating: 0, count: 4000), sampleRate: sr) == nil)
check("reports nothing for noise",
      Voice.period(of: (0..<8000).map { _ in Float.random(in: -0.5...0.5) },
                   sampleRate: sr) == nil)

print("\nimposing a pitch:")
let source = buzz(120, seconds: 0.5)
for target in [98.0, 147.0, 196.0, 262.0, 330.0] {
    let out = Voice.resynth(source, sampleRate: sr, frequency: target, duration: 0.5)
    guard let got = measureF0(out) else { check("\(Int(target)) Hz comes out", false); continue }
    let err = 12 * log2(got / target)
    check(String(format: "120 Hz -> %.0f Hz (got %.0f, %+.2f st)", target, got, err),
          abs(err) < 0.5)
}

print("\nlength is exactly what was asked for:")
for seconds in [0.2, 0.5, 1.2] {
    let out = Voice.resynth(source, sampleRate: sr, frequency: 196, duration: seconds)
    check(String(format: "%.1fs", seconds),
          abs(Double(out.count) / sr - seconds) < 0.005,
          "\(Double(out.count) / sr)")
}

print("\nthe note is steady, not a swoop:")
let steady = Voice.resynth(source, sampleRate: sr, frequency: 220, duration: 0.8)
var readings: [Double] = []
for slice in 0..<6 {
    let a = 0.15 + Double(slice) * 0.11
    if let f = measureF0(steady, from: a, to: a + 0.11) { readings.append(f) }
}
check("measurable throughout", readings.count >= 5, "\(readings.count) readings")
if let lo = readings.min(), let hi = readings.max() {
    check(String(format: "drifts less than a semitone (%.2f st)", 12 * log2(hi / lo)),
          12 * log2(hi / lo) < 1.0)
}

print("\nvowel finding, and holding it on a long note:")
// A quiet buzz of noise (a consonant) then a loud tone (the vowel).
var syllable = (0..<Int(sr * 0.08)).map { _ in Float.random(in: -0.02...0.02) }
syllable += buzz(120, seconds: 0.20)
let found = Voice.vowel(of: syllable, sampleRate: sr)
check("skips the leading consonant",
      Double(found.lowerBound) / sr > 0.05 && Double(found.lowerBound) / sr < 0.12,
      String(format: "starts at %.3fs", Double(found.lowerBound) / sr))
check("covers the vowel",
      Double(found.count) / sr > 0.15, String(format: "%.3fs", Double(found.count) / sr))

// Stretched to three times the length, the consonant must not stretch with it.
let long = Voice.resynth(syllable, sampleRate: sr, frequency: 200, duration: 0.84)
func firstLoud(_ x: [Float]) -> Double {
    let win = Int(sr * 0.01)
    var i = 0
    while i + win <= x.count {
        var e: Float = 0
        for j in i..<(i + win) { e += x[j] * x[j] }
        if e / Float(win) > 0.001 { return Double(i) / sr }
        i += win
    }
    return Double(x.count) / sr
}
let onset = firstLoud(long)
check(String(format: "consonant stays short on a long note (vowel enters at %.2fs)", onset),
      onset < 0.20, "would be ~0.24s if stretched with the rest")
if let f = measureF0(long, from: 0.4, to: 0.9) {
    check(String(format: "held vowel keeps its pitch (%.0f Hz)", f),
          abs(12 * log2(f / 200)) < 0.5)
}

print("\nnot silence, not clipping:")
let loud = Voice.resynth(source, sampleRate: sr, frequency: 196, duration: 0.5)
let peak = loud.map(abs).max() ?? 0
let rms = (loud.reduce(Float(0)) { $0 + $1 * $1 } / Float(loud.count)).squareRoot()
check(String(format: "has signal (rms %.3f)", rms), rms > 0.02)
check(String(format: "does not clip (peak %.2f)", peak), peak <= 1.0)
// Pitching up and down should not change the loudness much.
let up = Voice.resynth(source, sampleRate: sr, frequency: 330, duration: 0.5)
let down = Voice.resynth(source, sampleRate: sr, frequency: 98, duration: 0.5)
func level(_ x: [Float]) -> Float {
    (x.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
}
let ratio = Double(max(level(up), level(down)) / max(min(level(up), level(down)), 1e-6))
check(String(format: "level holds across the range (%.1fx)", ratio), ratio < 3.0)

print("\nedge cases are safe:")
check("empty source", Voice.resynth([], sampleRate: sr, frequency: 196, duration: 0.3).count > 0)
check("zero duration", Voice.resynth(source, sampleRate: sr, frequency: 196, duration: 0).isEmpty)
check("absurd frequency",
      Voice.resynth(source, sampleRate: sr, frequency: 0, duration: 0.3).count > 0)

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
