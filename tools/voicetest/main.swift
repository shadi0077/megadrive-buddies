import AppKit
import AVFoundation

// Checks the speech path: that a line renders, reports a real duration, and
// produces an envelope with enough dynamic range to actually move the beak.
_ = NSApplication.shared
let who = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"

guard let store = SpriteStore(character: who, bundle: Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"] ?? "build/Desktop Buddies.app")!) else {
    print("cannot load sprites"); exit(1)
}
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}
func pump(_ seconds: TimeInterval, while active: () -> Bool = { true }) {
    let dl = Date().addingTimeInterval(seconds)
    while Date() < dl, active() {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.008))
    }
}

print("available voices:")
check("at least one installed", !Voice.options.isEmpty)
check("Fred is the default", Voice.defaultIdentifier.hasSuffix("voice.Fred"),
      Voice.defaultIdentifier)
print("        \(Voice.options.map(\.title).joined(separator: ", "))")

print("\nmenu-bar icon:")
// Each character names its own menu-bar frame in its catalogue.
let hero = store.heroFrame
if let icon = store.menuBarIcon(frame: hero, height: 18) {
    check("is a sane menu-bar size",
          icon.size.height == 18 && icon.size.width > 8 && icon.size.width < 40,
          "\(icon.size)")
    check("is drawn in colour, not as a template", !icon.isTemplate)
    if let tiff = icon.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
        var ink = 0
        var coloured = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.4 else { continue }
                ink += 1
                // Peedy is green, Bonzi purple, F1 grey-and-red; whatever
                // the colour, it must not be rendering as a flat grey blob.
                let channels = [c.redComponent, c.greenComponent, c.blueComponent]
                if (channels.max()! - channels.min()!) > 0.12 { coloured += 1 }
            }
        }
        let ratio = Double(ink) / Double(rep.pixelsWide * rep.pixelsHigh)
        // A blank glyph passes a nil-check but looks like a broken menu item.
        check("actually has ink in it", ratio > 0.15 && ratio < 0.9,
              String(format: "%.0f%% opaque", ratio * 100))
        check("still reads in colour at 18pt", coloured > ink / 3,
              "\(coloured)/\(ink) green")
    }
} else { check("menu-bar icon renders", false) }

print("\nmenu-bar glyph fallback (SF Symbols has no bird before macOS 13):")
if let glyph = store.silhouette(frame: hero, height: 17) {
    check("is a template so it tints with the menu bar", glyph.isTemplate)
    check("is a sane menu-bar size", glyph.size.height == 17 && glyph.size.width > 6
          && glyph.size.width < 40, "\(glyph.size)")
    // A blank glyph would look like a broken menu item, so check it has ink.
    if let tiff = glyph.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
        var opaque = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.4 {
                opaque += 1
            }
        }
        let ratio = Double(opaque) / Double(rep.pixelsWide * rep.pixelsHigh)
        check("actually has ink in it", ratio > 0.12 && ratio < 0.85,
              String(format: "%.0f%% opaque", ratio * 100))
    }
} else { check("glyph renders", false) }

check("a voice exists that predates the Eloquence set",
      Voice.options.contains { !$0.identifier.contains("eloquence") })

print("\nviseme ramp:")
for name in store.talkPoses.keys.sorted() {
    guard let pose = store.talkPoses[name] else { continue }
    let shut = pose.mouth(forLevel: 0)
    let wide = pose.mouth(forLevel: 1)
    check("\(name): silence -> most closed patch", shut == pose.ramp.first, "got \(shut)")
    check("\(name): full volume -> widest patch", wide == pose.ramp.last, "got \(wide)")
    let sweep = stride(from: Float(0), through: 1, by: 0.05).map { pose.mouth(forLevel: $0) }
    check("\(name): sweep uses every patch", Set(sweep).count == pose.ramp.count,
          "\(Set(sweep).count) of \(pose.ramp.count)")
    check("\(name): out-of-range levels are safe",
          pose.ramp.contains(pose.mouth(forLevel: -5))
              && pose.ramp.contains(pose.mouth(forLevel: 99)))
}

print("\nspeaking a line:")
let voice = Voice()
voice.volume = 0.03                      // audible enough to render, quiet to run
var reported: TimeInterval = -1
var finished = false
var levels: [Float] = []

voice.speak("Is it cracker o'clock yet? I could preen for hours, and do.") { secs in
    reported = secs
} onFinish: {
    finished = true
}

pump(4) { reported < 0 }
check("audio started", reported > 0, "no onStart")
check("duration is plausible", reported > 0.8 && reported < 12, "\(reported)s")

let sampleUntil = Date().addingTimeInterval(min(reported + 0.5, 12))
while Date() < sampleUntil, !finished {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.016))
    if voice.isSpeaking { levels.append(voice.level) }
}
pump(3) { !finished }

check("finished", finished)
check("sampled the envelope", levels.count > 20, "\(levels.count) samples")
if let lo = levels.min(), let hi = levels.max() {
    check("beak closes at some point", lo < 0.35, "min \(lo)")
    check("beak opens wide at some point", hi > 0.75, "max \(hi)")
    let mean = levels.reduce(0, +) / Float(levels.count)
    check("not pinned at one extreme", mean > 0.15 && mean < 0.9, "mean \(mean)")
    print(String(format: "        min %.2f  mean %.2f  max %.2f over %d samples",
                 lo, mean, hi, levels.count))
}

print("\npitch:")
check("defaults to High (parrot, not Sam)", Voice().pitch == .high)
check("every setting is in AVSpeechUtterance's 0.5...2.0 range",
      Voice.Pitch.allCases.allSatisfy { $0.rawValue >= 0.5 && $0.rawValue <= 2.0 })

// Verify acoustically: render at each setting and measure the fundamental.
// Trusting the API here would miss a voice that silently ignores pitch.
func medianF0(_ x: [Float], _ sr: Double) -> Double {
    let win = Int(sr * 0.04)
    let minLag = Int(sr / 500), maxLag = Int(sr / 60)
    var found: [Double] = []
    var i = 0
    while i + win < x.count {
        let seg = Array(x[i..<(i + win)])
        let r0 = seg.reduce(Float(0)) { $0 + $1 * $1 }
        if r0 / Float(win) > 1e-4 {
            var bestLag = 0; var best: Float = 0
            for lag in minLag...maxLag where lag < win {
                var acc: Float = 0
                for j in 0..<(win - lag) { acc += seg[j] * seg[j + lag] }
                if acc / r0 > best { best = acc / r0; bestLag = lag }
            }
            if bestLag > 0, best > 0.3 { found.append(sr / Double(bestLag)) }
        }
        i += win
    }
    guard !found.isEmpty else { return 0 }
    found.sort()
    return found[found.count / 2]
}

func renderF0(_ p: Voice.Pitch) -> Double {
    let synth = AVSpeechSynthesizer()
    let u = AVSpeechUtterance(string: "Is it cracker o'clock yet? I could preen for hours.")
    u.voice = AVSpeechSynthesisVoice(identifier: Voice.defaultIdentifier)
    u.rate = 0.52
    u.pitchMultiplier = p.rawValue
    var all: [Float] = []; var sr: Double = 0; var done = false
    synth.write(u) { buf in
        guard let pcm = buf as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { done = true; return }
        sr = pcm.format.sampleRate
        if let ch = pcm.floatChannelData {
            all.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(pcm.frameLength)))
        }
    }
    pump(8) { !done }
    return sr > 0 ? medianF0(all, sr) : 0
}

let measured = Voice.Pitch.allCases.map { (p: $0, f0: renderF0($0)) }
for m in measured { print(String(format: "        %-8@ x%.2f -> %.0f Hz", m.p.title as NSString, m.p.rawValue, m.f0)) }
check("all settings produce voiced audio", measured.allSatisfy { $0.f0 > 50 })
check("pitch rises monotonically",
      zip(measured, measured.dropFirst()).allSatisfy { $0.f0 < $1.f0 },
      measured.map { Int($0.f0) }.description)
if let deep = measured.first(where: { $0.p == .deep })?.f0,
   let high = measured.first(where: { $0.p == .high })?.f0 {
    check("High is audibly above Deep", high > deep * 1.4,
          String(format: "%.0f vs %.0f Hz", high, deep))
}

print("\nno buffer rendering (the path older systems may take):")
let plain = Voice()
plain.volume = 0.03
plain.skipBufferRendering = true
var plainStart: TimeInterval = -1
var plainDone = false
plain.speak("Falling back to ordinary speech.") { plainStart = $0 } onFinish: { plainDone = true }
pump(3) { plainStart < 0 }
check("still reports a duration", plainStart > 0.5, "\(plainStart)")
check("reports speaking", plain.isSpeaking)
check("offers no envelope, so the animator cycles instead", plain.level == 0)
pump(plainStart + 3) { !plainDone }
check("still completes", plainDone)
plain.stop()

print("\nvolume (this app's own, not the system's):")
let vol = Voice()
vol.volume = 0.5
check("takes a level", abs(vol.volume - 0.5) < 1e-6)
vol.volume = 4
check("clamps above 1", vol.volume == 1, "\(vol.volume)")
vol.volume = -2
check("clamps below 0", vol.volume == 0, "\(vol.volume)")

// The mouth must move identically however loud they are: the envelope is
// normalised to the clip's own peak, and the render is always at full scale.
func envelope(at level: Float) -> [Float] {
    let v = Voice()
    v.volume = level
    var levels: [Float] = []
    var started: TimeInterval = -1
    var over = false
    v.speak("Testing the level.") { started = $0 } onFinish: { over = true }
    pump(6) { started < 0 }
    let deadline = Date().addingTimeInterval(max(started, 1) + 4)
    while !over, v.isSpeaking, Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.016))
        levels.append(v.level)
    }
    v.stop()
    return levels
}
let loudEnv = envelope(at: 1.0)
let quietEnv = envelope(at: 0.05)
check("beak still moves when quiet",
      (quietEnv.max() ?? 0) > 0.7 && (quietEnv.min() ?? 1) < 0.4,
      "min \(quietEnv.min() ?? -1) max \(quietEnv.max() ?? -1)")
if let a = loudEnv.max(), let b = quietEnv.max() {
    check("lip sync is the same at any volume", abs(a - b) < 0.15,
          String(format: "%.2f vs %.2f", a, b))
}
var silent = Voice()
silent.volume = 0
var silentDone = false
var silentStart: TimeInterval = -1
silent.speak("Silent but still animated.") { silentStart = $0 } onFinish: { silentDone = true }
pump(6) { silentStart < 0 }
check("volume 0 still reports a duration", silentStart > 0.5, "\(silentStart)")
check("volume 0 still drives the beak", silent.isSpeaking)
pump(silentStart + 4) { !silentDone }
check("volume 0 still completes", silentDone)
silent.stop()

print("\nwith no usable audio output:")
// Can't disable the device from here, but the contract must hold either way:
// speech reports a duration, drives the beak, and completes. It must never
// crash — AVAudioPlayerNode.play() raises an uncatchable ObjC exception if the
// engine's IO thread never cycles, which is what an absent output device looks
// like.
let mimed = Voice()
mimed.volume = 0.03
var mimedStart: TimeInterval = -1
var mimedDone = false
mimed.speak("Testing with no device.") { mimedStart = $0 } onFinish: { mimedDone = true }
pump(6) { mimedStart < 0 }
check("reports a duration whether or not audio is available", mimedStart > 0.5, "\(mimedStart)")
check("drives the beak either way", mimed.isSpeaking)
pump(mimedStart + 4) { !mimedDone }
check("completes either way", mimedDone)
mimed.stop()

print("\nmuted:")
let muted = Voice()
muted.isEnabled = false
var mutedFinished = false
muted.speak("You should not hear this.") { _ in
    check("muted voice does not start audio", false)
} onFinish: { mutedFinished = true }
pump(1) { !mutedFinished }
check("muted still reports completion", mutedFinished)
check("muted reports not speaking", !muted.isSpeaking)
check("muted level is zero", muted.level == 0)

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
