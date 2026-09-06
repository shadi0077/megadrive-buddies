import Foundation

/// The rest of the Mega Drive shelf: platformers, brawlers and one pop star.
///
/// Only the fighters carry a sound set, and it is the Streets of Rage rip —
/// grunts and thuds suit a man throwing a punch whichever game he came out of.
/// The cartoon characters make no noise, because no rip of their games' sound
/// is to hand and borrowing someone else's is worse than silence.
extension Personality {
    private static func hero(
        _ id: String, scale: CGFloat, beats: ClosedRange<Double>,
        speed: CGFloat, distance: ClosedRange<CGFloat>, restlessness: Double,
        walk: String = "walk", flourishes: [String], bits: [Bit],
        soundSet: String? = nil, title: String? = nil
    ) -> Personality {
        Personality(
            id: id, pixelArt: true, soundSet: soundSet, scale: scale, beatRange: beats,
            roaming: .init(distance: distance, speed: speed,
                           restlessness: restlessness),
            travel: .hops(cruise: walk), flourishes: flourishes,
            bits: bits, title: title)
    }

    private static func moment(_ clip: String) -> Bit {
        .init(intro: clip, loop: nil, outro: nil, hold: 0...0)
    }

    static let jim = hero("jim", scale: 1.9, beats: 7...16, speed: 260,
                          distance: 700...2600, restlessness: 2.6,
                          flourishes: ["whip", "getUp"],
                          bits: [moment("whip"), moment("getUp")],
                          title: "Earthworm Jim")

    static let pulseman = hero("pulseman", scale: 2.1, beats: 7...15, speed: 300,
                               distance: 800...2600, restlessness: 2.8,
                               flourishes: ["attack"],
                               bits: [moment("attack")])

    static let toejam = hero("toejam", scale: 2.5, beats: 8...18, speed: 180,
                             distance: 500...1800, restlessness: 2.2,
                             flourishes: ["dance", "dash"],
                             bits: [moment("dance"), moment("dash")],
                             title: "ToeJam")

    /// Earl of ToeJam &, who does not hurry — that being his entire character.
    /// The id carries the game: Desktop Buddies already has an Earl.
    static let earltje = hero("earltje", scale: 2.0, beats: 12...26, speed: 110,
                              distance: 300...1200, restlessness: 1.1,
                              flourishes: ["walk"],
                              bits: [moment("walk")],
                              title: "Earl")

    static let robert = hero("robert", scale: 1.15, beats: 8...18, speed: 150,
                             distance: 400...1500, restlessness: 1.8,
                             flourishes: ["punch", "kick", "jumpKick", "sweep",
                                          "crouch"],
                             bits: [moment("kick"), moment("sweep")],
                             soundSet: "_sor2", title: "Robert Garcia")

    static let donald = hero("donald", scale: 2.9, beats: 6...14, speed: 210,
                             distance: 600...2000, restlessness: 2.8,
                             flourishes: ["run", "cape", "wave"],
                             bits: [moment("cape"), moment("wave")],
                             title: "Donald Duck")

    /// Walks, obviously. The dance is a flourish and comes up often.
    static let moonwalker = hero("moonwalker", scale: 1.85, beats: 6...14,
                                 speed: 170, distance: 500...2000,
                                 restlessness: 3.0,
                                 flourishes: ["dance", "spin", "kick"],
                                 bits: [moment("dance"), moment("spin")],
                                 title: "Michael Jackson")

    static let gambit = hero("gambit", scale: 1.45, beats: 8...18, speed: 190,
                             distance: 500...1800, restlessness: 2.0,
                             flourishes: ["staff", "strike", "crouch"],
                             bits: [moment("staff"), moment("strike")],
                             soundSet: "_sor2")

    static let sketch = hero("sketch", scale: 1.55, beats: 7...16, speed: 200,
                             distance: 500...1900, restlessness: 2.2,
                             flourishes: ["run", "punch", "throw"],
                             bits: [moment("punch"), moment("throw")],
                             soundSet: "_sor2", title: "Sketch Turner")

    static let ryu = hero("ryu", scale: 1.4, beats: 8...18, speed: 140,
                          distance: 400...1400, restlessness: 1.7,
                          flourishes: ["punch", "uppercut", "crouch", "jump"],
                          bits: [moment("uppercut"), moment("jump")],
                          soundSet: "_sor2")

    static let musashi = hero("musashi", scale: 1.75, beats: 7...16, speed: 210,
                              distance: 600...2200, restlessness: 2.4,
                              flourishes: ["slash", "strike", "throw"],
                              bits: [moment("slash"), moment("throw")],
                              soundSet: "_sor2", title: "Joe Musashi")

    static let sparkster = hero("sparkster", scale: 2.5, beats: 7...15, speed: 240,
                                distance: 700...2400, restlessness: 2.6,
                                flourishes: ["walk"],
                                bits: [moment("walk")])

    /// The Hyperstone Heist four. One rip, one beat-'em-up, four turtles who
    /// differ by weapon and by temper — which is all they ever differed by.
    private static func turtle(_ id: String, scale: CGFloat,
                               beats: ClosedRange<Double>, speed: CGFloat,
                               restlessness: Double, title: String) -> Personality {
        hero(id, scale: scale, beats: beats, speed: speed,
             distance: 500...1900, restlessness: restlessness,
             flourishes: ["strike", "walk"],
             bits: [moment("strike")],
             soundSet: "_sor2", title: title)
    }

    static let raphael = turtle("raphael", scale: 1.95, beats: 6...14, speed: 200,
                                restlessness: 2.6, title: "Raphael")
    static let leonardo = turtle("leonardo", scale: 1.7, beats: 8...18, speed: 175,
                                 restlessness: 2.0, title: "Leonardo")
    static let michelangelo = turtle("michelangelo", scale: 1.85, beats: 6...13,
                                     speed: 195, restlessness: 2.9,
                                     title: "Michelangelo")
    static let donatello = turtle("donatello", scale: 1.9, beats: 9...19, speed: 165,
                                  restlessness: 1.8, title: "Donatello")
}
