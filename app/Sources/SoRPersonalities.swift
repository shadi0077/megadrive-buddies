import Foundation

/// The rest of the Streets of Rage 2 roster.
///
/// All four share one sound set — it's one game's rip — and differ the way the
/// characters do: Blaze is quick and acrobatic, Max is heavy and slow, Skate is
/// on rollerblades and never stops moving.
extension Personality {
    static let blaze = Personality(
        id: "blaze",
        pixelArt: true,
        soundSet: "_sor2",
        scale: 1.55,
        beatRange: 6...14,
        roaming: .init(distance: 600...2200, speed: 190, restlessness: 2.6),
        travel: .hops(cruise: "walk"),
        flourishes: ["punch", "kick", "highKick", "flip", "projectile", "spin"],
        bits: [
            .init(intro: "flip", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "projectile", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "knockdown", loop: nil, outro: nil, hold: 0...0),
        ]
    )

    /// Max Thunder. The id carries his game, because Desktop Buddies has a Max
    /// of its own who reports the news.
    static let maxsor = Personality(
        id: "maxsor",
        pixelArt: true,
        soundSet: "_sor2",
        scale: 1.55,
        beatRange: 11...24,        // he is not a quick man
        roaming: .init(distance: 500...1600, speed: 120, restlessness: 1.6),
        travel: .hops(cruise: "walk"),
        flourishes: ["punch", "flex", "grapple", "slam"],
        bits: [
            .init(intro: "flex", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "grapple", loop: nil, outro: "slam", hold: 0...0),
            .init(intro: "knockdown", loop: nil, outro: nil, hold: 0...0),
        ],
        title: "Max"
    )

    static let skate = Personality(
        id: "skate",
        pixelArt: true,
        soundSet: "_sor2",
        scale: 1.55,
        beatRange: 5...11,         // a teenager on rollerblades
        roaming: .init(distance: 900...3000, speed: 300, restlessness: 3.4),
        travel: .hops(cruise: "walk"),
        flourishes: ["punch", "kick", "flip", "spin", "dash"],
        bits: [
            .init(intro: "dash", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "spin", loop: nil, outro: nil, hold: 0...0),
            .init(intro: "knockdown", loop: nil, outro: nil, hold: 0...0),
        ]
    )
}

/// The Streets of Rage 1 trio and the enemies.
///
/// The enemy rips are small — a handful of poses each — so their repertoire is
/// short and their idle beats are sparse. Better a character who stands there
/// convincingly than one who cycles three frames every four seconds.
extension Personality {
    private static func brawler(
        _ id: String, scale: CGFloat, beats: ClosedRange<Double>,
        speed: CGFloat, distance: ClosedRange<CGFloat>, restlessness: Double,
        flourishes: [String], bits: [Bit], title: String? = nil
    ) -> Personality {
        Personality(
            id: id,
            pixelArt: true,
            soundSet: "_sor2",
            scale: scale,
            beatRange: beats,
            roaming: .init(distance: distance, speed: speed,
                           restlessness: restlessness),
            travel: .hops(cruise: "walk"),
            flourishes: flourishes,
            bits: bits,
            title: title
        )
    }

    private static func hit(_ clip: String) -> Bit {
        .init(intro: clip, loop: nil, outro: nil, hold: 0...0)
    }

    static let adam = brawler("adam", scale: 1.7, beats: 10...22, speed: 130,
                              distance: 300...900, restlessness: 0.8,
                              flourishes: ["punch", "kick", "flip"],
                              bits: [hit("flip"), hit("knockdown")])

    static let axel1 = brawler("axel1", scale: 1.7, beats: 10...22, speed: 130,
                               distance: 300...900, restlessness: 0.8,
                               flourishes: ["punch", "kick", "flip"],
                               bits: [hit("flip"), hit("knockdown")],
                               title: "Axel (1991)")

    static let blaze1 = brawler("blaze1", scale: 1.7, beats: 10...22, speed: 130,
                                distance: 300...900, restlessness: 0.8,
                                flourishes: ["punch", "kick", "flip"],
                                bits: [hit("flip"), hit("knockdown")],
                                title: "Blaze (1991)")

    static let galsia = brawler("galsia", scale: 1.7, beats: 10...22, speed: 150,
                                distance: 400...1400, restlessness: 2.0,
                                flourishes: ["punch"],
                                bits: [.init(intro: "knockdown", loop: nil,
                                             outro: "getUp", hold: 0...0)])

    static let donovan = brawler("donovan", scale: 1.6, beats: 11...24, speed: 130,
                                 distance: 400...1400, restlessness: 1.8,
                                 flourishes: ["punch", "flex"],
                                 bits: [hit("flex"), hit("knockdown")])

    static let eagle = brawler("eagle", scale: 1.6, beats: 10...22, speed: 145,
                               distance: 400...1500, restlessness: 2.0,
                               flourishes: ["kick", "highKick"],
                               bits: [hit("highKick"), hit("knockdown")])

    /// Streets of Rage 3, two years and one art style later. Same man, longer
    /// legs, and a sheet that finally has a proper walk in it.
    static let axel3 = brawler("axel3", scale: 1.5, beats: 7...16, speed: 175,
                               distance: 600...2200, restlessness: 2.4,
                               flourishes: ["punch", "kick", "run"],
                               bits: [hit("knockdown"), hit("kick")],
                               title: "Axel (1994)")

    static let slum = brawler("slum", scale: 1.6, beats: 9...20, speed: 160,
                              distance: 500...1600, restlessness: 2.2,
                              flourishes: ["punch", "attack"],
                              bits: [hit("attack"), hit("knockdown")])
}
