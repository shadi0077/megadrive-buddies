import AppKit

/// One character, fully assembled: sprites, window, animator, brain, sounds.
final class Buddy {
    let personality: Personality
    let store: SpriteStore
    let window: BuddyWindow
    let animator: Animator
    let brain: Brain

    init?(personality: Personality, scale: CGFloat) {
        guard let store = SpriteStore(character: personality.id) else { return nil }
        self.personality = personality
        self.store = store
        window = BuddyWindow(store: store, scale: scale * personality.scale)
        animator = Animator(store: store, view: window.buddyView)
        brain = Brain(personality: personality, store: store,
                      animator: animator, window: window)
        store.warm(["rest", "arrive", personality.walk, "guard"])
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
    private(set) var fighting = false
    private var nextFight = Date().addingTimeInterval(35)

    var liveliness: Liveliness = .occasional {
        didSet { buddies.forEach { $0.brain.liveliness = liveliness } }
    }

    var chattiness: Chattiness = .occasional {
        didSet { buddies.forEach { $0.brain.chattiness = chattiness } }
    }

    /// True while an exchange of words is running.
    private(set) var chatting = false
    private var nextChat = Date().addingTimeInterval(50)
    private var recentOpeners = RecentPicks(limit: 8)

    init(scale: CGFloat) {
        for personality in Personality.all {
            if let buddy = Buddy(personality: personality, scale: scale) {
                buddies.append(buddy)
            }
        }
        buddies.forEach { $0.start() }

        // Nobody starts a line while somebody else is finishing one. Strictly
        // "is somebody *else* mid-sentence": it has to stay true for whoever
        // holds the floor, or a character delivering a line blocks on itself.
        for buddy in buddies {
            buddy.brain.mayTalk = { [weak self, weak buddy] in
                guard let self, let buddy else { return true }
                return !self.onScreen.contains {
                    $0.id != buddy.id && $0.brain.isTalking
                }
            }
        }

        // One slow tick is plenty; the characters run their own 60 Hz clocks.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func buddy(_ id: String) -> Buddy? { buddies.first { $0.id == id } }

    var onScreen: [Buddy] { buddies.filter(\.isVisible) }
    var activeIDs: Set<String> { Set(onScreen.map(\.id)) }

    // MARK: - Coming and going

    func show(_ id: String, at point: NSPoint? = nil) {
        guard let buddy = buddy(id), !buddy.isVisible else { return }
        buddy.brain.appear(at: point ?? spot(for: buddy))
    }

    /// Bring several on, staggered — arriving together means every one of them
    /// shouting at once, which is just noise.
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

    // MARK: - Squaring up

    private func tick() {
        guard !fighting, !chatting else { return }
        let present = onScreen
        guard present.count > 1 else {
            nextFight = Date().addingTimeInterval(20)
            nextChat = Date().addingTimeInterval(20)
            return
        }
        guard present.allSatisfy({ $0.brain.isAvailable }) else { return }

        // Talking and fighting are on separate clocks, so a pair that has just
        // finished swinging at each other can still have a conversation about
        // it, and neither starves the other.
        if Date() >= nextChat, chattiness != .quiet, startBanter() { return }
        guard Date() >= nextFight else { return }

        // Proximity is the trigger: two who have wandered close together square
        // up, and if nobody is near anybody, two of them walk together first.
        var closest = CGFloat.infinity
        for a in present {
            for b in present where b.id != a.id {
                closest = min(closest, abs(a.brain.centreX - b.brain.centreX))
            }
        }
        if closest < 420, startSparring() { return }
        gatherAndSpar()
    }

    // MARK: - Them talking to each other

    /// The closest two who are both free, which is who a conversation is
    /// between: shouting across the desktop isn't a conversation.
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

    /// Kick off an exchange now, if the cast allows one.
    @discardableResult
    func startBanter() -> Bool {
        guard !chatting, !fighting, let (a, b) = nearestPair() else { return false }
        let options = GameTalk.exchanges(for: (a.id, b.id))
        guard !options.isEmpty else { return false }

        // Pick by opening line, so the no-repeat memory has something stable
        // to key on.
        let opener = recentOpeners.pick(from: options.map { $0[0].text })
        guard let exchange = options.first(where: { $0[0].text == opener }) else { return false }

        chatting = true
        plog("banter: \(a.id) and \(b.id), \(exchange.count) lines")
        // Long enough that neither wanders off mid-conversation.
        let hold = exchange.reduce(0.0) { $0 + Brain.readingTime($1.text) + 0.8 } + 4
        [a, b].forEach { $0.brain.holdBeats(for: hold) }
        deliver(exchange, at: 0, between: a, and: b)
        return true
    }

    /// Who says a given line: whoever it names, else whoever didn't say the
    /// last one, so an unattributed exchange still alternates.
    private func deliver(_ exchange: [GameTalk.Line], at index: Int,
                         between a: Buddy, and b: Buddy, lastSpeaker: String? = nil) {
        guard index < exchange.count, chatting else {
            chatting = false
            nextChat = Date().addingTimeInterval(Double.random(in: 45...100))
            [a, b].forEach { $0.brain.face(toward: -1) }
            return
        }
        let line = exchange[index]
        let speaker = line.who.flatMap(buddy) ?? (lastSpeaker == a.id ? b : a)
        let other = speaker.id == a.id ? b : a
        other.brain.face(toward: speaker.brain.centreX)

        // A gesture on the opening line only: a move before every line reads
        // as two characters performing rather than talking.
        let move: [String]? = index == 0 ? speaker.personality.flourishes : nil
        speaker.brain.deliver(line.text, move: move, facing: other.brain.centreX) {
            [weak self] in
            guard let self, self.chatting else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.deliver(exchange, at: index + 1, between: a, and: b,
                             lastSpeaker: speaker.id)
            }
        }
    }

    /// Walk two of them together, then have them talk.
    func gatherAndTalk() {
        guard let (a, b) = nearestPair() else { return }
        guard !chatting, !fighting else { return }
        let apart = abs(a.brain.centreX - b.brain.centreX)
        guard apart > b.window.frame.width * 1.6 else { startBanter(); return }
        b.brain.moveNear(x: a.brain.centreX) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.startBanter() }
        }
    }

    /// One exchange of blows: who swings, and what the other one does about it.
    private static let sparring: [[(attacker: Int, clips: [String])]] = [
        [(0, ["punch", "jab"]), (1, ["knockdown", "guard", "flip"]),
         (1, ["punch", "kick"]), (0, ["guard", "knockdown", "flip"])],
        [(0, ["kick", "highKick"]), (1, ["knockdown", "guard"]),
         (0, ["punch", "jab"]), (1, ["flip", "knockdown", "guard"])],
        [(1, ["grandUpper", "uppercut", "flameArc", "attack", "slam", "punch"]),
         (0, ["knockdown", "guard"]), (0, ["getUp", "guard", "flex", "celebrate"])],
        [(0, ["flex", "celebrate", "guard", "stretch"]),
         (1, ["punch", "kick"]), (0, ["knockdown", "guard"])],
    ]

    /// Two of them squaring up.
    ///
    /// They take turns, face each other, and nobody moves while somebody else
    /// is mid-swing — the shape of a conversation, with the content physical
    /// because they have no words.
    @discardableResult
    func startSparring() -> Bool {
        guard !fighting, !chatting else { return false }
        let brawlers = onScreen.filter { $0.brain.isAvailable }
        guard brawlers.count > 1 else { return false }

        // The two closest together, so it reads as them reacting to proximity
        // rather than shouting across the desktop.
        var pair: (Buddy, Buddy)?
        var closest = CGFloat.infinity
        for a in brawlers {
            for b in brawlers where b.id != a.id {
                let gap = abs(a.brain.centreX - b.brain.centreX)
                if gap < closest { closest = gap; pair = (a, b) }
            }
        }
        guard let (a, b) = pair else { return false }

        let exchange = Self.sparring.randomElement()!
        fighting = true
        plog("sparring: \(a.id) and \(b.id), \(Int(closest)) pt apart")
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
            [a, b].forEach { $0.brain.face(toward: -1) }   // back to facing front
            return
        }
        let step = exchange[index]
        let actor = step.attacker == 0 ? a : b
        let other = step.attacker == 0 ? b : a
        // Whoever isn't moving still turns to watch.
        other.brain.face(toward: actor.brain.centreX)

        actor.brain.act(step.clips, facing: other.brain.centreX) { [weak self] in
            guard let self, self.fighting else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.trade(exchange, at: index + 1, between: a, and: b)
            }
        }
    }

    /// Walk two of them together and have them square up.
    func gatherAndSpar() {
        let brawlers = onScreen
        guard brawlers.count > 1, !fighting else { startSparring(); return }
        let a = brawlers[0], b = brawlers[1]
        let apart = abs(a.brain.centreX - b.brain.centreX)
        guard apart > b.window.frame.width * 1.3 else { startSparring(); return }
        b.brain.moveNear(x: a.brain.centreX) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.startSparring() }
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
