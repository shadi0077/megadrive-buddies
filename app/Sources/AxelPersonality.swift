import Foundation

extension Personality {
    /// Axel Stone, Streets of Rage 2 — the one everybody pictures.
    ///
    /// He stands guard, walks the length of the screen, throws punches and a
    /// Grand Upper, and the game's own sound effects do the talking. Restless,
    /// the way someone squaring up is.
    static let axel = Personality(
        id: "axel",
        soundSet: "_sor2",
        scale: 1.55,               // Mega Drive sprites are small; scale him up
        beatRange: 7...16,
        // He walks, so he covers ground at walking pace and goes a long way
        // with it — across the screen, not a hop and a stop.
        roaming: .init(distance: 600...2200, speed: 165, restlessness: 2.6),
        walk: "walk",

        flourishes: ["punch", "jab", "kick", "highKick", "knee",
                     "grandUpper", "uppercut", "flameArc", "celebrate",
                     "guard", "stretch", "jumpKick"],

        // No costumes to put on and take off. His "bits" are combinations,
        // which is what a beat-'em-up character has instead.
        bits: [
            .init(intro: "guard", loop: nil, outro: "punch", hold: 0...0),
            .init(intro: "stretch", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "knockdown", loop: nil, outro: "getUp", hold: 0...0),
        ]
    )
}
