import AVFoundation
import AppKit

// Compare envelope shaping options by the spread of visemes they produce.
// A good curve uses the whole ramp rather than slamming between shut and wide.
let lines = ["Is it cracker o'clock yet?",
             "I'm not procrastinating, I'm perching.",
             "Squawk.",
             "Don't mind me, just supervising the desktop."]

func render(_ text: String) -> (data: [Float], sr: Double)? {
    let synth = AVSpeechSynthesizer()
    let u = AVSpeechUtterance(string: text)
    u.voice = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.Fred")
    u.rate = 0.52
    var all: [Float] = []; var sr: Double = 0; var done = false
    synth.write(u) { buf in
        guard let pcm = buf as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { done = true; return }
        sr = pcm.format.sampleRate
        if let ch = pcm.floatChannelData {
            all.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(pcm.frameLength)))
        }
    }
    let dl = Date().addingTimeInterval(6)
    while !done, Date() < dl { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
    return sr > 0 ? (all, sr) : nil
}

func rms(_ data: [Float], _ sr: Double) -> [Float] {
    let w = max(1, Int(sr / 60)); var out: [Float] = []; var i = 0
    while i < data.count {
        let e = min(i + w, data.count)
        var s: Float = 0; for j in i..<e { s += data[j] * data[j] }
        out.append((s / Float(e - i)).squareRoot()); i = e
    }
    return out
}

func shape(_ levels: [Float], norm: String, boost: Float, release: Float) -> [Float] {
    let sorted = levels.sorted()
    let ref: Float
    switch norm {
    case "peak": ref = sorted.last ?? 0
    case "p90":  ref = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.90))]
    case "p75":  ref = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.75))]
    default:     ref = sorted.last ?? 0
    }
    guard ref > 0.0001 else { return levels.map { _ in 0 } }
    var out = levels.map { min(1, ($0 / ref) * boost) }
    for i in 1..<out.count { out[i] = max(out[i], out[i - 1] * release) }
    return out
}

/// Loudness in dB across `range`, which spreads speech far more evenly than a
/// linear ratio does - the same reason audio meters are logarithmic.
func shapeDB(_ levels: [Float], range: Float, release: Float) -> [Float] {
    guard let ref = levels.max(), ref > 0.0001 else { return levels.map { _ in 0 } }
    var out = levels.map { v -> Float in
        let db = 20 * log10(max(v, 1e-6) / ref)
        return min(1, max(0, (db + range) / range))
    }
    for i in 1..<out.count { out[i] = max(out[i], out[i - 1] * release) }
    return out
}

var envs: [[Float]] = []
for l in lines { if let r = render(l) { envs.append(rms(r.data, r.sr)) } }

print("shaping                     viseme histogram (shut -> wide)        mean  %shut  %wide")
for (range, release) in [(Float(30), Float(0.60)), (36, 0.60), (42, 0.60), (36, 0.72)] {
    var hist = [Int](repeating: 0, count: 7); var all: [Float] = []
    for e in envs {
        for v in shapeDB(e, range: range, release: release) {
            all.append(v); hist[min(6, max(0, Int(v * 6 + 0.5)))] += 1
        }
    }
    let total = max(all.count, 1)
    let bars = hist.map { String(format: "%3.0f", Double($0) / Double(total) * 100) }.joined(separator: " ")
    let mean = all.reduce(0, +) / Float(total)
    print(String(format: "dB %2.0f       rel %.2f   %@   %.2f  %3.0f%%  %3.0f%%",
                 range, release, bars, mean,
                 Double(hist[0]) / Double(total) * 100, Double(hist[6]) / Double(total) * 100))
}

for (norm, boost, release) in [("peak", Float(1.6), Float(0.70)),
                               ("peak", 1.25, 0.65),
                               ("peak", 1.0, 0.60),
                               ("p90", 1.0, 0.60),
                               ("p75", 1.0, 0.60),
                               ("p90", 1.15, 0.55)] {
    var hist = [Int](repeating: 0, count: 7); var all: [Float] = []
    for e in envs {
        for v in shape(e, norm: norm, boost: boost, release: release) {
            all.append(v)
            hist[min(6, max(0, Int(v * 6 + 0.5)))] += 1
        }
    }
    let total = max(all.count, 1)
    let bars = hist.map { String(format: "%3.0f", Double($0) / Double(total) * 100) }.joined(separator: " ")
    let mean = all.reduce(0, +) / Float(total)
    print(String(format: "%-6@ boost %.2f rel %.2f   %@   %.2f  %3.0f%%  %3.0f%%",
                 norm as NSString, boost, release, bars, mean,
                 Double(hist[0]) / Double(total) * 100, Double(hist[6]) / Double(total) * 100))
}
