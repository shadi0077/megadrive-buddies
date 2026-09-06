import Foundation

/// Everything a character says in one language, plus how they sound saying it.
///
/// The two languages aren't translations of each other. Puns don't survive
/// translation, so the Arabic jokes are Arabic jokes; only the facts carry
/// across, because facts are facts.
struct SpeechPack {
    /// The character's name in this language.
    let name: String
    /// Preferred voice identifiers, best first.
    let voiceOrder: [String]
    /// Regional variants to fall back to, best first — "ar-SA" before "ar-001".
    let preferredLocales: [String]
    let pitch: Voice.Pitch
    let rate: Float
    /// Sung tonic in Hz.
    let singingRoot: Double

    let greetings: [String]
    let idle: [String]
    let poked: [String]
    let pokedAgain: [String]
    let dropped: [String]
    let leaving: [String]
    let welcomeBack: [String]
    let noticed: [String]
    let timeOfDay: [String]
    /// Keyed by `Personality.Bit.talk`.
    let byBit: [String: [String]]
    let jokes: [Joke]
    let facts: [String]
    let riddles: [Riddle]
    let twisters: [String]
    let songs: [Song]

    /// The voice this pack would like.
    ///
    /// A named voice wins if it's installed; otherwise the best regional match.
    /// That ordering means the app upgrades itself: macOS exposes only the
    /// world-Arabic voice today, but install a Saudi one and it gets picked up
    /// with no code change.
    ///
    /// A pack that can find no voice for its language returns nil, and the
    /// language isn't offered — reciting Arabic through an English synthesiser
    /// doesn't fail, it spells it out, unintelligibly.
    var preferredVoice: String? {
        for id in voiceOrder where Voice.installed(id) { return id }
        for locale in preferredLocales {
            if let match = Voice.bestVoice(forLocale: locale) { return match }
        }
        return nil
    }
}

/// Whether the system has a given voice installed.
func AVSpeechVoiceExists(_ identifier: String) -> Bool {
    Voice.installed(identifier)
}

/// Everything that makes one character not the other, independent of language:
/// how big they are, how they move, which clips they reach for, how often.
///
/// The two are deliberately opposed. Peedy is quick, fussy and theatrical —
/// lots of small movements. Bonzi is slow, heavy and unbothered, with a strong
/// preference for sitting down. Putting them on one desktop should feel like a
/// double act.
struct Personality {
    let id: String

    /// True for sprite rips from games: pixel art, scaled without smoothing,
    /// and drawn with a hard-edged speech box rather than a soft balloon.
    var pixelArt: Bool = false

    /// Folder its sound effects come from, when it has one. Shared between
    /// characters out of the same game, since it's one game's rip.
    var soundSet: String? = nil

    /// Scale relative to the sprite canvas, so the two end up sensibly sized
    /// next to each other rather than at whatever their sheets happened to be.
    let scale: CGFloat
    /// Seconds between idle beats, before energy and chattiness scale them.
    let beatRange: ClosedRange<Double>
    let roaming: Roaming
    let travel: Travel
    let flourishes: [String]
    let bits: [Bit]

    /// What they say, per language. Empty for the characters who don't talk —
    /// the sprite rips, who have sound effects and speech boxes instead.
    var packs: [Language: SpeechPack] = [:]

    /// A clip to loop while speaking, for the characters whose sprite sets
    /// have no mouth patches to composite. Nil means lip-sync as usual.
    var talkLoop: String? = nil

    /// Shown in the menu when the id isn't presentable on its own — the two
    /// 1991 brawlers, or a character whose id carries its game because the
    /// other product in this repository already has that name.
    var title: String? = nil

    enum Travel {
        /// Takeoff, a looping cruise, then a landing.
        case flies(takeoff: String, cruise: String, land: String)
        /// No takeoff or landing — just a clip to play while moving.
        case hops(cruise: String)

        var cruise: String {
            switch self {
            case .flies(_, let c, _), .hops(let c): return c
            }
        }
    }

    /// How far and how fast they move about.
    ///
    /// A flying parrot crosses a gap; someone walking crosses the room. Tying
    /// speed to the character matters more than it sounds: a walk cycle played
    /// while the window jumps 500 points in half a second reads as moonwalking,
    /// which is exactly what it looked like before this existed.
    struct Roaming {
        /// How far a single wander goes, in points.
        let distance: ClosedRange<CGFloat>
        /// Points per second while travelling.
        let speed: CGFloat
        /// How high the arc lifts at the midpoint. Flight arcs; walking doesn't.
        let arc: CGFloat
        /// How much of the idle rotation goes on moving about. Someone who
        /// walks for a living should be pacing, not standing.
        let restlessness: Double

        init(distance: ClosedRange<CGFloat>, speed: CGFloat, arc: CGFloat = 0,
             restlessness: Double = 1) {
            self.distance = distance
            self.speed = speed
            self.arc = arc
            self.restlessness = restlessness
        }
    }


    /// A "bit" is an intro, a loop to sit in, and an outro to undo it.
    struct Bit {
        let intro: String
        let loop: String?
        let outro: String?
        let hold: ClosedRange<Double>
        /// Key into `SpeechPack.byBit`. Empty for characters with no speech
        /// pack: a bit they perform without a word about it.
        var talk: String = ""
        /// Talk pose to lip-sync in, or nil when the sprite set has no mouth
        /// patches for this costume — they speak with a still mouth rather than
        /// snapping to a bare pose.
        var pose: String? = nil
    }

    /// English is the fallback: every speaking character has it, and a
    /// half-translated character is worse than one that stays in a language it
    /// knows. Characters who don't speak return nil.
    func pack(_ language: Language) -> SpeechPack? {
        packs[language] ?? packs[.english]
    }

    /// Everyone here is a Microsoft Agent character with mouth patches, so
    /// this is really "has anything to say" — a character with no pack at all
    /// still animates, it just never opens its mouth.
    var speaks: Bool { !packs.isEmpty }

    /// Languages this character can actually speak — a pack is only usable if
    /// the system has a voice for it. A silent character speaks all of them
    /// equally well, which is to say not at all, so it never constrains the
    /// choice.
    func languages() -> [Language] {
        guard speaks else { return Language.allCases }
        return Language.allCases.filter { packs[$0]?.preferredVoice != nil }
    }

    /// Every character here has a speech pack, which is where the name comes
    /// from — in whichever language they're speaking. The id is a fallback for
    /// a character whose pack hasn't been written yet.
    var name: String { title ?? pack(.english)?.name ?? id.capitalized }

    /// Everyone this build ships. The full roster lives in `everyone`; a
    /// product manifest picks from it.
    /// Everyone this repository has, across both apps. A product manifest
    /// picks from it, and nothing else decides who ships.
    /// Everyone this build ships.
    ///
    /// Generated by `tools/publish.py` when this repository was exported
    /// from the shared one. Edit it there, not here.
    static let everyone: [Personality] = [
        .axel,
        .blaze,
        .maxsor,
        .skate,
        .adam,
        .axel1,
        .blaze1,
        .galsia,
        .donovan,
        .eagle,
        .slum,
        .sonic,
        .tails,
        .knuckles,
        .robotnik,
        .mecha,
        .ristar,
        .terry,
        .sonic3d,
        .jim,
        .pulseman,
        .toejam,
        .earltje,
        .donald,
        .moonwalker,
        .sparkster,
        .robert,
        .ryu,
        .musashi,
        .gambit,
        .sketch,
        .raphael,
        .leonardo,
        .michelangelo,
        .donatello,
        .axel3,
        .spinball,
    ]

    static let all: [Personality] = {
        let wanted = Product.current.cast
        guard !wanted.isEmpty else { return everyone }
        // Manifest order, so the menu lists them the way the product intends.
        return wanted.compactMap { id in everyone.first { $0.id == id } }
    }()

    /// Falls back to whoever this build ships first, rather than to a
    /// character by name. `.peedy` was the fallback, which is fine while every
    /// build contains him and a compile error the moment one doesn't — an app
    /// exported for a single product carries only its own cast.
    static func named(_ id: String) -> Personality {
        if let match = all.first(where: { $0.id == id }) { return match }
        return all.first ?? everyone[0]
    }
}
