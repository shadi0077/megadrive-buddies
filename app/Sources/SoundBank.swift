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
    private var playing: [AVAudioPlayer] = []
    private var recent: [Kind: Int] = [:]

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

    /// Play one, avoiding whichever was played last so it doesn't repeat.
    ///
    /// A set needn't carry all three kinds. Ristar's rip is ten clips of his
    /// voice and nothing else, so there is no thud to play when he takes a
    /// knock — and staying silent at the one moment a noise is called for
    /// reads as a bug. Falls back to whatever the set does have.
    @discardableResult
    func play(_ kind: Kind) -> Bool {
        guard isEnabled else { return false }
        let wanted = clips[kind]?.isEmpty == false
            ? kind
            : Kind.allCases.first { !(clips[$0] ?? []).isEmpty }
        guard let kind = wanted, let pool = clips[kind], !pool.isEmpty else { return false }
        var index = Int.random(in: 0..<pool.count)
        if pool.count > 1, index == recent[kind] {
            index = (index + 1) % pool.count
        }
        recent[kind] = index

        guard let player = try? AVAudioPlayer(contentsOf: pool[index]) else { return false }
        player.volume = volume
        guard player.play() else { return false }

        // Keep a reference until it has finished, and drop the finished ones.
        playing.removeAll { !$0.isPlaying }
        playing.append(player)
        return true
    }

    func stop() {
        playing.forEach { $0.stop() }
        playing.removeAll()
    }
}
