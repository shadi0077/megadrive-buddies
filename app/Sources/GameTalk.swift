import Foundation

/// What they talk about: video games, up to 1997, and nothing after.
///
/// The cutoff is the point of it. These are 16-bit characters standing on a
/// desktop thirty years later, so they talk about the era they came from —
/// arcades, cartridges, the console war, the games that were new to them.
/// Nothing here knows what happened next.
///
/// The facts are facts. Each one is something that actually happened, kept
/// short enough for a speech bubble; where a story is famous but the details
/// are contested, it's phrased as the story it is rather than stated flat.
enum GameTalk {

    struct Joke {
        let setup: String
        let punchline: String
    }

    /// One line of an exchange. `who` names a character when only that
    /// character can say it; nil means anybody can.
    struct Line {
        let who: String?
        let text: String
        init(_ who: String?, _ text: String) { self.who = who; self.text = text }
    }

    // MARK: - Facts

    static let facts: [String] = [
        "Nintendo was founded in 1889. It made playing cards for most of a century before it made a game.",
        "Sega is short for Service Games. It started out supplying coin-op machines to army bases in Japan.",
        "Space Invaders sped up as you shot the aliens because the hardware drew fewer of them faster. The bug shipped as difficulty.",
        "The Konami Code was written by a man porting Gradius to the NES who found his own game too hard to test.",
        "Tetris was written in 1984 by Alexey Pajitnov at the Soviet Academy of Sciences. He saw no royalties for over a decade.",
        "Donkey Kong's hero was called Jumpman. He got the name Mario later, from a landlord.",
        "Pac-Man's ghosts don't all chase you. One follows, one cuts you off, one wanders — that's why the maze feels alive.",
        "Pac-Man was built around eating because Namco wanted a game for people who weren't there to shoot things.",
        "Street Fighter II's combos were an accident. A timing bug let moves chain, and Capcom decided to keep it.",
        "The Mega Drive launched in Japan in 1988. America got it a year later, under the name Genesis.",
        "Sonic was very nearly called Mr Needlemouse.",
        "Sega released Sonic 2 everywhere on one day and called it Sonic 2sday: the 24th of November, 1992.",
        "The spin dash didn't exist in the first Sonic. There was no way to charge a roll standing still.",
        "Doom went out as shareware in 1993 — the first episode free, the rest by post.",
        "Myst has outsold every other PC game of the nineties, and the nineties aren't over yet.",
        "The blood in Mortal Kombat led to a US Senate hearing, and the hearing led to the ESRB in 1994.",
        "The PlayStation started life as a CD add-on Sony was building for the Super Nintendo. Nintendo walked away in 1991.",
        "Sega launched the Saturn in America four months early, announced on stage at E3 1995. Most shops found out that day.",
        "Virtua Fighter, in 1993, was the first fighting game built out of polygons.",
        "Lara Croft was called Laura Cruz in the early drafts of Tomb Raider.",
        "Crash Bandicoot spent development under the working title Willy the Wombat.",
        "Pokémon Red and Green came out in Japan in 1996 — on a Game Boy that was already seven years old.",
        "Final Fantasy VII shipped on three CDs in 1997. The install was optional. The discs were not.",
        "GoldenEye 007 was made at Rare in 1997 by a team where almost nobody had shipped a game before.",
        "They say Atari buried its unsold E.T. cartridges in a New Mexico landfill in 1983. Nobody has dug them up to check.",
        "The story goes that the first Pong cabinet was reported broken, and the fault was a coin box too full to take another quarter.",
        "Metroid, in 1986, revealed Samus as a woman if you finished it quickly enough.",
        "Super Mario Bros. 2 in the West is a reskin of a game called Doki Doki Panic. The Japanese sequel was thought too hard.",
        "The Mega Drive ran on a Motorola 68000 — the same processor family as the first Macintosh.",
        "Blast processing was a marketing phrase. The 68000 in a Mega Drive ran at about 7.6 MHz.",
        "Sonic 3 came with a battery so it could save. Most Mega Drive cartridges had nowhere to put your progress.",
        "Akuma was hidden in Super Street Fighter II Turbo in 1994, behind conditions almost nobody met by accident.",
        "Earthworm Jim's animation was drawn by hand, frame by frame, by animators who had worked in cartoons.",
        "Comix Zone put you inside a comic book, punching through panels the artist was drawing around you.",
        "ToeJam & Earl built its levels at random every time, an idea it borrowed from Rogue.",
        "Michael Jackson's Moonwalker, in 1990, had you rescuing children by dancing at people until they fell over.",
        "Shinobi III gave a ninja a horse in one stage and a surfboard in another, and nobody thought to stop it.",
        "Sparkster of Rocket Knight Adventures is an opossum. Everybody says squirrel.",
        "Treasure — Gunstar Heroes, Dynamite Headdy — was founded in 1992 by staff who had walked out of Konami.",
        "Pulseman was made by Game Freak, three years before the same studio made Pokémon.",
        "The Game Boy launched in 1989 and came bundled in the West with Tetris. It was black and white and it outlived everything.",
        "Street Fighter II was pirated as arcade boards, not discs. Rainbow Edition was a hacked chip, not a patch.",
        "Sonic CD shipped with a different soundtrack in America than in Japan. Both are the real one, depending who you ask.",
        "Nintendo's Game Boy shipped with a link cable, and the killer app for it turned out to be trading.",
        "Arcades charged by the credit, so difficulty was a business model. Home ports had to learn to be fair.",
    ]

    // MARK: - Jokes

    static let jokes: [Joke] = [
        .init(setup: "How many mascots does it take to change a lightbulb?",
              punchline: "Two. One to change it, one to insist their version is faster."),
        .init(setup: "Why did the arcade cabinet never save any money?",
              punchline: "Everything it did cost a quarter."),
        .init(setup: "What's a hedgehog's favourite kind of music?",
              punchline: "Anything with a good loop."),
        .init(setup: "Why can't you trust a boss in a side-scroller?",
              punchline: "There's always a second phase."),
        .init(setup: "What did the 68000 say to the sound chip?",
              punchline: "You handle the music. I'll handle the pressure."),
        .init(setup: "Why did the RPG hero turn down a free room at the inn?",
              punchline: "He'd already saved."),
        .init(setup: "How can you tell a game was made in 1993?",
              punchline: "The blood is behind a code."),
        .init(setup: "What did Tetris say to the gap?",
              punchline: "Don't move. I've got something that fits."),
        .init(setup: "Why did the ghost stop chasing Pac-Man?",
              punchline: "He'd been going round in circles for years and finally noticed."),
        .init(setup: "Why was the platform character so anxious?",
              punchline: "Everywhere he went, the floor was optional."),
        .init(setup: "What's the difference between an arcade and a casino?",
              punchline: "The casino tells you the odds."),
        .init(setup: "Why did the beat-'em-up character eat the roast chicken off the pavement?",
              punchline: "It was in a barrel. That makes it fine."),
        .init(setup: "Why don't fighting-game rivals ever finish a conversation?",
              punchline: "Someone always shouts round two."),
        .init(setup: "What did the sprite say to the palette?",
              punchline: "Don't you change on me."),
        .init(setup: "Why did the ninja bring a surfboard to work?",
              punchline: "Stage four."),
        .init(setup: "What do you call a cartridge you have to blow into?",
              punchline: "Working, eventually."),
        .init(setup: "Why did the shopkeeper in the RPG never leave his shop?",
              punchline: "He was worried about the economy — he'd seen how much people had in their pockets."),
        .init(setup: "How does a 16-bit character apologise?",
              punchline: "Three frames of looking at his shoes."),
        .init(setup: "Why did the racing game character refuse to talk about the ending?",
              punchline: "No spoilers. Literally, the car didn't come with one."),
        .init(setup: "What's the most honest thing in an arcade?",
              punchline: "The high score table. It remembers exactly how bad you were."),
        .init(setup: "Why was the password screen so unpopular?",
              punchline: "Nobody could tell an 8 from a B, and the game knew it."),
        .init(setup: "Why did the mascot get a sequel so quickly?",
              punchline: "Marketing had already printed the cereal."),
        .init(setup: "What did the final boss say to the save point?",
              punchline: "You're new here, aren't you."),
        .init(setup: "Why do old games have such good music?",
              punchline: "When you only get a handful of channels, you have to mean it."),
        .init(setup: "Why did the sprite refuse to be scaled?",
              punchline: "He'd seen what smoothing does to a man."),
        .init(setup: "What's the scariest sound in a coin-op?",
              punchline: "The countdown after you die, when your pocket is empty."),
    ]

    // MARK: - Passing remarks

    static let idle: [String] = [
        "Thirty years and I still can't walk past a coin slot.",
        "The trick to a boss is that it always tells you what it's about to do. Once.",
        "I miss instruction manuals. Somebody drew those.",
        "Everything I know about physics I learned from a spring.",
        "There's no pause in an arcade. That was the whole business.",
        "Cartridge games loaded instantly. I'm not saying it was better. I'm saying it loaded instantly.",
        "Somebody in 1991 decided I should run to the right. I've never questioned it.",
        "You had one life, three continues, and a bus to catch.",
        "Every wall in my game is exactly as thick as the artist felt that morning.",
        "I've been standing here so long the desktop has become a level.",
        "Passwords were forty characters long and case sensitive. On a pad.",
        "The music was written by someone with three channels and a deadline.",
        "In my day the difficulty setting was the arcade owner.",
        "Nobody ever explained the plot. There was a printed page and a lot of guessing.",
        "Someone spent a week animating my blink. Nobody has ever mentioned it.",
        "The best games of my era fit in less memory than this speech bubble.",
        "You could tell the good ports because they kept the arcade's timing.",
        "I have never in my life used a save point that felt generous.",
        "There's a whole generation who has never blown into anything to make it work.",
        "The console war was mostly playgrounds arguing about processors nobody had seen.",
        "Somewhere there's a magazine that gave my game 84%. I think about it.",
        "Two players, one screen, no scrolling apart. That was the deal.",
    ]

    // MARK: - Exchanges

    /// Two-hander conversations. The comedy is in the contrast, and nobody
    /// wins. Character-specific ones only run when both are on screen.
    static let exchanges: [[Line]] = [
        [.init("sonic", "I do the whole level in thirty seconds."),
         .init("knuckles", "Then you've seen none of it."),
         .init("sonic", "I've seen it thirty times.")],

        [.init("ryu", "I travel the world looking for stronger opponents."),
         .init("terry", "I got mine in one city."),
         .init("ryu", "Then you've been lucky with the city.")],

        [.init("toejam", "Do you know where we are?"),
         .init("earl", "No, but the level's random, so neither does anyone."),
         .init("toejam", "That's the most relaxing thing you've ever said.")],

        [.init("axel", "In my game the food is on the floor."),
         .init("blaze", "In a barrel."),
         .init("axel", "In a barrel, on the floor. And it works.")],

        [.init("jim", "I was drawn by hand, frame by frame."),
         .init("sonic", "I was drawn to move fast."),
         .init("jim", "It shows, and I mean that kindly.")],

        [.init("robotnik", "I've built a hundred machines to stop him."),
         .init("sonic", "Ninety-nine."),
         .init("robotnik", "I have one in the shed.")],

        [.init("ristar", "I grab things with my arms. They stretch."),
         .init("knuckles", "I punch things. They don't."),
         .init("ristar", "We should team up. You'd hate it.")],

        [.init("moonwalker", "In my game you rescue children by dancing."),
         .init("ryu", "In mine you punch a man through a car."),
         .init("moonwalker", "Different approaches. Same outcome, arguably.")],

        [.init(nil, "Do you ever wonder what's after 1997?"),
         .init(nil, "Every day. Then I remember the arcade shut and I stop."),
         .init(nil, "Fair.")],

        [.init(nil, "Blast processing."),
         .init(nil, "It was a phrase."),
         .init(nil, "It was a very good phrase.")],

        [.init(nil, "How many hits can you take?"),
         .init(nil, "Three, and then I flash for a bit."),
         .init(nil, "Luxury. I flash and then I'm gone.")],

        [.init(nil, "What's your continue screen like?"),
         .init(nil, "Ten seconds and a countdown."),
         .init(nil, "Mine's nine. They knew what they were doing.")],

        [.init(nil, "I've been thinking about the ending."),
         .init(nil, "Ours is a picture of the sky and the word CONGRATULATION."),
         .init(nil, "Singular?"),
         .init(nil, "Singular.")],

        [.init(nil, "Somebody's watching us through a window."),
         .init(nil, "That's a desktop."),
         .init(nil, "That's what I said. A window.")],

        [.init(nil, "In 1993 everything got a blood code."),
         .init(nil, "In 1994 everything got a rating."),
         .init(nil, "In 1995 everything got polygons and we lost the plot.")],

        [.init(nil, "My whole personality is a walk cycle."),
         .init(nil, "Mine's eight frames of standing still."),
         .init(nil, "That's not less. That's restraint.")],

        [.init(nil, "Do you think anyone still has our cartridge?"),
         .init(nil, "In a box. In a loft. Under a coat."),
         .init(nil, "That's immortality, that.")],

        [.init(nil, "The music in your game was better."),
         .init(nil, "The music in every game was better. Three channels and a man with something to prove.")],

        [.init(nil, "I finished mine without a single continue."),
         .init(nil, "Nobody finished yours without a single continue."),
         .init(nil, "Nobody was watching, either.")],

        [.init(nil, "There's a chicken in a wall in my game."),
         .init(nil, "Whole roast?"),
         .init(nil, "Whole roast. Restores everything. Nobody asks.")],

        [.init(nil, "What's your special move?"),
         .init(nil, "I press two buttons and hope."),
         .init(nil, "That's everyone's special move.")],

        [.init(nil, "They say the arcades are gone."),
         .init(nil, "They say a lot of things."),
         .init(nil, "They said blast processing.")],
    ]

    /// Lines only one character would say. Everyone else draws on `idle`.
    static let personal: [String: [String]] = [
        "sonic": ["I was nearly called Mr Needlemouse. Think about that.",
                  "They shipped my sequel on a Tuesday and named the day after me.",
                  "Rings are just health you can drop everywhere at the worst moment."],
        "knuckles": ["I glide, I climb, I punch. Nobody's ever needed a fourth thing.",
                     "I was in a game with my name on it and I still got tricked."],
        "tails": ["I can fly. Not far, and not for long, but I can fly.",
                  "Two tails. Everyone asks. Yes, they work."],
        "robotnik": ["Every machine I build is defeated by a hedgehog. Every one.",
                     "I have a doctorate. Nobody uses it."],
        "mecha": ["I am what happens when the doctor gets it nearly right."],
        "ristar": ["My arms reach further than you'd think. That's the whole game.",
                   "I came out the same year as some very loud consoles. Nobody noticed me."],
        "terry": ["Are you okay? Buster wolf.",
                  "My hat has been through more than most people."],
        "ryu": ["The answer is always more training.",
                "I fought a man who could throw fire. So can I. We had a lot to discuss."],
        "robert": ["Money never got me a single win in this thing."],
        "musashi": ["A ninja in 1993 got a horse level and a surf level. I earned both."],
        "jim": ["Groovy.",
                "I'm a worm in a suit. The suit does the walking.",
                "They animated me by hand. That's why I move like a cartoon and land like a sack."],
        "toejam": ["We crash-landed. We were fine. We're always fine."],
        "earl": ["I do not run. I have never run. Running is for people who left late."],
        "donald": ["I was in a game about illusions. Half of it wasn't there."],
        "moonwalker": ["The dance was the attack. That's not a metaphor, it's the mechanic."],
        "sparkster": ["Opossum. Not a squirrel. It's on the box."],
        "pulseman": ["The studio that made me went on to make something with monsters in it."],
        "gambit": ["The card does the work. I just have to look like I meant it."],
        "sketch": ["I was drawn into my own comic. The artist was not kind."],
        "axel": ["Grand Upper. Say it properly."],
        "blaze": ["Everyone remembers the kick. Nobody remembers the projectile."],
        "max": ["I am slow because I only need to arrive once."],
        "skate": ["I'm the fast one. Ask anyone who isn't a hedgehog."],
    ]

    // MARK: - Picking

    /// Exchanges both of these two can actually hold: every named line has to
    /// belong to one of them, or half the conversation goes missing.
    static func exchanges(for pair: (String, String)) -> [[Line]] {
        exchanges.filter { lines in
            let named = Set(lines.compactMap(\.who))
            return named.isEmpty || named.isSubset(of: [pair.0, pair.1])
        }
    }

    /// What this character says when it has nothing in particular to say.
    static func smallTalk(for id: String) -> [String] {
        (personal[id] ?? []) + idle
    }
}
