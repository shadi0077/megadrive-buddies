import Foundation

// Shared material both characters can draw on, and the songs as note data.
// All of it ships in the bundle: he has no network access and never will.

struct Joke {
    let setup: String
    let punchline: String
}

struct Riddle {
    let question: String
    let answer: String
}

/// One sung note: a syllable, its pitch in semitones above the tonic, and how
/// many beats it occupies.
struct Note {
    let text: String
    let step: Int
    let beats: Double

    init(_ text: String, _ step: Int, _ beats: Double = 1) {
        self.text = text
        self.step = step
        self.beats = beats
    }
}

/// A line of lyric and the notes that carry it. The lyric is what the bubble
/// shows; the notes are what actually gets sung.
struct SongPhrase {
    let lyric: String
    let notes: [Note]
}

struct Song {
    let title: String
    /// Something he says before starting.
    let intro: String
    let secondsPerBeat: Double
    let phrases: [SongPhrase]
    /// Sung tonic in Hz, when this song wants one of its own.
    let root: Double?

    init(title: String, intro: String, secondsPerBeat: Double,
         phrases: [SongPhrase], root: Double? = nil) {
        self.title = title
        self.intro = intro
        self.secondsPerBeat = secondsPerBeat
        self.phrases = phrases
        self.root = root
    }
}

enum Repertoire {

    /// Facts either of them can tell — neither has a claim on octopuses.
    /// Each personality appends its own themed ones to this.
    static let sharedFacts: [String] = [
        "Honey doesn't spoil. Archaeologists have found pots of it thousands of years old, still edible.",
        "Octopuses have three hearts and blue blood.",
        "Bananas are berries. Strawberries are not. Botany is a shambles.",
        "Wombats produce cube-shaped droppings, and nobody has entirely explained why.",
        "There are more possible games of chess than there are atoms in the observable universe.",
        "A day on Venus lasts longer than a year on Venus.",
        "Venus also spins backwards compared with nearly every other planet.",
        "Sharks are older than trees by about a hundred million years.",
        "Cleopatra lived closer in time to the Moon landing than to the building of the Great Pyramid.",
        "The Eiffel Tower is taller in summer. The iron expands in the heat.",
        "Sea otters hold hands while they sleep so they don't drift apart.",
        "Scotland's national animal is the unicorn.",
        "The shortest war on record was over in about forty minutes.",
        "Your stomach lining replaces itself every few days. Otherwise it would digest itself.",
        "Sound travels roughly four times faster in water than in air.",
        "There are more trees on Earth than there are stars in the Milky Way.",
        "The first computer to sing was an IBM 704, in 1961. It sang Daisy Bell.",
        "In 1947 Grace Hopper's team taped a moth into a logbook as the first actual case of a bug being found.",
        "Bit is short for binary digit. The statistician John Tukey coined it.",
        "Ray Tomlinson chose the at sign for email in 1971 because nobody else was using that key.",
        "A googol is a one followed by a hundred zeros. It was named by a nine-year-old.",
        "The first Macintosh shipped in 1984 with a hundred and twenty-eight kilobytes of memory.",
    ]

    /// Riddles work in either voice, so they're shared.
    static let englishRiddles: [Riddle] = [
        Riddle(question: "What has keys but opens no locks?", answer: "A piano."),
        Riddle(question: "What gets wetter the more it dries?", answer: "A towel."),
        Riddle(question: "I speak without a mouth and hear without ears. What am I?",
               answer: "An echo."),
        Riddle(question: "What has hands but cannot clap?", answer: "A clock."),
        Riddle(question: "The more you take, the more you leave behind. What am I?",
               answer: "Footsteps."),
        Riddle(question: "What has a head and a tail, but no body?", answer: "A coin."),
        Riddle(question: "What travels the world while staying in one corner?",
               answer: "A stamp."),
        Riddle(question: "What goes up but never comes down?", answer: "Your age."),
        Riddle(question: "What has many teeth but cannot bite?", answer: "A comb."),
        Riddle(question: "What has one eye but cannot see?", answer: "A needle."),
        Riddle(question: "What can you catch but never throw?", answer: "A cold."),
        Riddle(question: "What has a neck but no head?", answer: "A bottle."),
    ]

    /// The same facts, in the same dialect the rest of the Arabic is written in.
    /// Facts are the one thing that does carry across a translation.
    static let arabicSharedFacts: [String] = [
        "العسل ما يفسد. لقوا علماء الآثار جرار عسل عمرها آلاف السنين ولا زالت صالحة.",
        "الأخطبوط عنده ثلاثة قلوب، ودمه أزرق.",
        "الموز فاكهة عنبية، والفراولة لا. علم النبات فوضى.",
        "فضلات حيوان الومبات على شكل مكعبات، ولين الحين ما أحد فسّرها كامل.",
        "عدد مباريات الشطرنج الممكنة أكثر من عدد الذرات في الكون كله.",
        "اليوم في كوكب الزهرة أطول من السنة فيه.",
        "والزهرة يلف عكس بقية الكواكب.",
        "أسماك القرش أقدم من الشجر بقريب مية مليون سنة.",
        "كليوباترا عاشت أقرب للنزول على القمر منها لبناء الهرم الأكبر.",
        "برج إيفل أطول في الصيف، لأن الحديد يتمدد بالحر.",
        "ثعالب الماي تمسك أيدي بعض وهي نايمة عشان ما تبتعد.",
        "الحيوان الوطني لاسكتلندا وحيد قرن أسطوري، وهذا شي غريب.",
        "أقصر حرب في التاريخ خلصت في قريب أربعين دقيقة.",
        "بطانة معدتك تتجدد كل كم يوم، وإلا هضمت نفسها.",
        "الصوت في الماي أسرع أربع مرات منه في الهوا.",
        "عدد الشجر على الأرض أكثر من عدد النجوم في مجرتنا.",
        "أول حاسوب يغنّي كان آي بي إم ٧٠٤ عام ألف وتسعمئة وواحد وستين.",
        "كلمة بِت اختصار للرقم الثنائي، وقد صاغها الإحصائي جون توكي.",
        "اختار راي توملينسون رمز آت للبريد الإلكتروني عام ألف وتسعمئة وواحد وسبعين، لأن أحدًا لم يكن يستخدم ذلك الزر.",
        "الغوغول هو واحد يتبعه مئة صفر، وقد سمّاه طفل في التاسعة من عمره.",
    ]

    /// Riddles the way they're actually asked — "وش الشي اللي..." rather than
    /// the textbook "ما هو الشيء الذي...".
    static let saudiRiddles: [Riddle] = [
        Riddle(question: "وش الشي اللي كل ما تاخذ منه يكبر؟", answer: "الحفرة."),
        Riddle(question: "وش الشي اللي له أسنان وما يعض؟", answer: "المشط."),
        Riddle(question: "وش الشي اللي يمشي بلا رجول ويبكي بلا عيون؟", answer: "السحاب."),
        Riddle(question: "وش الشي اللي يطلع ولا ينزل أبد؟", answer: "العمر."),
        Riddle(question: "وش الشي اللي يتكلم بلا لسان ويسمع بلا أذن؟", answer: "الصدى."),
        Riddle(question: "وش الشي اللي كل ما نشّفته زاد بلله؟", answer: "المنشفة."),
        Riddle(question: "وش الشي اللي له عين وحدة وما يشوف؟", answer: "الإبرة."),
        Riddle(question: "بيت ما له باب ولا شباك، وش هو؟", answer: "بيت الشعر."),
        Riddle(question: "وش الشي اللي له راس وما له عين؟", answer: "الدبوس."),
        Riddle(question: "وش الشي اللي يلف حول البيت وما يتحرك؟", answer: "السور."),
        Riddle(question: "وش الشي اللي يدخل الماي وما يتبلل؟", answer: "الضو."),
        Riddle(question: "وش الشي اللي كل ما زاد نقص؟", answer: "العمر."),
    ]

    // MARK: - Songs

    /// All well out of copyright. The melodies are approximate — these are
    /// speech synthesisers, not a choir.
    static let peedySongs: [Song] = [
        Song(title: "Daisy Bell",
             intro: "This was the first song a computer ever sang. Nineteen sixty-one.",
             secondsPerBeat: 0.42,
             phrases: [
                SongPhrase(lyric: "Daisy, Daisy,", notes: [
                    Note("Dai", 7, 1.5), Note("sy", 4), Note("Dai", 0, 1.5), Note("sy", 2),
                ]),
                SongPhrase(lyric: "give me your answer do.", notes: [
                    Note("give", 4), Note("me", 5), Note("your", 7),
                    Note("ans", 4, 1.5), Note("wer", 2), Note("do", 0, 2),
                ]),
                SongPhrase(lyric: "I'm half crazy,", notes: [
                    Note("I'm", 7), Note("half", 9), Note("cra", 11, 1.5), Note("zy", 9),
                ]),
                SongPhrase(lyric: "all for the love of you.", notes: [
                    Note("all", 7), Note("for", 5), Note("the", 4),
                    Note("love", 2), Note("of", 4), Note("you", 0, 2),
                ]),
             ]),

        Song(title: "Twinkle, Twinkle",
             intro: "Everybody knows this one. Join in if you like.",
             secondsPerBeat: 0.40,
             phrases: [
                SongPhrase(lyric: "Twinkle, twinkle, little star,", notes: [
                    Note("Twin", 0), Note("kle", 0), Note("twin", 7), Note("kle", 7),
                    Note("lit", 9), Note("tle", 9), Note("star", 7, 2),
                ]),
                SongPhrase(lyric: "how I wonder what you are.", notes: [
                    Note("how", 5), Note("I", 5), Note("won", 4), Note("der", 4),
                    Note("what", 2), Note("you", 2), Note("are", 0, 2),
                ]),
             ]),

        Song(title: "Row Your Boat",
             intro: "A short one. I have a small lung capacity.",
             secondsPerBeat: 0.38,
             phrases: [
                SongPhrase(lyric: "Row, row, row your boat,", notes: [
                    Note("Row", 0, 1.5), Note("row", 0, 1.5), Note("row", 0),
                    Note("your", 2), Note("boat", 4, 2),
                ]),
                SongPhrase(lyric: "gently down the stream.", notes: [
                    Note("gent", 4), Note("ly", 2), Note("down", 4),
                    Note("the", 5), Note("stream", 7, 2),
                ]),
             ]),

        Song(title: "Polly Wolly Doodle",
             intro: "This one has a Polly in it, so I consider it mine.",
             secondsPerBeat: 0.36,
             phrases: [
                SongPhrase(lyric: "Fare thee well, fare thee well,", notes: [
                    Note("Fare", 7), Note("thee", 7), Note("well", 4, 1.5),
                    Note("fare", 7), Note("thee", 7), Note("well", 4, 1.5),
                ]),
                SongPhrase(lyric: "fare thee well my fairy fay.", notes: [
                    Note("fare", 7), Note("thee", 9), Note("well", 7), Note("my", 4),
                    Note("fair", 2), Note("y", 0), Note("fay", 0, 2),
                ]),
             ]),
    ]

    /// Slower and lower, to suit him. Swing Low is on the list for the obvious
    /// reason: he arrives on a vine.
    /// Max's, in his own register. Nothing here overlaps the other two.
    static let maxSongs: [Song] = [
        Song(title: "Old MacDonald",
             intro: "A song about livestock. I have no livestock. Here we go.",
             secondsPerBeat: 0.40,
             phrases: [
                SongPhrase(lyric: "Old MacDonald had a farm,", notes: [
                    Note("Old", 0), Note("Mac", 0), Note("Don", 0), Note("ald", -5),
                    Note("had", 9), Note("a", 9), Note("farm", 7, 2),
                ]),
                SongPhrase(lyric: "E I E I O.", notes: [
                    Note("E", 4), Note("I", 4), Note("E", 2), Note("I", 2), Note("O", 0, 2),
                ]),
                SongPhrase(lyric: "And on that farm he had a bird,", notes: [
                    Note("And", 0), Note("on", 0), Note("that", 0), Note("farm", -5),
                    Note("he", 9), Note("had", 9), Note("a", 7), Note("bird", 7, 1.5),
                ]),
                SongPhrase(lyric: "E I E I O.", notes: [
                    Note("E", 4), Note("I", 4), Note("E", 2), Note("I", 2), Note("O", 0, 2),
                ]),
             ]),

        Song(title: "Frère Jacques",
             intro: "This one is a round. I am one bird, so it will be a straight line.",
             secondsPerBeat: 0.45,
             phrases: [
                SongPhrase(lyric: "Are you sleeping, are you sleeping,", notes: [
                    Note("Are", 0), Note("you", 2), Note("sleep", 4), Note("ing", 0),
                    Note("are", 0), Note("you", 2), Note("sleep", 4), Note("ing", 0),
                ]),
                SongPhrase(lyric: "Brother John, Brother John?", notes: [
                    Note("Bro", 4), Note("ther", 5), Note("John", 7, 2),
                    Note("Bro", 4), Note("ther", 5), Note("John", 7, 2),
                ]),
                SongPhrase(lyric: "Morning bells are ringing,", notes: [
                    Note("Mor", 7), Note("ning", 9), Note("bells", 7), Note("are", 5),
                    Note("ring", 4), Note("ing", 0),
                ]),
                SongPhrase(lyric: "Ding dang dong.", notes: [
                    Note("Ding", 0), Note("dang", -5), Note("dong", 0, 2),
                ]),
             ]),
    ]

    /// Merlin's: older tunes, in the lowest register any of them use.
    static let merlinSongs: [Song] = [
        Song(title: "Greensleeves",
             intro: "This one is nearly five hundred years old. So, roughly, am I.",
             secondsPerBeat: 0.50,
             phrases: [
                SongPhrase(lyric: "Alas my love, you do me wrong,", notes: [
                    Note("A", 0), Note("las", 3), Note("my", 5), Note("love", 7, 1.5),
                    Note("you", 8), Note("do", 7), Note("me", 5), Note("wrong", 2, 2),
                ]),
                SongPhrase(lyric: "to cast me off discourteously.", notes: [
                    Note("to", 0), Note("cast", 2), Note("me", 3), Note("off", 5, 1.5),
                    Note("dis", 3), Note("cour", 2), Note("te", 0), Note("ous", -2),
                    Note("ly", 0, 2),
                ]),
                SongPhrase(lyric: "And I have loved you so long,", notes: [
                    Note("And", 0), Note("I", 3), Note("have", 5), Note("loved", 7, 1.5),
                    Note("you", 8), Note("so", 7), Note("long", 5, 2),
                ]),
             ]),

        Song(title: "Ode to Joy",
             intro: "Beethoven. He was going deaf, and wrote this anyway.",
             secondsPerBeat: 0.44,
             phrases: [
                SongPhrase(lyric: "Joy to thee, thou shining spark,", notes: [
                    Note("Joy", 4), Note("to", 4), Note("thee", 5), Note("thou", 7),
                    Note("shi", 7), Note("ning", 5), Note("spark", 4, 1.5),
                ]),
                SongPhrase(lyric: "daughter of Elysium,", notes: [
                    Note("daugh", 2), Note("ter", 0), Note("of", 0), Note("E", 2),
                    Note("ly", 4), Note("si", 4, 1.5), Note("um", 2, 1.5),
                ]),
             ]),
    ]

    /// Rover's: short, bright, and pitched where an eager dog would sit.
    static let roverSongs: [Song] = [
        Song(title: "Mary Had a Little Lamb",
             intro: "I know one about an animal following someone around. Relatable.",
             secondsPerBeat: 0.38,
             phrases: [
                SongPhrase(lyric: "Mary had a little lamb,", notes: [
                    Note("Ma", 4), Note("ry", 2), Note("had", 0), Note("a", 2),
                    Note("lit", 4), Note("tle", 4), Note("lamb", 4, 1.5),
                ]),
                SongPhrase(lyric: "little lamb, little lamb,", notes: [
                    Note("lit", 2), Note("tle", 2), Note("lamb", 2, 1.5),
                    Note("lit", 4), Note("tle", 7), Note("lamb", 7, 1.5),
                ]),
                SongPhrase(lyric: "Mary had a little lamb,", notes: [
                    Note("Ma", 4), Note("ry", 2), Note("had", 0), Note("a", 2),
                    Note("lit", 4), Note("tle", 4), Note("lamb", 4),
                ]),
                SongPhrase(lyric: "its fleece was white as snow.", notes: [
                    Note("its", 4), Note("fleece", 2), Note("was", 2),
                    Note("white", 4), Note("as", 2), Note("snow", 0, 2),
                ]),
             ]),

        Song(title: "London Bridge",
             intro: "This one's about a bridge falling down. Nobody seems worried.",
             secondsPerBeat: 0.36,
             phrases: [
                SongPhrase(lyric: "London Bridge is falling down,", notes: [
                    Note("Lon", 7), Note("don", 9), Note("Bridge", 7), Note("is", 5),
                    Note("fall", 4), Note("ing", 5), Note("down", 7, 1.5),
                ]),
                SongPhrase(lyric: "falling down, falling down,", notes: [
                    Note("fall", 2), Note("ing", 4), Note("down", 5, 1.5),
                    Note("fall", 4), Note("ing", 5), Note("down", 7, 1.5),
                ]),
                SongPhrase(lyric: "London Bridge is falling down,", notes: [
                    Note("Lon", 7), Note("don", 9), Note("Bridge", 7), Note("is", 5),
                    Note("fall", 4), Note("ing", 5), Note("down", 7),
                ]),
                SongPhrase(lyric: "my fair lady.", notes: [
                    Note("my", 2), Note("fair", 5), Note("la", 4), Note("dy", 0, 2),
                ]),
             ]),
    ]

    /// Clippit's — bright, and short enough that he can't spoil them.
    static let clippySongs: [Song] = [
        Song(title: "Three Blind Mice",
             intro: "It looks like you'd enjoy a song. I've decided you would.",
             secondsPerBeat: 0.40,
             phrases: [
                SongPhrase(lyric: "Three blind mice, three blind mice,", notes: [
                    Note("Three", 4), Note("blind", 2), Note("mice", 0, 2),
                    Note("three", 4), Note("blind", 2), Note("mice", 0, 2),
                ]),
                SongPhrase(lyric: "See how they run, see how they run,", notes: [
                    Note("See", 7), Note("how", 5), Note("they", 5), Note("run", 4, 1.5),
                    Note("see", 7), Note("how", 5), Note("they", 5), Note("run", 4, 1.5),
                ]),
             ]),

        Song(title: "Hot Cross Buns",
             intro: "This is the shortest song I know. You're welcome.",
             secondsPerBeat: 0.44,
             phrases: [
                SongPhrase(lyric: "Hot cross buns, hot cross buns,", notes: [
                    Note("Hot", 4), Note("cross", 2), Note("buns", 0, 2),
                    Note("hot", 4), Note("cross", 2), Note("buns", 0, 2),
                ]),
                SongPhrase(lyric: "one a penny, two a penny,", notes: [
                    Note("one", 0), Note("a", 0), Note("pen", 0), Note("ny", 0),
                    Note("two", 2), Note("a", 2), Note("pen", 2), Note("ny", 2),
                ]),
                SongPhrase(lyric: "hot cross buns.", notes: [
                    Note("hot", 4), Note("cross", 2), Note("buns", 0, 2),
                ]),
             ]),
    ]

    /// Earl's: one song, taken slowly, because that is the point of him.
    static let earlSongs: [Song] = [
        Song(title: "Oh My Darling, Clementine",
             intro: "Slow one. Don't fight it.",
             secondsPerBeat: 0.52,
             phrases: [
                SongPhrase(lyric: "Oh my darling, oh my darling,", notes: [
                    Note("Oh", 0), Note("my", 0), Note("dar", 0, 1.5), Note("ling", -5),
                    Note("oh", 4), Note("my", 4), Note("dar", 4, 1.5), Note("ling", 0),
                ]),
                SongPhrase(lyric: "oh my darling Clementine.", notes: [
                    Note("oh", 0), Note("my", 4), Note("dar", 7), Note("ling", 7),
                    Note("Cle", 5), Note("men", 2), Note("tine", 0, 2),
                ]),
                SongPhrase(lyric: "You are lost and gone forever,", notes: [
                    Note("You", 0), Note("are", 0), Note("lost", 0), Note("and", -5),
                    Note("gone", 4), Note("for", 4), Note("ev", 4), Note("er", 0),
                ]),
             ]),
    ]

    /// F1's: he sings the notes he was given, at the length he was given.
    static let f1Songs: [Song] = [
        Song(title: "Yankee Doodle",
             intro: "A marching tune. I will keep exact time. That is the appeal.",
             secondsPerBeat: 0.36,
             phrases: [
                SongPhrase(lyric: "Yankee Doodle went to town,", notes: [
                    Note("Yan", 0), Note("kee", 0), Note("Doo", 2), Note("dle", 4),
                    Note("went", 0), Note("to", 4), Note("town", 2, 1.5),
                ]),
                SongPhrase(lyric: "riding on a pony,", notes: [
                    Note("ri", 0), Note("ding", 0), Note("on", 2), Note("a", 4),
                    Note("po", 0, 1.5), Note("ny", -1, 1.5),
                ]),
                SongPhrase(lyric: "Yankee Doodle keep it up,", notes: [
                    Note("Yan", 0), Note("kee", 2), Note("Doo", 4), Note("dle", 5),
                    Note("keep", 7), Note("it", 5), Note("up", 4, 1.5),
                ]),
             ]),
    ]

    /// Manma's: quiet, and the highest register any of them sing in.
    static let manmaSongs: [Song] = [
        Song(title: "Sakura",
             intro: "An old one about cherry blossom. It's a little sad. Most of them are.",
             secondsPerBeat: 0.54,
             phrases: [
                SongPhrase(lyric: "Sakura, sakura,", notes: [
                    Note("Sa", 0), Note("ku", 0), Note("ra", 2, 2),
                    Note("sa", 0), Note("ku", 0), Note("ra", 2, 2),
                ]),
                SongPhrase(lyric: "across the spring sky,", notes: [
                    Note("a", 2), Note("cross", 3), Note("the", 5),
                    Note("spring", 3), Note("sky", 2, 2),
                ]),
                SongPhrase(lyric: "as far as the eye can see.", notes: [
                    Note("as", 5), Note("far", 7), Note("as", 8), Note("the", 7),
                    Note("eye", 5), Note("can", 3), Note("see", 2, 2),
                ]),
             ]),
    ]

    static let bonziSongs: [Song] = [
        Song(title: "Swing Low, Sweet Chariot",
             intro: "This one's about swinging. I feel qualified.",
             secondsPerBeat: 0.52,
             phrases: [
                SongPhrase(lyric: "Swing low, sweet chariot,", notes: [
                    Note("Swing", 7, 1.5), Note("low", 4, 1.5), Note("sweet", 0),
                    Note("cha", 4), Note("ri", 7), Note("ot", 7, 2),
                ]),
                SongPhrase(lyric: "coming for to carry me home.", notes: [
                    Note("com", 9), Note("ing", 7), Note("for", 4), Note("to", 4),
                    Note("car", 2), Note("ry", 4), Note("me", 2), Note("home", 0, 2),
                ]),
             ]),

        Song(title: "Coming Round the Mountain",
             intro: "Long song. I'll do the good bit.",
             secondsPerBeat: 0.44,
             phrases: [
                SongPhrase(lyric: "She'll be coming round the mountain", notes: [
                    Note("She'll", 0), Note("be", 0), Note("com", 0), Note("ing", 4),
                    Note("round", 7), Note("the", 7), Note("moun", 4), Note("tain", 4),
                ]),
                SongPhrase(lyric: "when she comes.", notes: [
                    Note("when", 2), Note("she", 4), Note("comes", 0, 2),
                ]),
             ]),

        Song(title: "Michael Row the Boat Ashore",
             intro: "Steady one. Everything I do is steady.",
             secondsPerBeat: 0.50,
             phrases: [
                SongPhrase(lyric: "Michael, row the boat ashore,", notes: [
                    Note("Mi", 0), Note("chael", 4), Note("row", 7), Note("the", 7),
                    Note("boat", 9), Note("a", 7), Note("shore", 4, 2),
                ]),
                SongPhrase(lyric: "hallelujah.", notes: [
                    Note("hal", 4), Note("le", 2), Note("lu", 0), Note("jah", 0, 2),
                ]),
             ]),
    ]

    /// Written for this, rather than borrowed. Almost every Arabic song anyone
    /// would recognise is firmly in copyright, and a desktop toy is no place to
    /// find out where the line is — so these are simple original ditties, built
    /// from whole short words the synthesiser pronounces cleanly on their own.
    static let peedyArabicSongs: [Song] = [
        Song(title: "يا هلا",
             intro: "أغنية قصيرة، ألّفتها بنفسي. لا تنتقدني كثير.",
             secondsPerBeat: 0.46,
             phrases: [
                SongPhrase(lyric: "يا هلا، يا هلا", notes: [
                    Note("يا", 0), Note("هلا", 4), Note("يا", 7), Note("هلا", 4),
                ]),
                SongPhrase(lyric: "يا هلا بالغالي", notes: [
                    Note("يا", 7), Note("هلا", 9), Note("بالغالي", 7, 2),
                ]),
             ]),

        Song(title: "وين القهوة",
             intro: "هذي أغنية شكوى.",
             secondsPerBeat: 0.44,
             phrases: [
                SongPhrase(lyric: "وين القهوة؟", notes: [
                    Note("وين", 7), Note("القهوة", 4, 2),
                ]),
                SongPhrase(lyric: "ما حد يدري", notes: [
                    Note("ما", 4), Note("حد", 2), Note("يدري", 0, 2),
                ]),
             ]),
    ]

    /// Max's, in the same original vein — a bulletin that turns into a tune.
    static let maxSongsArabic: [Song] = [
        Song(title: "نشرة قصيرة",
             intro: "نشرة اليوم... بس بالغناء.",
             secondsPerBeat: 0.42,
             phrases: [
                SongPhrase(lyric: "نشرة، نشرة", notes: [
                    Note("نشرة", 0), Note("نشرة", 4),
                ]),
                SongPhrase(lyric: "ما في أخبار", notes: [
                    Note("ما", 7), Note("في", 5), Note("أخبار", 4, 2),
                ]),
                SongPhrase(lyric: "كل شي تمام", notes: [
                    Note("كل", 4), Note("شي", 2), Note("تمام", 0, 2),
                ]),
             ]),

        Song(title: "تنبيه",
             intro: "أغنية عن التنبيهات. قصيرة، مثلها.",
             secondsPerBeat: 0.40,
             phrases: [
                SongPhrase(lyric: "تنبيه، تنبيه", notes: [
                    Note("تنبيه", 7), Note("تنبيه", 9),
                ]),
                SongPhrase(lyric: "ولا شي جديد", notes: [
                    Note("ولا", 7), Note("شي", 4), Note("جديد", 0, 2),
                ]),
                SongPhrase(lyric: "نشرة ثانية", notes: [
                    Note("نشرة", 4), Note("ثانية", 5, 2),
                ]),
                SongPhrase(lyric: "وكل شي هادي", notes: [
                    Note("وكل", 7), Note("شي", 5), Note("هادي", 0, 2),
                ]),
             ]),
    ]

    /// Merlin's, written for this — slow, and pitched at the bottom of him.
    static let merlinSongsArabic: [Song] = [
        Song(title: "على مهل",
             intro: "أغنية قديمة... ألّفتها توّي.",
             secondsPerBeat: 0.52,
             phrases: [
                SongPhrase(lyric: "على مهل، على مهل", notes: [
                    Note("على", 0), Note("مهل", 3), Note("على", 5), Note("مهل", 3),
                ]),
                SongPhrase(lyric: "الوقت طويل", notes: [
                    Note("الوقت", 5), Note("طويل", 0, 2),
                ]),
             ]),

        Song(title: "الصبر",
             intro: "أغنية عن الصبر. طويلة، طبعاً.",
             secondsPerBeat: 0.50,
             phrases: [
                SongPhrase(lyric: "الصبر مفتاح", notes: [
                    Note("الصبر", 0), Note("مفتاح", 5, 2),
                ]),
                SongPhrase(lyric: "والفرج قريب", notes: [
                    Note("والفرج", 7), Note("قريب", 3, 2),
                ]),
                SongPhrase(lyric: "لا تستعجل", notes: [
                    Note("لا", 5), Note("تستعجل", 3, 2),
                ]),
                SongPhrase(lyric: "كل شي بوقته", notes: [
                    Note("كل", 3), Note("شي", 2), Note("بوقته", 0, 2),
                ]),
             ]),
    ]

    /// Rover's, written for this. Short lines, because he cannot hold a note.
    static let roverSongsArabic: [Song] = [
        Song(title: "دور دور",
             intro: "أغنية عن الدوران والبحث. تخصصي.",
             secondsPerBeat: 0.38,
             phrases: [
                SongPhrase(lyric: "دور، دور", notes: [
                    Note("دور", 0), Note("دور", 4),
                ]),
                SongPhrase(lyric: "وأنا ألقاه", notes: [
                    Note("وأنا", 7), Note("ألقاه", 4, 2),
                ]),
                SongPhrase(lyric: "ما يضيع شي", notes: [
                    Note("ما", 4), Note("يضيع", 2), Note("شي", 0, 2),
                ]),
             ]),

        Song(title: "وينك",
             intro: "أغنية قصيرة. أنا كلبي، ما أطوّل.",
             secondsPerBeat: 0.36,
             phrases: [
                SongPhrase(lyric: "وينك، وينك", notes: [
                    Note("وينك", 7), Note("وينك", 5),
                ]),
                SongPhrase(lyric: "أنا هنا", notes: [
                    Note("أنا", 4), Note("هنا", 0, 2),
                ]),
                SongPhrase(lyric: "أدوّر وألقى", notes: [
                    Note("أدوّر", 4), Note("وألقى", 7, 2),
                ]),
                SongPhrase(lyric: "وأرجع لك", notes: [
                    Note("وأرجع", 5), Note("لك", 0, 2),
                ]),
             ]),
    ]

    /// The four Office assistants who came late to the cast, in Arabic —
    /// short original ditties, like the others.
    static let clippySongsArabic: [Song] = [
        Song(title: "ورقة وقلم",
             intro: "أغنية قصيرة... يبدو إنك تبغى تسمعها.",
             secondsPerBeat: 0.40,
             phrases: [
                SongPhrase(lyric: "ورقة وقلم", notes: [
                    Note("ورقة", 4), Note("وقلم", 0, 2),
                ]),
                SongPhrase(lyric: "وأنا أساعد", notes: [
                    Note("وأنا", 7), Note("أساعد", 4, 2),
                ]),
                SongPhrase(lyric: "تبغى قائمة؟", notes: [
                    Note("تبغى", 5), Note("قائمة", 7, 2),
                ]),
                SongPhrase(lyric: "أنا جاهز", notes: [
                    Note("أنا", 4), Note("جاهز", 0, 2),
                ]),
             ]),
    ]

    static let earlSongsArabic: [Song] = [
        Song(title: "على راحتك",
             intro: "أغنية بطيئة... ما في داعي نستعجل.",
             secondsPerBeat: 0.52,
             phrases: [
                SongPhrase(lyric: "على راحتك", notes: [
                    Note("على", 0), Note("راحتك", 4, 2),
                ]),
                SongPhrase(lyric: "الدنيا ما تروح", notes: [
                    Note("الدنيا", 5), Note("ما", 2), Note("تروح", 0, 2),
                ]),
             ]),
    ]

    static let f1SongsArabic: [Song] = [
        Song(title: "واحد اثنين",
             intro: "أغنية بإيقاع منتظم. هذا اللي يعجبني فيها.",
             secondsPerBeat: 0.36,
             phrases: [
                SongPhrase(lyric: "واحد، اثنين", notes: [
                    Note("واحد", 0), Note("اثنين", 4),
                ]),
                SongPhrase(lyric: "كل شي تمام", notes: [
                    Note("كل", 7), Note("شي", 4), Note("تمام", 0, 2),
                ]),
                SongPhrase(lyric: "ثلاثة، أربعة", notes: [
                    Note("ثلاثة", 5), Note("أربعة", 7),
                ]),
                SongPhrase(lyric: "الحالة سليمة", notes: [
                    Note("الحالة", 4), Note("سليمة", 0, 2),
                ]),
             ]),
    ]

    static let manmaSongsArabic: [Song] = [
        Song(title: "كل زين",
             intro: "أغنية صغيرة... عن الأكل، طبعاً.",
             secondsPerBeat: 0.50,
             phrases: [
                SongPhrase(lyric: "كل زين", notes: [
                    Note("كل", 0), Note("زين", 3, 2),
                ]),
                SongPhrase(lyric: "وارتاح شوي", notes: [
                    Note("وارتاح", 5), Note("شوي", 2, 2),
                ]),
                SongPhrase(lyric: "الشاي جاهز", notes: [
                    Note("الشاي", 3), Note("جاهز", 5, 2),
                ]),
                SongPhrase(lyric: "والليل طويل", notes: [
                    Note("والليل", 3), Note("طويل", 0, 2),
                ]),
             ]),
    ]

    /// Slower and lower, like everything else he does.
    static let bonziArabicSongs: [Song] = [
        Song(title: "على مهلي",
             intro: "أغنية بطيئة. تناسبني.",
             secondsPerBeat: 0.58,
             phrases: [
                SongPhrase(lyric: "على مهلي، على مهلي", notes: [
                    Note("على", 0), Note("مهلي", 4, 2), Note("على", 0), Note("مهلي", 2, 2),
                ]),
                SongPhrase(lyric: "ما أستعجل أبد", notes: [
                    Note("ما", 4), Note("أستعجل", 2, 2), Note("أبد", 0, 2),
                ]),
             ]),

        Song(title: "الموز",
             intro: "هذي عن الموز. أغلب أغانيّ عن الموز.",
             secondsPerBeat: 0.54,
             phrases: [
                SongPhrase(lyric: "موز، موز، موز طيب", notes: [
                    Note("موز", 0), Note("موز", 4), Note("موز", 7), Note("طيب", 4, 2),
                ]),
                SongPhrase(lyric: "كل يوم آكل موز", notes: [
                    Note("كل", 7), Note("يوم", 9), Note("آكل", 7), Note("موز", 0, 2),
                ]),
             ]),
    ]
}
