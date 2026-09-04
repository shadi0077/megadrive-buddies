import AVFoundation

/// A character's sound effects, for characters who make noise rather than talk.
///
/// Deliberately `AVAudioPlayer` rather than the engine the speaking characters
/// use: these are short one-shots that want firing and forgetting, and
/// `AVAudioPlayer.play()` returns false on a dead audio device instead of
/// raising the uncatchable exception `AVAudioPlayerNode` does.
final class SoundBank {
    /// Which kind of noise fits a moment.
    enum Kind: String, CaseIterable {
        case effort     // short grunts — punches, kicks
        case impact     // hits and thuds
        case shout      // longer shouts — specials, arriving, celebrating
    }

    private var clips: [Kind: [URL]] = [:]
    /// Held while playing; `AVAudioPlayer` stops the moment it's released.
    /// Only ever touched on `speaker`.
    private var playing: [AVAudioPlayer] = []
    private var recent: [Kind: Int] = [:]

    /// Sound is started off the main thread.
    ///
    /// `AVAudioPlayer.play()` looks synchronous and local, and is neither: it
    /// makes a blocking XPC call to the audio server. When that server is
    /// unhappy the call simply doesn't return, and on the main thread that
    /// freezes the whole app — every character stops mid-step, no menu, no
    /// trace, nothing to see. It happened here: a test that played a hundred
    /// clips in a row wedged the system audio service, and afterwards the app
    /// hung on the first character's arrival noise.
    ///
    /// A hung audio server is now somebody else's problem. The characters keep
    /// walking, in silence.
    private let speaker = DispatchQueue(label: "megadrive-buddies.sound",
                                        qos: .userInitiated)

    var volume: Float = 0.8
    var isEnabled = true

    /// `set` is the folder the sounds live in, which may be shared: the four
    /// Streets of Rage characters all draw on the same rip rather than
    /// carrying four copies of it.
    init?(set: String, bundle: Bundle = .main) {
        let dir = "characters/\(set)"
        guard let manifest = bundle.url(forResource: "sounds", withExtension: "json",
                                        subdirectory: dir),
              let data = try? Data(contentsOf: manifest),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
        else { return nil }

        for (key, names) in root {
            guard let kind = Kind(rawValue: key) else { continue }
            clips[kind] = names.compactMap {
                bundle.url(forResource: ($0 as NSString).deletingPathExtension,
                           withExtension: "wav", subdirectory: "\(dir)/sounds")
            }
        }
        guard clips.values.contains(where: { !$0.isEmpty }) else { return nil }
    }

    func has(_ kind: Kind) -> Bool { !(clips[kind] ?? []).isEmpty }

    /// Which clip a kind resolves to, before any of it reaches the speakers.
    ///
    /// A set needn't carry all three kinds. Ristar's rip is ten clips of his
    /// voice and nothing else, so there is no thud to play when he takes a
    /// knock — and staying silent at the one moment a noise is called for
    /// reads as a bug. Falls back to whatever the set does have.
    ///
    /// Split out from `play` so the fallback can be tested without playing
    /// anything: asserting it by ear meant a hundred overlapping players, and
    /// `AVAudioPlayer.play()` starts refusing long before the logic is wrong.
    func source(for kind: Kind) -> URL? {
        let wanted = clips[kind]?.isEmpty == false
            ? kind
            : Kind.allCases.first { !(clips[$0] ?? []).isEmpty }
        guard let kind = wanted, let pool = clips[kind], !pool.isEmpty else { return nil }
        var index = Int.random(in: 0..<pool.count)
        if pool.count > 1, index == recent[kind] {
            index = (index + 1) % pool.count
        }
        recent[kind] = index
        return pool[index]
    }

    /// Play one, avoiding whichever was played last so it doesn't repeat.
    ///
    /// Returns whether a clip was *found*, not whether it reached the speakers:
    /// the playing happens on another thread, and the answer to "did the audio
    /// server accept it" arrives too late to be of use to a caller.
    @discardableResult
    func play(_ kind: Kind) -> Bool {
        guard isEnabled, let url = source(for: kind) else { return false }
        let level = volume
        speaker.async { [weak self] in
            guard let self, let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.volume = level
            guard player.play() else { return }
            // Keep a reference until it has finished, and drop the finished ones.
            self.playing.removeAll { !$0.isPlaying }
            self.playing.append(player)
        }
        return true
    }

    func stop() {
        speaker.async { [weak self] in
            self?.playing.forEach { $0.stop() }
            self?.playing.removeAll()
        }
    }
}
