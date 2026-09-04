import Foundation

/// The Sonic games, Ristar and Fatal Fury 2.
///
/// These come from platformers rather than a beat-'em-up, and it shows in what
/// they can do: Sonic runs, Tails flies, Ristar bounces, and none of them owns
/// a punch. They also arrive without a sound rip, so they go about it silently
/// — the Streets of Rage grunts belong to Streets of Rage.
///
/// Scale is set per character so they stand at sensible heights next to each
/// other. A Mega Drive Sonic is 38 pixels tall and Terry Bogard is 92, and
/// scaling both to one height would be wrong: Sonic really is a small
/// hedgehog. They are nudged toward each other, not flattened.
extension Personality {
    private static func platformer(
        _ id: String, scale: CGFloat, beats: ClosedRange<Double>,
        speed: CGFloat, distance: ClosedRange<CGFloat>, restlessness: Double,
        walk: String = "walk", flourishes: [String], bits: [Bit],
        soundSet: String? = nil, title: String? = nil
    ) -> Personality {
        Personality(
            id: id,
            soundSet: soundSet,
            scale: scale,
            beatRange: beats,
            roaming: .init(distance: distance, speed: speed,
                           restlessness: restlessness),
            walk: walk,
            flourishes: flourishes,
            bits: bits,
            title: title
        )
    }

    private static func moment(_ clip: String) -> Bit {
        .init(intro: clip, loop: nil, outro: nil, hold: 0...0)
    }

    /// Fastest thing on the desktop, and travels on the run cycle rather than
    /// the walk — at 420 points per second a walk would read as a moonwalk.
    static let sonic = platformer("sonic", scale: 2.4, beats: 5...12, speed: 420,
                                  distance: 1000...3600, restlessness: 3.6,
                                  walk: "run",
                                  flourishes: ["walk", "skid", "bored", "lookUp",
                                               "crouch"],
                                  bits: [moment("sit"), moment("bored"),
                                         moment("skid")])

    static let tails = platformer("tails", scale: 2.6, beats: 7...16, speed: 260,
                                  distance: 700...2400, restlessness: 2.8,
                                  flourishes: ["fly", "roll", "walk"],
                                  bits: [moment("fly"), moment("roll")],
                                  title: "Tails")

    static let knuckles = platformer("knuckles", scale: 2.4, beats: 8...18, speed: 240,
                                     distance: 600...2000, restlessness: 2.2,
                                     flourishes: ["run", "roll", "bored"],
                                     bits: [moment("bored"), moment("roll")])

    /// He does not run anywhere quickly, and he laughs at his own jokes.
    static let robotnik = platformer("robotnik", scale: 1.9, beats: 10...22, speed: 120,
                                     distance: 300...1100, restlessness: 1.2,
                                     flourishes: ["laugh", "cheer", "crouch", "hit"],
                                     bits: [moment("laugh"), moment("cheer")],
                                     title: "Dr. Robotnik")

    /// Hovers on his jets, so the idle doubles as the travel clip — the same
    /// trick the Streets of Rage 1 trio use, for the same reason.
    static let mecha = platformer("mecha", scale: 1.8, beats: 9...20, speed: 200,
                                  distance: 600...2000, restlessness: 2.0,
                                  flourishes: ["spin", "dash"],
                                  bits: [moment("spin"), moment("dash")],
                                  title: "Mecha Sonic")

    static let ristar = platformer("ristar", scale: 2.4, beats: 7...15, speed: 190,
                                   distance: 500...1800, restlessness: 2.4,
                                   flourishes: ["jump", "roll", "cheer", "celebrate"],
                                   bits: [moment("cheer"), moment("celebrate"),
                                          moment("jump")])

    /// Pre-rendered rather than drawn, and it shows next to the others — which
    /// is the point of shipping him separately from the Sonic 2 sprite.
    static let sonic3d = platformer("sonic3d", scale: 2.0, beats: 6...14, speed: 300,
                                    distance: 800...2800, restlessness: 3.0,
                                    flourishes: ["walk"],
                                    bits: [moment("walk")],
                                    title: "Sonic (3D Blast)")

    /// The one newcomer who can actually fight, so he keeps the sound set and
    /// squares up like the Streets of Rage cast.
    static let terry = platformer("terry", scale: 1.3, beats: 8...18, speed: 150,
                                  distance: 400...1500, restlessness: 1.8,
                                  flourishes: ["punch", "kick", "highKick", "crouch",
                                               "jump"],
                                  bits: [.init(intro: "knockdown", loop: nil,
                                               outro: nil, hold: 0...0),
                                         moment("highKick")],
                                  soundSet: "_sor2",
                                  title: "Terry Bogard")
}
