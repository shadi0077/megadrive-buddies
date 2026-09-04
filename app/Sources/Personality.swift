import Foundation

/// Everything that makes one brawler not the other: how big they are, how far
/// and how fast they walk, which moves they reach for, and how often.
///
/// Nobody here talks. These are beat-'em-up sprite rips — no mouth frames, no
/// visemes, nothing to say — so the differences that matter are physical ones.
/// Blaze is quick and acrobatic, Max is heavy and slow, Skate is on
/// rollerblades and never stops moving.
struct Personality {
    let id: String

    /// Folder its sound effects come from. Shared between characters out of
    /// the same game, since it's one game's rip.
    let soundSet: String

    /// Scale relative to the sprite canvas. Mega Drive sprites are small, and
    /// the rips aren't all at the same scale, so this is what makes them
    /// sensibly sized next to each other.
    let scale: CGFloat
    /// Seconds between idle beats, before energy and liveliness scale them.
    let beatRange: ClosedRange<Double>
    let roaming: Roaming
    /// The clip to loop while walking somewhere.
    let walk: String
    let flourishes: [String]
    let bits: [Bit]

    /// Shown in the menu, when the id isn't presentable on its own. Both games
    /// have an Axel and a Blaze, seven years apart.
    var title: String? = nil

    /// How far and how fast they move about.
    ///
    /// Tying speed to the character matters more than it sounds: a walk cycle
    /// played while the window jumps 500 points in half a second reads as
    /// moonwalking, which is exactly what it looked like before this existed.
    struct Roaming {
        /// How far a single walk goes, in points.
        let distance: ClosedRange<CGFloat>
        /// Points per second while travelling.
        let speed: CGFloat
        /// How much of the idle rotation goes on moving about. Someone who
        /// walks for a living should be pacing, not standing.
        let restlessness: Double
    }

    /// A "bit" is an intro, a loop to sit in, and an outro to undo it. For
    /// these characters it's a combination rather than a costume: guard then
    /// punch, knocked down then back up.
    struct Bit {
        let intro: String
        let loop: String?
        let outro: String?
        let hold: ClosedRange<Double>
    }

    var name: String { title ?? id.capitalized }

    /// Everyone this build ships. The product manifest picks from it, which is
    /// what lets a second app exist without touching any of this.
    static let everyone: [Personality] = [
        .axel, .blaze, .max, .skate,          // Streets of Rage 2
        .adam, .axel1, .blaze1,               // Streets of Rage 1
        .galsia, .donovan, .eagle, .slum,     // enemies
    ]

    static let all: [Personality] = {
        let wanted = Product.current.cast
        guard !wanted.isEmpty else { return everyone }
        // Manifest order, so the menu lists them the way the product intends.
        return wanted.compactMap { id in everyone.first { $0.id == id } }
    }()

    static func named(_ id: String) -> Personality {
        all.first { $0.id == id } ?? .axel
    }
}
