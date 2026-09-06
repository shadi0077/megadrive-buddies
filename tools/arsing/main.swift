import AVFoundation
import AppKit
_ = NSApplication.shared
// Does the Arabic voice actually sing? Same measurement as the English check:
// does each note land on the pitch asked for, and hold it.
let who = Personality.named(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy")
let pack = who.pack(.arabic)
let song = pack.songs[0]
let root = song.root ?? pack.singingRoot
print("\(pack.name) — \"\(song.title)\"  root \(Int(root)) Hz")

func render(_ t: String, pitch: Float) -> ([Float], Double) {
    let s = AVSpeechSynthesizer(); let u = AVSpeechUtterance(string: t)
    u.voice = AVSpeechSynthesisVoice(identifier: pack.preferredVoice ?? "")
    u.rate = 0.5; u.pitchMultiplier = min(max(pitch, 0.5), 2)
    var a: [Float] = []; var sr = 0.0; var done = false
    s.write(u) { b in
        guard let p = b as? AVAudioPCMBuffer else { return }
        if p.frameLength == 0 { done = true; return }
        sr = p.format.sampleRate
        if let c = p.floatChannelData {
            a.append(contentsOf: UnsafeBufferPointer(start: c[0], count: Int(p.frameLength)))
        }
    }
    let dl = Date().addingTimeInterval(8)
    while !done, Date() < dl { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005)) }
    return (a, sr)
}
func periodicity(_ x: [Float], lag: Int) -> Double {
    guard lag > 1, x.count > lag * 3 else { return 0 }
    var acc = 0.0, ea = 0.0, eb = 0.0
    for j in 0..<(x.count - lag) {
        acc += Double(x[j]) * Double(x[j + lag]); ea += Double(x[j]) * Double(x[j])
        eb += Double(x[j + lag]) * Double(x[j + lag])
    }
    let d = (ea * eb).squareRoot(); return d > 0 ? acc / d : 0
}
// The voice's natural pitch, the way the app measures it.
var natural = 116.0
do {
    let (p, sr) = render("نحن نعلم كيف تسير الرياح على المدى الطويل", pitch: 1)
    let w = Int(sr * 0.08); var f: [Double] = []; var i = 0
    while i + w <= p.count {
        if let q = Voice.period(of: Array(p[i..<(i+w)]), sampleRate: sr) { f.append(sr / q) }
        i += w / 2
    }
    if !f.isEmpty { f.sort(); natural = f[f.count/2] }
}
print(String(format: "voice's natural pitch: %.0f Hz\n", natural))
print("note        want      match   octave-up")
var worst = 1.0, bad = 0
for note in song.phrases.flatMap(\.notes) {
    let target = root * pow(2.0, Double(note.step) / 12.0)
    let (raw, sr) = render(note.text, pitch: Float(min(max(target / natural, 0.5), 2.0)))
    var lo = 0, hi = raw.count - 1
    while lo < raw.count, abs(raw[lo]) < 0.004 { lo += 1 }
    while hi > lo, abs(raw[hi]) < 0.004 { hi -= 1 }
    let src = lo < hi ? Array(raw[lo...hi]) : raw
    let x = Voice.resynth(src, sampleRate: sr, frequency: target,
                          duration: note.beats * song.secondsPerBeat,
                          sourceF0: natural * min(max(target / natural, 0.5), 2.0))
    let lag = Int((sr / target).rounded())
    let m = periodicity(x, lag: lag), up = periodicity(x, lag: max(2, lag/2))
    if up > m { bad += 1 }
    worst = min(worst, m)
    print(String(format: "%-10@ %6.1f Hz  %.2f    %+.2f %@", note.text as NSString,
                 target, m, up, up > m ? "  <-- wrong octave" : ""))
}
print(String(format: "\nweakest match %.2f   wrong octave: %d", worst, bad))
