import AVFoundation

/// Speech and singing, with the mouth driven by how loud he actually is.
///
/// Everything is rendered to PCM before anything is played. That buys two
/// things a plain `speak()` can't: the exact duration up front, so the bubble
/// matches the audio instead of guessing from string length, and a loudness
/// envelope to pick a viseme from each frame. Cycling mouths on a timer looks
/// like a puppet; following the waveform looks like speech.
final class Voice {
    struct Option {
        let title: String
        let identifier: String
        let note: String?
    }

    /// MS Sam is a Windows SAPI voice and isn't ours to ship, so these are the
    /// nearest things macOS has. Fred is the classic MacinTalk formant synth —
    /// same era, same flat robotic register — and is the default.
    private static let known: [Option] = [
        Option(title: "Fred", identifier: "com.apple.speech.synthesis.voice.Fred",
               note: "closest to MS Sam"),
        Option(title: "Ralph", identifier: "com.apple.speech.synthesis.voice.Ralph", note: nil),
        Option(title: "Junior", identifier: "com.apple.speech.synthesis.voice.Junior", note: nil),
        Option(title: "Albert", identifier: "com.apple.speech.synthesis.voice.Albert", note: nil),
        Option(title: "Grandpa", identifier: "com.apple.eloquence.en-US.Grandpa",
               note: "Eloquence"),
        Option(title: "Eddy", identifier: "com.apple.eloquence.en-US.Eddy", note: "Eloquence"),
        Option(title: "Zarvox", identifier: "com.apple.speech.synthesis.voice.Zarvox", note: nil),
    ]

    /// Only the ones actually installed on this Mac.
    static let options: [Option] = known.filter {
        AVSpeechSynthesisVoice(identifier: $0.identifier) != nil
    }

    static var defaultIdentifier: String {
        options.first?.identifier
            ?? AVSpeechSynthesisVoice(language: "en-US")?.identifier
            ?? ""
    }

    /// Whether the system has this voice, including ones not in `options` —
    /// the Arabic voices aren't on the MS-Sam-alike list but are perfectly
    /// installed.
    static func installed(_ identifier: String) -> Bool {
        AVSpeechSynthesisVoice(identifier: identifier) != nil
    }

    /// The language a voice speaks, as a bare code like "en" or "ar".
    static func languageCode(of identifier: String) -> String? {
        AVSpeechSynthesisVoice(identifier: identifier)?.language
            .split(separator: "-").first.map(String.init)
    }

    /// Whether a voice is a sensible choice for this language.
    ///
    /// Handing Arabic text to an English synthesiser doesn't fail — it spells
    /// it out, at roughly ten times the length and entirely unintelligible.
    /// So a saved voice from another language must never be reapplied.
    static func canSpeak(_ identifier: String, _ language: Language) -> Bool {
        languageCode(of: identifier) == language.rawValue
    }

    /// The best installed voice for an exact locale like "ar-SA", preferring
    /// higher-quality variants where several exist.
    static func bestVoice(forLocale locale: String) -> String? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.caseInsensitiveCompare(locale) == .orderedSame }
            .max { $0.quality.rawValue < $1.quality.rawValue }?
            .identifier
    }

    /// Installed voices worth offering for a language. For English that's the
    /// curated MS-Sam-alike list; for anything else, whatever the system has.
    static func options(for language: Language) -> [Option] {
        if language == .english { return options }
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language.rawValue) }
            .map { Option(title: $0.name, identifier: $0.identifier, note: nil) }
    }

    static func title(for identifier: String) -> String {
        options.first { $0.identifier == identifier }?.title ?? "System voice"
    }

    /// Pitch settings, as multipliers of the voice's natural pitch. Measured
    /// on Fred, whose natural F0 is about 116 Hz, these land near 99 / 133 /
    /// 174 / 215 Hz — the multiplier tracks F0 almost exactly linearly.
    enum Pitch: Float, CaseIterable {
        case deep = 0.85
        case low = 1.15
        case high = 1.5
        case squeaky = 1.85

        var title: String {
            switch self {
            case .deep: return "Deep"
            case .low: return "Low"
            case .high: return "High"
            case .squeaky: return "Squeaky"
            }
        }
    }

    /// How many envelope samples per second of audio.
    private static let envelopeRate: Double = 60

    var isEnabled = true
    var identifier = Voice.defaultIdentifier
    /// A shade above default: MS Sam was brisk and flat.
    var rate: Float = 0.52
    /// He is a parrot, so he sits well above Sam's register by default.
    var pitch: Pitch = .high
    /// Output level for this app alone, 0...1 — nothing to do with the system
    /// volume. Applied as gain on the player node rather than baked into the
    /// render, so it takes effect mid-sentence and leaves the rendered waveform
    /// (and therefore the lip-sync envelope) untouched.
    var volume: Float = 1.0 {
        didSet {
            volume = min(max(volume, 0), 1)
            node.volume = volume
        }
    }
    /// Sung tonic in Hz, set from the personality.
    var personalityRoot: Double = 196

    /// Forces the no-lip-sync path, which is what runs wherever buffer
    /// rendering is unavailable. Exposed so tests can cover that branch.
    var skipBufferRendering = false

    /// Playback runs through an engine that is started once and left running.
    ///
    /// `AVAudioPlayerNode.play()` raises "player did not see an IO cycle" — an
    /// uncatchable ObjC exception, so a hard crash — if it lands before the
    /// engine's IO thread has spun up. An earlier version started the engine
    /// lazily and paused it when idle, which made that race reachable on
    /// almost every utterance. Starting at launch means IO has been cycling
    /// long before he ever says anything.
    ///
    /// (AVAudioPlayer over an in-memory WAV would sidestep the lifecycle
    /// entirely, but `play()` returns false on this setup — the WAV is valid
    /// and `afinfo` reads it fine, it simply refuses to start.)
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var connectedFormat: AVAudioFormat?

    /// When the engine's IO thread last rendered anything.
    ///
    /// `engine.isRunning` is no proof that it is: with no usable output device
    /// it returns true while nothing ever renders, and `node.play()` then
    /// raises an ObjC exception Swift cannot catch — a hard crash.
    ///
    /// This used to be a one-shot "IO has started" flag, which crashed anyway
    /// when a machine's audio recovered mid-session: a device that comes and
    /// goes leaves a sticky flag saying yes while the truth is no. A timestamp
    /// refreshed by a permanent tap answers the only question that matters —
    /// is it rendering *now* — and closes that window.
    private var lastRenderAt: TimeInterval = 0
    private var ioIsLive: Bool { CACurrentMediaTime() - lastRenderAt < 0.5 }

    /// Held for the lifetime of a render; dropping it mid-flight cancels it.
    private var writer: AVSpeechSynthesizer?
    /// Used only when buffer rendering isn't available.
    private let fallback = AVSpeechSynthesizer()

    private var envelope: [Float] = []
    private var startedAt: TimeInterval = 0
    private var speaking = false
    /// Bumped on every stop/new utterance so stale callbacks can be dropped.
    private var token = 0

    init() {
        engine.attach(node)
        node.volume = volume
        connect(to: AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1))
        engine.prepare()
        watchForIO()
        try? engine.start()

        // A device change (headphones in or out) stops the engine, and may be
        // the moment a working output appears. Restart and start listening for
        // a render cycle again rather than waiting for the next utterance.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastRenderAt = 0
            self.connectedFormat = nil
            self.connect(to: AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1))
            self.watchForIO()
            try? self.engine.start()
        }
    }

    /// Reconnecting the graph can drop an existing tap, so always remove and
    /// reinstall rather than assuming the previous one survived.
    private func watchForIO() {
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024,
                                        format: nil) { [weak self] _, _ in
            // Audio thread: a plain store, deliberately unsynchronised.
            self?.lastRenderAt = CACurrentMediaTime()
        }
    }

    private func connect(to format: AVAudioFormat?) {
        guard let format, connectedFormat != format else { return }
        engine.connect(node, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    var isSpeaking: Bool { speaking }

    /// Mouth openness, 0...1, at the current playback position.
    var level: Float {
        guard speaking, !envelope.isEmpty else { return 0 }
        // Off the node's own render clock where possible, so the beak cannot
        // drift from the audio.
        var elapsed = CACurrentMediaTime() - startedAt
        if node.isPlaying, let nodeTime = node.lastRenderTime,
           let played = node.playerTime(forNodeTime: nodeTime), played.sampleRate > 0 {
            elapsed = Double(played.sampleTime) / played.sampleRate
        }
        let index = Int(elapsed * Self.envelopeRate)
        guard index >= 0, index < envelope.count else { return 0 }
        return envelope[index]
    }

    // MARK: - Speaking

    /// Speak `text`. `onStart` gets the real duration once audio begins.
    func speak(_ text: String,
               onStart: @escaping (TimeInterval) -> Void,
               onFinish: @escaping () -> Void) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !trimmed.isEmpty else { onFinish(); return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        // AVSpeechUtterance only accepts 0.5...2.0.
        utterance.pitchMultiplier = min(max(pitch.rawValue, 0.5), 2.0)
        // Rendered at full scale; the user's level is applied on the way out.
        utterance.volume = 1

        let mine = token

        guard !skipBufferRendering else {
            speakDirectly(utterance, onStart: onStart, onFinish: onFinish)
            return
        }

        renderOne(trimmed, pitch: utterance.pitchMultiplier, rate: rate) { [weak self] buffer in
            guard let self, self.token == mine else { return }
            guard let buffer, let clip = Self.clip(from: buffer) else {
                self.speakDirectly(utterance, onStart: onStart, onFinish: onFinish)
                return
            }
            self.play(clip, token: mine, onStart: onStart, onFinish: onFinish)
        }
    }

    func stop() {
        token += 1
        writer?.stopSpeaking(at: .immediate)
        writer = nil
        fallback.stopSpeaking(at: .immediate)
        if node.isPlaying { node.stop() }
        speaking = false
        envelope = []
    }

    /// Say a sample line so a voice can be auditioned from the menu.
    func preview(_ text: String) {
        speak(text, onStart: { _ in }, onFinish: {})
    }

    // MARK: - Singing

    /// Sing a song, reporting each lyric line as it comes round.
    ///
    /// Every note is a separate one-syllable utterance rendered at its own
    /// pitch, padded with silence to fill its beat, and stitched into a single
    /// clip. Doing it as one buffer rather than a queue of utterances means the
    /// lyrics and the lip sync come off the same clock as the audio, so nothing
    /// drifts.
    func sing(_ song: Song,
              onPhrase: @escaping (Int) -> Void,
              onStart: @escaping (TimeInterval) -> Void,
              onFinish: @escaping () -> Void) {
        stop()
        guard isEnabled, !song.phrases.isEmpty, !skipBufferRendering else {
            onFinish()
            return
        }

        let root = song.root ?? personalityRoot
        let mine = token
        let flat = song.phrases.flatMap(\.notes)

        var phraseStartNote: [Int] = []
        var running = 0
        for phrase in song.phrases {
            phraseStartNote.append(running)
            running += phrase.notes.count
        }

        var rendered: [AVAudioPCMBuffer?] = Array(repeating: nil, count: flat.count)
        var sourcePitch: [Double] = Array(repeating: 0, count: flat.count)
        var natural = Self.fallbackF0

        func renderNote(_ index: Int) {
            guard token == mine else { return }
            guard index < flat.count else {
                self.assembleSong(song, notes: flat, rendered: rendered,
                                  sourcePitch: sourcePitch,
                                  phraseStartNote: phraseStartNote, token: mine,
                                  root: root, onPhrase: onPhrase,
                                  onStart: onStart, onFinish: onFinish)
                return
            }
            let note = flat[index]
            let target = root * pow(2.0, Double(note.step) / 12.0)
            // Put the synthesiser in roughly the right register first, so the
            // grains are close to the source's own period and smear less. The
            // exact pitch is imposed afterwards.
            let coarse = min(max(target / natural, 0.5), 2.0)
            renderOne(note.text, pitch: Float(coarse), rate: 0.5) { buffer in
                guard self.token == mine else { return }
                rendered[index] = buffer.flatMap { Self.trimmed($0) }
                sourcePitch[index] = natural * coarse
                renderNote(index + 1)
            }
        }
        measureNaturalPitch { [weak self] hz in
            guard let self, self.token == mine else { return }
            natural = hz
            renderNote(0)
        }
    }

    // MARK: - Making a note out of a syllable

    /// Each voice's natural fundamental, measured once and remembered.
    ///
    /// Detecting the period of a single sung syllable is unreliable — a short
    /// clip that starts with "sw" or "ch" reads as a harmonic, and PSOLA built
    /// on a wrong period lets the source pitch leak through. Measuring once
    /// over a long, fully voiced phrase is far steadier, and since we render
    /// the syllable ourselves at a known multiplier, its pitch is then known
    /// rather than guessed.
    private static var naturalPitches: [String: Double] = [:]
    private static let fallbackF0: Double = 116

    private func measureNaturalPitch(_ completion: @escaping (Double) -> Void) {
        if let known = Self.naturalPitches[identifier] { completion(known); return }
        // Long and heavily voiced, so there is plenty to lock onto.
        renderOne("we all know how the low winds roll along", pitch: 1, rate: 0.5) { buffer in
            var result = Self.fallbackF0
            if let buffer, let data = buffer.floatChannelData {
                let sr = buffer.format.sampleRate
                let x = Array(UnsafeBufferPointer(start: data[0],
                                                  count: Int(buffer.frameLength)))
                let win = Int(sr * 0.08)
                var found: [Double] = []
                var i = 0
                while i + win <= x.count {
                    if let p = Self.period(of: Array(x[i..<(i + win)]), sampleRate: sr) {
                        found.append(sr / p)
                    }
                    i += win / 2
                }
                if !found.isEmpty {
                    found.sort()
                    result = found[found.count / 2]
                }
            }
            Self.naturalPitches[self.identifier] = result
            completion(result)
        }
    }

    /// The source's own pitch period, in samples, from the voiced middle of a
    /// syllable. Returns nil when nothing periodic is there (an "s" or a "t").
    static func period(of source: [Float], sampleRate: Double) -> Double? {
        guard source.count > 64 else { return nil }
        // Analyse the loudest stretch, which is the vowel. Taking a fixed slice
        // instead lands on the consonant for a syllable like "star" and reads
        // the period off the "st", which came out a third of the right pitch.
        let span = min(source.count, max(64, Int(sampleRate * 0.05)))
        var bestStart = 0
        var bestEnergy = Float(-1)
        var start = 0
        while start + span <= source.count {
            var energy: Float = 0
            for j in start..<(start + span) { energy += source[j] * source[j] }
            if energy > bestEnergy { bestEnergy = energy; bestStart = start }
            start += max(1, span / 4)
        }
        let seg = Array(source[bestStart..<(bestStart + span)])

        let minLag = max(2, Int(sampleRate / 450))
        let maxLag = min(seg.count - 2, Int(sampleRate / 70))
        guard minLag < maxLag else { return nil }

        let energy = seg.reduce(Float(0)) { $0 + $1 * $1 }
        guard energy > 1e-6 else { return nil }

        var scores = [Float](repeating: 0, count: maxLag + 1)
        for lag in minLag...maxLag {
            var acc: Float = 0, norm: Float = 0
            for j in 0..<(seg.count - lag) {
                acc += seg[j] * seg[j + lag]
                norm += seg[j + lag] * seg[j + lag]
            }
            scores[lag] = norm > 0 ? acc / (energy * norm).squareRoot() : 0
        }
        guard let peak = scores.max(), peak > 0.35 else { return nil }

        // The fundamental is the *first* strong peak. Every later peak sits at
        // a multiple of it, so scanning from the long end — which looks like it
        // avoids locking onto a harmonic — actually lands on a sub-harmonic and
        // reports the note an octave or two flat.
        var chosen: Int?
        var lag = minLag + 1
        while lag < maxLag {
            if scores[lag] > scores[lag - 1], scores[lag] >= scores[lag + 1],
               scores[lag] > peak * 0.8 {
                chosen = lag
                break
            }
            lag += 1
        }
        guard let best = chosen, best > minLag, best < maxLag else { return nil }

        // Parabolic interpolation, so the period isn't quantised to whole
        // samples — at 300 Hz one sample is most of a semitone.
        let a = scores[best - 1], b = scores[best], c = scores[best + 1]
        let denom = a - 2 * b + c
        let shift = denom != 0 ? 0.5 * Double(a - c) / Double(denom) : 0
        return Double(best) + max(-1, min(1, shift))
    }

    /// The loud middle of a syllable — its vowel.
    ///
    /// Everything before it is the opening consonant and everything after is
    /// the closing one. Knowing where it starts and ends is what lets a long
    /// note hold the vowel rather than drawing out the "st" in "star".
    static func vowel(of source: [Float], sampleRate: Double) -> Range<Int> {
        guard source.count > 16 else { return 0..<source.count }
        let win = max(8, Int(sampleRate * 0.01))
        var energies: [Float] = []
        var i = 0
        while i + win <= source.count {
            var e: Float = 0
            for j in i..<(i + win) { e += source[j] * source[j] }
            energies.append(e)
            i += win
        }
        guard let peak = energies.max(), peak > 0 else { return 0..<source.count }
        let threshold = peak * 0.25
        guard let first = energies.firstIndex(where: { $0 >= threshold }),
              let last = energies.lastIndex(where: { $0 >= threshold }) else {
            return 0..<source.count
        }
        let lo = first * win
        let hi = min(source.count, (last + 1) * win)
        return lo < hi ? lo..<hi : 0..<source.count
    }

    /// Positions of the source's glottal pulses, one per period.
    private static func pitchMarks(_ source: [Float], period: Double) -> [Int] {
        let step = Int(period.rounded())
        guard step > 1 else { return [] }
        var marks: [Int] = []
        var centre = step
        while centre < source.count - step {
            // Snap to the loudest sample nearby, so every grain starts at the
            // same point in the waveform's cycle. This is the whole trick:
            // grains taken at arbitrary phase cancel each other out instead of
            // reinforcing, which is why naive overlap-add produces mush.
            var best = centre
            for j in max(0, centre - step / 2)...min(source.count - 1, centre + step / 2)
            where abs(source[j]) > abs(source[best]) { best = j }
            marks.append(best)
            centre = best + step
        }
        return marks
    }

    /// Re-lay a rendered syllable at one constant pitch, for an exact duration.
    ///
    /// Asking the synthesiser to sing does not work. Measured over Twinkle,
    /// letting `pitchMultiplier` carry the melody gave every note a 5–31
    /// semitone spread (it applies sentence intonation to each isolated word)
    /// and interval errors up to 3.4 semitones — the tune was unrecognisable.
    ///
    /// So the pitch is taken away from it, by time-domain PSOLA: cut one grain
    /// per glottal pulse and lay those grains down again at exactly the target
    /// period. The grains carry the syllable's formants, their new spacing
    /// dictates the pitch. Output length is chosen rather than inherited, so
    /// notes butt together with no padding and the line is legato.
    /// `sourceF0` is the pitch the syllable was rendered at, when the caller
    /// knows it. Passing it avoids detecting the period from a fragment too
    /// short to be reliable.
    static func resynth(_ source: [Float], sampleRate: Double,
                        frequency: Double, duration: Double,
                        sourceF0: Double = 0) -> [Float] {
        let outCount = Int(duration * sampleRate)
        guard outCount > 0 else { return [] }
        guard source.count > 8, frequency > 20 else {
            return [Float](repeating: 0, count: outCount)
        }

        let outPeriod = sampleRate / frequency
        // Unvoiced syllables have no period to follow; give them the target's,
        // which imposes a pitch on the noise. That is the classic singing-robot
        // sound and is exactly right here.
        let srcPeriod = sourceF0 > 20
            ? sampleRate / sourceF0
            : (period(of: source, sampleRate: sampleRate) ?? outPeriod)
        let marks = pitchMarks(source, period: srcPeriod)
        guard !marks.isEmpty else { return [Float](repeating: 0, count: outCount) }

        let half = max(2, Int(srcPeriod.rounded()))
        let window = (0...(2 * half)).map {
            Float(0.5 - 0.5 * cos(Double.pi * Double($0) / Double(half)))
        }

        var out = [Float](repeating: 0, count: outCount)
        var weight = [Float](repeating: 0, count: outCount)

        // Consonants keep their natural speed and the vowel absorbs the
        // stretch, so a long note is a held vowel rather than a drawn-out "st".
        let voiced = vowel(of: source, sampleRate: sampleRate)
        let head = min(voiced.lowerBound, outCount / 3)
        let tail = min(source.count - voiced.upperBound, outCount / 3)
        let body = max(1, outCount - head - tail)

        func sourceTime(_ t: Double) -> Double {
            if t < Double(head) {
                return head > 0 ? t * Double(voiced.lowerBound) / Double(head) : 0
            }
            if t >= Double(head + body) {
                let into = t - Double(head + body)
                let span = Double(source.count - voiced.upperBound)
                return Double(voiced.upperBound) + (tail > 0 ? into * span / Double(tail) : 0)
            }
            let into = (t - Double(head)) / Double(body)
            return Double(voiced.lowerBound) + into * Double(voiced.count)
        }

        var centre = 0.0
        while Int(centre) < outCount {
            // The grain that sits at this point of the syllable.
            let srcTime = sourceTime(centre)
            var nearest = marks[0]
            var bestGap = Double.infinity
            for m in marks {
                let gap = abs(Double(m) - srcTime)
                if gap < bestGap { bestGap = gap; nearest = m }
            }
            let outStart = Int(centre) - half
            let srcStart = nearest - half
            for k in 0...(2 * half) {
                let o = outStart + k, sIdx = srcStart + k
                guard o >= 0, o < outCount, sIdx >= 0, sIdx < source.count else { continue }
                out[o] += source[sIdx] * window[k]
                weight[o] += window[k]
            }
            centre += outPeriod
        }

        // Grain spacing rarely matches grain width, so normalise by how much
        // window actually landed on each sample; otherwise pitching up shouts
        // and pitching down whispers.
        for i in 0..<outCount where weight[i] > 0.2 { out[i] /= weight[i] }
        return out
    }

    /// The pitch the tonic sits at for a given song.
    ///
    /// Utterance pitch is capped at 0.5...2.0, so a wide melody has to be
    /// transposed down as a whole rather than letting the clamp flatten its top
    /// notes — which would quietly wreck the tune's shape. Singing sits below
    /// his speaking pitch for the same reason: it needs the headroom.
    static func tonic(for song: Song, speaking: Float) -> Float {
        let steps = song.phrases.flatMap(\.notes).map(\.step)
        let top = steps.max() ?? 0
        let bottom = steps.min() ?? 0
        let ceiling = 2.0 / Float(pow(2.0, Double(top) / 12.0))
        let floor = 0.5 / Float(pow(2.0, Double(bottom) / 12.0))
        return max(floor, min(min(speaking, 1.15), ceiling))
    }

    /// Beat length for a song once each syllable's rendered length is known.
    ///
    /// Stretched until the tightest note fits inside its own beat, so a
    /// two-beat note stays twice a one-beat note instead of both collapsing to
    /// whatever the synthesiser happened to produce.
    static func secondsPerBeat(for song: Song, noteDurations: [Double]) -> Double {
        var beat = song.secondsPerBeat
        for (note, duration) in zip(song.phrases.flatMap(\.notes), noteDurations)
        where note.beats > 0 {
            beat = max(beat, duration / note.beats)
        }
        return beat
    }

    private func assembleSong(_ song: Song, notes: [Note],
                              rendered: [AVAudioPCMBuffer?],
                              sourcePitch: [Double],
                              phraseStartNote: [Int], token mine: Int,
                              root: Double,
                              onPhrase: @escaping (Int) -> Void,
                              onStart: @escaping (TimeInterval) -> Void,
                              onFinish: @escaping () -> Void) {
        guard let format = rendered.compactMap({ $0 }).first?.format else { onFinish(); return }
        let sampleRate = format.sampleRate

        // Every note is rebuilt at its exact pitch and its exact length, so the
        // written rhythm survives and consecutive notes join without a gap.
        var samples: [Float] = []
        var noteOffsets: [Int] = []
        for (i, note) in notes.enumerated() {
            noteOffsets.append(samples.count)
            let seconds = note.beats * song.secondsPerBeat
            guard let buffer = rendered[i], let data = buffer.floatChannelData else {
                samples.append(contentsOf: [Float](repeating: 0,
                                                   count: Int(seconds * sampleRate)))
                continue
            }
            let source = Array(UnsafeBufferPointer(start: data[0],
                                                   count: Int(buffer.frameLength)))
            let frequency = root * pow(2.0, Double(note.step) / 12.0)
            samples.append(contentsOf: Self.resynth(source, sampleRate: sampleRate,
                                                    frequency: frequency,
                                                    duration: seconds,
                                                    sourceF0: sourcePitch[i]))
        }

        guard !samples.isEmpty,
              let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(samples.count)),
              let dst = out.floatChannelData else { onFinish(); return }
        dst[0].update(from: samples, count: samples.count)
        out.frameLength = AVAudioFrameCount(samples.count)

        let clip = Clip(buffer: out,
                        envelope: Self.loudness(of: out),
                        duration: Double(samples.count) / sampleRate)

        // Lyric cues, taken off the same timeline as the audio.
        let cues = phraseStartNote.map { Double(noteOffsets[$0]) / sampleRate }
        play(clip, token: mine, onStart: { duration in
            onStart(duration)
            for (index, at) in cues.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + at) { [weak self] in
                    guard let self, self.token == mine else { return }
                    onPhrase(index)
                }
            }
        }, onFinish: onFinish)
    }

    // MARK: - Playback

    struct Clip {
        let buffer: AVAudioPCMBuffer
        let envelope: [Float]
        let duration: TimeInterval
    }

    private func play(_ clip: Clip, token mine: Int,
                      onStart: @escaping (TimeInterval) -> Void,
                      onFinish: @escaping () -> Void,
                      waited: TimeInterval = 0) {
        connect(to: clip.buffer.format)
        if !engine.isRunning { try? engine.start() }

        guard ioIsLive else {
            // Give a just-started engine a moment to spin up, then give up and
            // mime rather than risk the exception.
            if waited < 0.75, engine.isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self, self.token == mine else { return }
                    self.play(clip, token: mine, onStart: onStart, onFinish: onFinish,
                              waited: waited + 0.05)
                }
            } else {
                mime(clip, token: mine, onStart: onStart, onFinish: onFinish)
            }
            return
        }

        node.scheduleBuffer(clip.buffer, completionCallbackType: .dataPlayedBack) { _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.token == mine else { return }
                self.speaking = false
                self.envelope = []
                onFinish()
            }
        }
        envelope = clip.envelope
        startedAt = CACurrentMediaTime()
        speaking = true
        node.play()
        onStart(clip.duration)
    }

    /// Run a clip's timeline with no sound.
    ///
    /// When there is no working output device he still opens his beak on the
    /// right syllables and the bubble still keeps time — he just mimes. Much
    /// better than going silent and still, and far better than crashing.
    private func mime(_ clip: Clip, token mine: Int,
                      onStart: @escaping (TimeInterval) -> Void,
                      onFinish: @escaping () -> Void) {
        envelope = clip.envelope
        startedAt = CACurrentMediaTime()
        speaking = true
        onStart(clip.duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + clip.duration) { [weak self] in
            guard let self, self.token == mine else { return }
            self.speaking = false
            self.envelope = []
            onFinish()
        }
    }

    /// No envelope here, so the animator falls back to timed viseme cycling.
    private func speakDirectly(_ utterance: AVSpeechUtterance,
                               onStart: @escaping (TimeInterval) -> Void,
                               onFinish: @escaping () -> Void) {
        guard !utterance.speechString.isEmpty else { onFinish(); return }
        // No node in this path, so the level has to ride on the utterance.
        utterance.volume = volume
        let estimate = min(7.0, 1.2 + Double(utterance.speechString.count) * 0.06)
        speaking = true
        envelope = []
        startedAt = CACurrentMediaTime()
        fallback.speak(utterance)
        onStart(estimate)
        let mine = token
        DispatchQueue.main.asyncAfter(deadline: .now() + estimate) { [weak self] in
            guard let self, self.token == mine else { return }
            self.speaking = false
            onFinish()
        }
    }

    // MARK: - Rendering

    /// Render one utterance to a single buffer, or nil if that isn't possible.
    private func renderOne(_ text: String, pitch: Float, rate: Float,
                           completion: @escaping (AVAudioPCMBuffer?) -> Void) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = min(max(pitch, 0.5), 2.0)
        utterance.volume = 1

        let synth = AVSpeechSynthesizer()
        writer = synth
        var chunks: [AVAudioPCMBuffer] = []
        var settled = false
        let lock = NSLock()

        let settle: () -> Void = {
            lock.lock()
            let first = !settled
            settled = true
            let all = chunks
            lock.unlock()
            guard first else { return }
            DispatchQueue.main.async { completion(Self.join(all)) }
        }

        synth.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            guard pcm.frameLength > 0 else { settle(); return }
            if let copy = Self.copy(pcm) {
                lock.lock(); chunks.append(copy); lock.unlock()
            }
        }
        // If rendering never lands, fall back rather than hanging.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { settle() }
    }

    /// Take a private copy of a rendered chunk, normalised to float32.
    ///
    /// The buffer handed to the callback is reused, so it has to be copied. The
    /// int16 branch is for older systems, which render the legacy voices to
    /// 16-bit; without it the whole clip would be discarded and we would drop
    /// to plain speech with no lip sync.
    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let frames = Int(source.frameLength)
        guard frames > 0 else { return nil }
        let channels = Int(source.format.channelCount)

        if let src = source.floatChannelData {
            guard let out = AVAudioPCMBuffer(pcmFormat: source.format,
                                             frameCapacity: source.frameLength),
                  let dst = out.floatChannelData else { return nil }
            for ch in 0..<channels { dst[ch].update(from: src[ch], count: frames) }
            out.frameLength = source.frameLength
            return out
        }

        // Speech is mono; anything interleaved and multi-channel isn't worth
        // untangling here — the caller falls back to ordinary playback.
        guard let src = source.int16ChannelData, channels == 1,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: source.format.sampleRate,
                                         channels: 1, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: source.frameLength),
              let dst = out.floatChannelData else { return nil }
        for i in 0..<frames { dst[0][i] = Float(src[0][i]) / 32768 }
        out.frameLength = source.frameLength
        return out
    }

    /// Crop leading and trailing silence.
    ///
    /// Each rendered utterance is padded with quiet either side. For a whole
    /// sentence that is harmless, but for a single sung syllable the padding
    /// is dead weight — and since the song's tempo stretches to fit its
    /// longest note, one padded syllable slows down the entire song. Trimming
    /// took Daisy Bell from 19s to something near its written length.
    private static func trimmed(_ buffer: AVAudioPCMBuffer,
                                floor: Float = 0.004) -> AVAudioPCMBuffer? {
        guard let data = buffer.floatChannelData?[0] else { return buffer }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }

        var first = 0
        while first < frames, abs(data[first]) < floor { first += 1 }
        guard first < frames else { return nil }        // all silence
        var last = frames - 1
        while last > first, abs(data[last]) < floor { last -= 1 }

        let kept = last - first + 1
        guard kept > 0, kept < frames,
              let out = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                         frameCapacity: AVAudioFrameCount(kept)),
              let dst = out.floatChannelData else { return buffer }
        for ch in 0..<Int(buffer.format.channelCount) {
            guard let src = buffer.floatChannelData?[ch] else { continue }
            dst[ch].update(from: src.advanced(by: first), count: kept)
        }
        out.frameLength = AVAudioFrameCount(kept)
        return out
    }

    /// Concatenate same-format buffers into one.
    private static func join(_ chunks: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let format = chunks.first?.format else { return nil }
        let total = chunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard total > 0,
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let dst = out.floatChannelData else { return nil }
        var offset = 0
        for chunk in chunks {
            guard chunk.format == format, let src = chunk.floatChannelData else { continue }
            let frames = Int(chunk.frameLength)
            for ch in 0..<Int(format.channelCount) {
                dst[ch].advanced(by: offset).update(from: src[ch], count: frames)
            }
            offset += frames
        }
        out.frameLength = AVAudioFrameCount(offset)
        return offset > 0 ? out : nil
    }

    private static func clip(from buffer: AVAudioPCMBuffer) -> Clip? {
        guard buffer.frameLength > 0 else { return nil }
        return Clip(buffer: buffer,
                    envelope: loudness(of: buffer),
                    duration: Double(buffer.frameLength) / buffer.format.sampleRate)
    }

    /// Per-window RMS mapped to dB against the clip's own peak.
    ///
    /// Linear loudness is bimodal for speech — almost everything lands either
    /// near silence or near the peak, so the beak just slams between shut and
    /// wide and the five shapes in between never get used. Measured over a set
    /// of his lines, a 30 dB window spreads them evenly (roughly
    /// 22/9/10/8/3/24/23 across the ramp, against 22/15/7/4/5/5/41 for linear).
    private static func loudness(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let data = buffer.floatChannelData?[0] else { return [] }
        let frames = Int(buffer.frameLength)
        let window = max(1, Int(buffer.format.sampleRate / envelopeRate))

        var levels: [Float] = []
        levels.reserveCapacity(frames / window + 1)
        var i = 0
        while i < frames {
            let end = min(i + window, frames)
            var sum: Float = 0
            for j in i..<end { sum += data[j] * data[j] }
            levels.append((sum / Float(end - i)).squareRoot())
            i = end
        }

        guard let peak = levels.max(), peak > 0.0001 else {
            return [Float](repeating: 0, count: levels.count)
        }
        let range: Float = 30      // dB below peak that counts as fully shut
        var out = levels.map { level -> Float in
            let db = 20 * log10(max(level, 1e-6) / peak)
            return min(1, max(0, (db + range) / range))
        }
        // Slow release, so he doesn't chatter on every dip between syllables.
        for i in 1..<out.count { out[i] = max(out[i], out[i - 1] * 0.6) }
        return out
    }
}
