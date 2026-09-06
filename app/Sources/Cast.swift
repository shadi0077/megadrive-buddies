import AppKit

/// One character, fully assembled: sprites, window, animator, brain, voice.
final class Buddy {
    let personality: Personality
    let store: SpriteStore
    let window: BuddyWindow
    let animator: Animator
    let brain: Brain

    init?(personality: Personality, language: Language, scale: CGFloat) {
        guard let store = SpriteStore(character: personality.id) else { return nil }
        self.personality = personality
        self.store = store
        window = BuddyWindow(store: store, scale: scale * personality.scale)
        window.buddyView.pixelArt = personality.pixelArt
        animator = Animator(store: store, view: window.buddyView)
        animator.talkLoop = personality.talkLoop
        brain = Brain(personality: personality, language: language, store: store,
                      animator: animator, window: window)
        store.warm(["rest", "arrive", personality.travel.cruise, "greet", "blink"])
    }

    var id: String { personality.id }
    var isVisible: Bool { brain.isVisible }

    func start() { animator.start() }
    func stop() { animator.stop() }
}

/// Who is on screen, and what happens when there is more than one of them.
final class Cast {
    private(set) var buddies: [Buddy] = []
    private var timer: Timer?

    /// True while an exchange is running, so nothing else grabs them.
    private(set) var talking = false
    private var nextBanter = Date().addingTimeInterval(35)
    private var recentBanter = RecentPicks(limit: 6)

    var chattiness: Chattiness = .occasional {
        didSet { buddies.forEach { $0.brain.chattiness = chattiness } }
    }

    var liveliness: Liveliness = .occasional {
        didSet { buddies.forEach { $0.brain.liveliness = liveliness } }
    }

    private(set) var language: Language

    init(language: Language, scale: CGFloat) {
        self.language = language
        for personality in Personality.all {
            if let buddy = Buddy(personality: personality, language: language, scale: scale) {
                buddies.append(buddy)
            }
        }
        buddies.forEach { $0.start() }

        // Nobody starts a line while somebody else is finishing one.
        for buddy in buddies {
            // Strictly "is somebody else mid-sentence". It must stay true for
            // whoever currently holds the floor, or a character delivering a
            // banter line would block on himself.
            buddy.brain.mayStartTalking = { [weak self, weak buddy] in
                guard let self, let buddy else { return true }
                return !self.onScreen.contains {
                    $0.id != buddy.id && $0.brain.isSpeakingNow
                }
            }
        }

        // One slow tick is plenty; the characters run their own 60 Hz clocks.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func buddy(_ id: String) -> Buddy? { buddies.first { $0.id == id } }

    /// Switch everyone over at once — a bilingual pair would be odd.
    func speak(_ language: Language) {
        guard language != self.language else { return }
        self.language = language
        talking = false
        buddies.forEach { $0.brain.speak(language) }
    }

    /// Languages every character on screen can actually speak. A language with
    /// no installed voice isn't offered at all.
    var availableLanguages: [Language] {
        // A character who doesn't speak never rules a language out.
        Language.allCases.filter { language in
            buddies.allSatisfy {
                !$0.personality.speaks
                    || $0.personality.packs[language]?.preferredVoice != nil
            }
        }
    }
    var onScreen: [Buddy] { buddies.filter(\.isVisible) }
    var activeIDs: Set<String> { Set(onScreen.map(\.id)) }

    // MARK: - Coming and going

    func show(_ id: String, at point: NSPoint? = nil) {
        guard let buddy = buddy(id), !buddy.isVisible else { return }
        buddy.brain.appear(at: point ?? spot(for: buddy))
    }

    /// Bring several on, staggered — arriving together means greeting together,
    /// and two voices at once is just noise.
    func showAll(_ ids: [String], savedOrigin: @escaping (String) -> NSPoint?) {
        for (n, id) in ids.enumerated() {
            let delay = Double(n) * 3.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.show(id, at: savedOrigin(id))
            }
        }
    }

    func hide(_ id: String) {
        buddy(id)?.brain.vanish()
    }

    /// A starting position that doesn't land on top of whoever is already out.
    private func spot(for buddy: Buddy) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let vf = screen.visibleFrame
        let size = buddy.window.frame.size
        let taken = onScreen.filter { $0.id != buddy.id }.map(\.window.frame)

        // Try a few slots along the bottom, right to left, and take the first
        // that isn't already occupied.
        for slot in 0..<4 {
            let x = vf.maxX - size.width - 60 - CGFloat(slot) * (size.width + 70)
            let candidate = NSRect(x: max(x, vf.minX + 8), y: vf.minY + 40,
                                   width: size.width, height: size.height)
            if !taken.contains(where: { $0.intersects(candidate.insetBy(dx: -30, dy: -30)) }) {
                return candidate.origin
            }
        }
        return NSPoint(x: vf.midX - size.width / 2, y: vf.minY + 40)
    }

    // MARK: - Them talking to each other

    private func tick() {
        guard !talking, !fighting else { return }
        let present = onScreen
        guard present.count > 1 else {
            nextBanter = Date().addingTimeInterval(20)
            nextFight = Date().addingTimeInterval(20)
            return
        }
        guard present.allSatisfy({ $0.brain.isAvailable }) else { return }

        // The Agent characters have written exchanges keyed to who they are.
        // The sprite rips talk out of a shared pool and settle their
        // differences physically, on a clock of its own so that talking and
        // fighting don't starve each other.
        if present.contains(where: { $0.personality.speaks }) {
            guard Date() >= nextBanter else { return }
            startBanter()
            return
        }
        if Date() >= nextBanter, chattiness != .quiet, startGameBanter() { return }
        guard Date() >= nextFight else { return }
        var closest = CGFloat.infinity
        for a in present {
            for b in present where b.id != a.id {
                closest = min(closest, abs(a.brain.centreX - b.brain.centreX))
            }
        }
        if closest < 420, startSparring() { return }
        gatherAndSpar()
    }

    // MARK: - The characters with no voice

    /// True while an exchange of blows is running.
    private(set) var fighting = false
    private var nextFight = Date().addingTimeInterval(45)
    private var recentOpeners = RecentPicks(limit: 8)

    /// The closest two who are both free, which is who an exchange is between:
    /// shouting across the desktop isn't a conversation, or a fight.
    private func nearestPair() -> (Buddy, Buddy)? {
        let free = onScreen.filter { $0.brain.isAvailable }
        guard free.count > 1 else { return nil }
        var pair: (Buddy, Buddy)?
        var closest = CGFloat.infinity
        for a in free {
            for b in free where b.id != a.id {
                let gap = abs(a.brain.centreX - b.brain.centreX)
                if gap < closest { closest = gap; pair = (a, b) }
            }
        }
        return pair
    }

    /// A conversation out of GameTalk, for characters with no speech packs.
    @discardableResult
    func startGameBanter() -> Bool {
        guard !talking, !fighting, let (a, b) = nearestPair() else { return false }
        let options = GameTalk.exchanges(for: (a.id, b.id))
        guard !options.isEmpty else { return false }
        let opener = recentOpeners.pick(from: options.map { $0[0].text })
        guard let exchange = options.first(where: { $0[0].text == opener }) else { return false }

        talking = true
        plog("game banter: \(a.id) and \(b.id), \(exchange.count) lines")
        let hold = exchange.reduce(0.0) { $0 + 1.5 + Double($1.text.count) * 0.048 + 0.8 } + 4
        [a, b].forEach { $0.brain.holdBeats(for: hold) }
        deliverGame(exchange, at: 0, between: a, and: b)
        return true
    }

    /// Who says a line: whoever it names, else whoever didn't say the last one,
    /// so an unattributed exchange still alternates.
    private func deliverGame(_ exchange: [GameTalk.Line], at index: Int,
                             between a: Buddy, and b: Buddy, lastSpeaker: String? = nil) {
        guard index < exchange.count, talking else {
            talking = false
            nextBanter = Date().addingTimeInterval(Double.random(in: 45...100))
            [a, b].forEach { $0.brain.face(toward: -1) }
            return
        }
        let line = exchange[index]
        let speaker = line.who.flatMap(buddy) ?? (lastSpeaker == a.id ? b : a)
        let other = speaker.id == a.id ? b : a
        other.brain.face(toward: speaker.brain.centreX)

        // A gesture on the opening line only: one before every line reads as
        // two characters performing rather than talking.
        let move: String? = index == 0 ? speaker.personality.flourishes.first : nil
        speaker.brain.deliver(line.text, move: move, facing: other.brain.centreX) {
            [weak self] in
            guard let self, self.talking else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.deliverGame(exchange, at: index + 1, between: a, and: b,
                                 lastSpeaker: speaker.id)
            }
        }
    }

    /// One exchange of blows: who swings, and what the other does about it.
    private static let sparring: [[(attacker: Int, clips: [String])]] = [
        [(0, ["punch", "jab", "strike"]), (1, ["knockdown", "guard", "flip"]),
         (1, ["punch", "kick", "strike"]), (0, ["guard", "knockdown", "flip"])],
        [(0, ["kick", "highKick"]), (1, ["knockdown", "guard"]),
         (0, ["punch", "jab", "strike"]), (1, ["flip", "knockdown", "guard"])],
        [(1, ["grandUpper", "uppercut", "flameArc", "attack", "slam", "punch"]),
         (0, ["knockdown", "guard"]), (0, ["getUp", "guard", "flex", "celebrate"])],
        [(0, ["flex", "celebrate", "guard", "stretch"]),
         (1, ["punch", "kick", "strike"]), (0, ["knockdown", "guard"])],
    ]

    /// Two of them squaring up: take turns, face each other, and nobody moves
    /// while somebody else is mid-swing — a conversation, with the content
    /// physical because they have no words.
    @discardableResult
    func startSparring() -> Bool {
        guard !fighting, !talking, let (a, b) = nearestPair() else { return false }
        let exchange = Self.sparring.randomElement()!
        fighting = true
        plog("sparring: \(a.id) and \(b.id)")
        let hold = Double(exchange.count) * 4 + 6
        [a, b].forEach { $0.brain.holdBeats(for: hold) }
        trade(exchange, at: 0, between: a, and: b)
        return true
    }

    private func trade(_ exchange: [(attacker: Int, clips: [String])], at index: Int,
                       between a: Buddy, and b: Buddy) {
        guard index < exchange.count, fighting else {
            fighting = false
            nextFight = Date().addingTimeInterval(Double.random(in: 40...90))
            [a, b].forEach { $0.brain.face(toward: -1) }
            return
        }
        let step = exchange[index]
        let actor = step.attacker == 0 ? a : b
        let other = step.attacker == 0 ? b : a
        other.brain.face(toward: actor.brain.centreX)     // whoever isn't swinging watches

        actor.brain.act(step.clips, facing: other.brain.centreX) { [weak self] in
            guard let self, self.fighting else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.trade(exchange, at: index + 1, between: a, and: b)
            }
        }
    }

    /// Walk two of them together, then have them square up.
    func gatherAndSpar() {
        guard let (a, b) = nearestPair(), !talking, !fighting else { return }
        guard abs(a.brain.centreX - b.brain.centreX) > b.window.frame.width * 1.3 else {
            startSparring(); return
        }
        b.brain.moveNear(x: a.brain.centreX) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.startSparring() }
        }
    }

    /// Kick off an exchange now, if the cast allows one.
    @discardableResult
    func startBanter() -> Bool {
        guard !talking else { return false }
        let present = onScreen
        guard present.count > 1 else { return false }

        // Only whoever is free can take part. With two on screen that's the
        // same as requiring everybody, which is what this used to do; with
        // nine it would mean waiting for all of them at once, and no
        // conversation would ever start.
        let free = Set(present.filter(\.brain.isAvailable).map(\.id))
        guard free.count > 1 else { return false }
        let options = Banter.available(for: free, in: language)
        guard !options.isEmpty else { return false }

        // Keyed on speaker as well as opening line: the same opener belongs to
        // every pair that has no material of its own, so keying on the text
        // alone would hand the conversation to the same two characters every
        // time.
        func key(_ exchange: [BanterLine]) -> String {
            "\(exchange[0].who)|\(exchange[0].text)"
        }
        let chosen = recentBanter.pick(from: options.map(key))
        guard let exchange = options.first(where: { key($0) == chosen }) else { return false }

        talking = true
        let speakers = Set(exchange.map(\.who))
        plog("banter: \(exchange.count) lines between \(speakers.sorted().joined(separator: " and "))")
        // Long enough that neither wanders off mid-conversation. Only the two
        // taking part are held; the rest carry on with whatever they were doing.
        let hold = Double(exchange.count) * 6 + 6
        present.filter { speakers.contains($0.id) }.forEach { $0.brain.holdBeats(for: hold) }
        deliver(exchange, at: 0)
        return true
    }

    private func deliver(_ exchange: [BanterLine], at index: Int) {
        guard index < exchange.count else {
            talking = false
            nextBanter = Date().addingTimeInterval(Double.random(in: 50...110))
            return
        }
        let line = exchange[index]
        guard let speaker = buddy(line.who), speaker.isVisible else {
            deliver(exchange, at: index + 1)
            return
        }
        // Anyone else on screen is who he's talking to.
        let other = onScreen.first { $0.id != speaker.id }

        speaker.brain.deliver(line.text, move: line.move,
                              facing: other?.brain.centreX) { [weak self] in
            guard let self, self.talking else { return }
            // A beat between lines, so it reads as conversation rather than a
            // pair of monologues.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.deliver(exchange, at: index + 1)
            }
        }
    }

    /// Bring them together, then have them talk.
    func gatherAndBanter() {
        let present = onScreen
        guard present.count > 1, !talking else {
            startBanter()
            return
        }
        // The two already nearest each other, so the walk is short and it
        // reads as those two falling into conversation rather than the app
        // picking the first two in the list every time.
        var pair: (Buddy, Buddy)?
        var closest = CGFloat.infinity
        for (i, a) in present.enumerated() {
            for b in present.dropFirst(i + 1) {
                let gap = abs(a.brain.centreX - b.brain.centreX)
                if gap < closest { closest = gap; pair = (a, b) }
            }
        }
        guard let (first, second) = pair else { return }
        guard closest > second.window.frame.width * 1.6 else { startBanter(); return }
        second.brain.moveNear(x: first.brain.centreX) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.startBanter() }
        }
    }

    func clampAll() { buddies.forEach { $0.brain.clampToScreen() } }

    func resize(to scale: CGFloat) {
        for buddy in buddies {
            buddy.window.resize(to: scale * buddy.personality.scale, store: buddy.store)
            buddy.brain.clampToScreen()
        }
    }
}
