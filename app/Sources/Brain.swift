import AppKit

/// Set PEEDY_DEBUG=1 to trace behaviour decisions on stderr.
let peedyDebug = ProcessInfo.processInfo.environment["PEEDY_DEBUG"] == "1"

func plog(_ message: @autoclosure () -> String) {
    guard peedyDebug else { return }
    FileHandle.standardError.write("[cast] \(message())\n".data(using: .utf8)!)
}

enum Chattiness: Int, CaseIterable {
    case quiet = 0, occasional = 1, chatty = 2

    var title: String {
        switch self {
        case .quiet: return "Quiet"
        case .occasional: return "Occasional"
        case .chatty: return "Chatty"
        }
    }
    /// Chance an idle beat comes with a line.
    var speakChance: Double {
        switch self {
        case .quiet: return 0
        case .occasional: return 0.35
        case .chatty: return 0.8
        }
    }
    /// Weight of the talking beat for the characters who have no voice: they
    /// put the same material in a speech box instead.
    var weight: Double {
        switch self {
        case .quiet: return 0
        case .occasional: return 0.30
        case .chatty: return 0.85
        }
    }
}

/// How often they do anything at all.
///
/// Separate from `Chattiness` on purpose: pacing about and talking are
/// different appetites, and somebody who wants a lively desktop doesn't
/// necessarily want it narrated.
enum Liveliness: Int, CaseIterable {
    case calm = 0, occasional = 1, restless = 2

    var title: String {
        switch self {
        case .calm: return "Calm"
        case .occasional: return "Occasional"
        case .restless: return "Restless"
        }
    }

    /// Multiplier on the character's own beat interval, so a quick parrot and
    /// a lumbering wrestler both settle or liven up without losing the
    /// difference between them.
    var pace: Double {
        switch self {
        case .calm: return 1.7
        case .occasional: return 1.0
        case .restless: return 0.62
        }
    }
}

/// Decides what the bird does and when. Everything user-visible funnels
/// through here so only one thing is ever in flight at a time.
final class Brain {
    let personality: Personality
    /// What he says and how he sounds, in the language currently selected.
    private(set) var pack: SpeechPack?
    private(set) var language: Language = .english

    /// Trace lines carry the character's name, so a two-hander is readable.
    private func plog(_ message: @autoclosure () -> String) {
        guard peedyDebug else { return }
        FileHandle.standardError.write(
            "[\(personality.id)] \(message())\n".data(using: .utf8)!)
    }

    /// Set by the Cast: false while somebody else has the floor. Two characters
    /// talking over each other is unreadable, and worse, unfunny.
    var mayStartTalking: (() -> Bool)?
    private let store: SpriteStore
    private let animator: Animator
    private let window: BuddyWindow
    private let bubble = SpeechBubbleWindow()
    let voice = Voice()

    private enum Mode { case away, busy, idle, dragging }
    private var mode: Mode = .away

    /// Bumped on every state change. Deferred callbacks capture the value
    /// they were issued under and bail if the bird has moved on since.
    private var generation = 0
    private func bump() -> Int { generation += 1; return generation }
    private func current(_ token: Int) -> Bool { generation == token }

    private var nextBeat: TimeInterval = 0
    private var clock: TimeInterval = 0
    private var bubbleUntil: TimeInterval = 0

    /// In-flight travel, driven from the animator tick.
    private var travel: (from: NSPoint, to: NSPoint, t: Double, duration: Double)?

    /// How lively he is, 0...1. Rises when something happens to him, decays
    /// back toward a baseline set by whether anyone is actually at the machine.
    /// Everything about his rhythm — gap between beats, blink rate, what he
    /// picks to do — reads off this, so he has good spells and quiet spells
    /// instead of one flat tempo.
    private var energy: Double = 0.55
    private var nextBlink: TimeInterval = 0
    private var wasAway = false
    /// When he last entered .busy, for the stuck-state backstop below.
    private var busySince: TimeInterval = 0

    private var lastCursor: NSPoint = .zero
    private var cursorSpeed: Double = 0
    private var lastNoticed: TimeInterval = -100
    private var cursorWasNear = false

    private var pokeStreak = 0
    private var lastPokeAt: TimeInterval = -100

    private var recentLines = RecentPicks(limit: 8)
    private var recentJokes = RecentPicks(limit: 10)
    private var recentFacts = RecentPicks(limit: 14)
    private var recentSongs = RecentPicks(limit: 2)
    private var recentMoves = RecentPicks(limit: 4)

    var chattiness: Chattiness = .occasional

    var liveliness: Liveliness = .occasional {
        didSet { scheduleBeat() }
    }

    /// The game characters' sound effects — what they have instead of a voice.
    let sounds: SoundBank?

    var isVisible: Bool { mode != .away }

    init(personality: Personality, language: Language, store: SpriteStore,
         animator: Animator, window: BuddyWindow) {
        self.personality = personality
        self.language = language
        self.pack = personality.pack(language)
        self.sounds = personality.soundSet.flatMap { SoundBank(set: $0) }
        self.store = store
        self.animator = animator
        self.window = window
        animator.onTick = { [weak self] dt in self?.tick(dt) }
        // Only offer a level while audio is actually playing; otherwise the
        // animator cycles visemes on its own.
        animator.mouthLevel = { [weak self] in
            guard let self, self.voice.isSpeaking, self.voice.isEnabled else { return nil }
            return self.voice.level
        }
        applyPack()
        wireWindow()
    }

    /// Switch language. Anything mid-sentence is dropped rather than finished
    /// in a language he's no longer speaking.
    func speak(_ language: Language) {
        guard language != self.language else { return }
        self.language = language
        pack = personality.pack(language)
        stopSpeaking()
        applyPack()
        // The pools all changed, so what he said a moment ago is no guide.
        recentLines = RecentPicks(limit: 8)
        recentJokes = RecentPicks(limit: 10)
        recentFacts = RecentPicks(limit: 14)
        recentSongs = RecentPicks(limit: 2)
        plog("language -> \(language.rawValue)")
    }

    private func applyPack() {
        guard let pack else { return }
        if let id = pack.preferredVoice { voice.identifier = id }
        voice.pitch = pack.pitch
        voice.rate = pack.rate
        voice.personalityRoot = pack.singingRoot
    }

    /// The name he goes by in the language he's speaking.
    var displayName: String { pack?.name ?? personality.name }

    /// One line for this hour of the day, in his own language.
    private func timeOfDayPool(_ hour: Int) -> [String] {
        guard let pack else { return [] }
        let slot: Int
        switch hour {
        case 5..<12: slot = 0
        case 12..<18: slot = 1
        case 18..<23: slot = 2
        default: slot = 3           // 23 and 0..<5
        }
        return pack.timeOfDay.count > slot ? [pack.timeOfDay[slot]] : pack.greetings
    }

    // MARK: - Liveliness

    /// Where energy settles, given how long the user has been away from the
    /// keyboard. Nobody there means nobody to perform for.
    static func energyBaseline(userIdleSeconds: Double) -> Double {
        userIdleSeconds > 180 ? 0.12 : 0.55
    }

    /// What a poke should get, given how many landed in quick succession.
    enum Reaction { case startled, playful, tiring, hadEnough }

    static func reaction(forStreak streak: Int) -> Reaction {
        switch streak {
        case ..<2: return .startled
        case 2...3: return .playful
        case 4...6: return .tiring
        default: return .hadEnough
        }
    }

    /// Pick from `weights` proportionally. `roll` is 0..<1.
    static func weightedPick<T>(_ weights: [(T, Double)], roll: Double) -> T? {
        let total = weights.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return weights.first?.0 }
        var cursor = roll.clamped(to: 0..<1) * total
        for (value, weight) in weights {
            cursor -= max(0, weight)
            if cursor < 0 { return value }
        }
        return weights.last?.0
    }

    /// How near the cursor has to get before he takes an interest.
    static let noticeRadius: CGFloat = 250

    /// Whether a cursor should register as *arriving* next to him.
    ///
    /// Edge-triggered on purpose. Level-triggering means a cursor parked on top
    /// of him gets greeted every few seconds forever, which reads as a stuck
    /// loop rather than attention. The speed floor stops a motionless cursor
    /// counting as an arrival when it is he who moved.
    static func noticesCursor(at point: NSPoint, frame: NSRect,
                              wasNear: Bool, speed: Double) -> (notice: Bool, near: Bool) {
        let near = hypot(point.x - frame.midX, point.y - frame.midY) < noticeRadius
        return (near && !wasNear && speed > 60, near)
    }

    /// Seconds since the user last touched the keyboard or mouse. Needs no
    /// permission, unlike anything that reads actual events.
    private var userIdleSeconds: Double {
        guard let any = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }

    private func stir(_ amount: Double) { energy = min(1, energy + amount) }

    private func updateEnergy(_ dt: TimeInterval) {
        let idle = userIdleSeconds
        let away = idle > 180
        if wasAway, !away { wasAway = false; welcomeBack() }
        if away { wasAway = true }

        let baseline = Self.energyBaseline(userIdleSeconds: idle)
        energy += (baseline - energy) * min(1, dt * 0.03)
    }

    private func welcomeBack() {
        guard mode == .idle, bubbleUntil == 0 else { return }
        plog("welcome back")
        energy = 0.9
        scheduleBeat()
        perform(move(["greet", "cheer", "announce", "celebrate"])) { [weak self] in
            guard let self, self.chattiness != .quiet else { return }
            self.say(self.recentLines.pick(from: (pack?.welcomeBack ?? [])))
        }
    }

    // MARK: - Blinking

    private func scheduleBlink() {
        // Irregular, and quicker when he is alert. Eyes that never blink are
        // the fastest way to make something read as a puppet.
        nextBlink = clock + Double.random(in: 1.6...6.0) * (1.5 - energy * 0.7)
    }

    private func maybeBlink() {
        guard clock >= nextBlink else { return }
        scheduleBlink()
        // Idle rest only. A "bit" owns its animator for the whole intro/loop/
        // outro sequence and hands back through a deferred callback; blinking
        // over the top of one would replace the clip mid-flight and strand him
        // in the loop forever. Not worth an eye flutter.
        // Not every sprite set has eye patches — a Genesis rip has no blink
        // frames at all, so those characters simply don't blink.
        guard store.animation("blink") != nil else { return }
        guard mode == .idle, bubbleUntil == 0, animator.currentName == "rest" else { return }

        // Capture the generation rather than bumping it: a blink must not
        // invalidate anyone else's pending work, only be invalidated by it.
        let token = generation
        let twice = Double.random(in: 0...1) < 0.16
        animator.play("blink") { [weak self] in
            guard let self, self.current(token), self.mode == .idle else { return }
            guard twice else { self.animator.play("rest"); return }
            self.animator.play("blink") {
                guard self.current(token), self.mode == .idle else { return }
                self.animator.play("rest")
            }
        }
    }

    // MARK: - Noticing the cursor

    private func updateCursor(_ dt: TimeInterval) {
        let now = NSEvent.mouseLocation
        if lastCursor != .zero, dt > 0 {
            let moved = hypot(now.x - lastCursor.x, now.y - lastCursor.y)
            // Smoothed, so one big jump doesn't read as a sustained swipe.
            cursorSpeed += (moved / dt - cursorSpeed) * min(1, dt * 8)
        }
        lastCursor = now

        let frame = window.frame
        let (notice, near) = Self.noticesCursor(at: now, frame: frame,
                                                wasNear: cursorWasNear, speed: cursorSpeed)
        cursorWasNear = near
        guard notice else { return }
        guard mode == .idle, bubbleUntil == 0, clock - lastNoticed > 9 else { return }

        let dx = now.x - frame.midX
        guard mayStartTalking?() ?? true else { return }
        lastNoticed = clock
        stir(0.2)
        plog(String(format: "noticed cursor dx=%.0f speed=%.0f", dx, cursorSpeed))

        if cursorSpeed > 1100 {
            perform(move(["surprised", "guard", "jumpKick"]))   // shot past him
        } else {
            // The point clip aims to the viewer's right unmirrored.
            animator.mirrored = dx < 0
            perform(move(["point", "punch", "jab"])) { [weak self] in
                guard let self else { return }
                self.animator.mirrored = false
                if self.chattiness == .chatty, Double.random(in: 0...1) < 0.3 {
                    self.say(self.recentLines.pick(from: (pack?.noticed ?? [])))
                }
            }
        }
    }

    // MARK: - Lifecycle

    func appear(at point: NSPoint? = nil) {
        guard mode == .away else { return }
        if let point { window.setFrameOrigin(point) }
        window.orderFront(nil)
        mode = .busy
        makeNoise(.shout)
        animator.play("arrive") { [weak self] in
            guard let self else { return }
            self.goIdle()                     // must precede say(): goIdle
            // Half the time he notices what time of day it is.        // plays "rest" over the hold
            let hour = Calendar.current.component(.hour, from: Date())
            let pool = Bool.random() ? self.timeOfDayPool(hour) : (self.pack?.greetings ?? [])
            self.say(self.recentLines.pick(from: pool))
        }
    }

    /// Where he was standing before he flew off, so he can come back to it.
    private(set) var lastOrigin: NSPoint = .zero

    func vanish(_ completion: (() -> Void)? = nil) {
        guard mode != .away else { completion?(); return }
        lastOrigin = window.frame.origin
        cancelTravel()
        mode = .busy
        say(recentLines.pick(from: (pack?.leaving ?? [])), pose: nil, duration: 1.6)
        animator.play("depart") { [weak self] in
            self?.hideNow()
            completion?()
        }
    }

    private func hideNow() {
        voice.stop()
        mode = .away
        bubble.dismiss()
        window.orderOut(nil)
    }

    // MARK: - Beats

    private func goIdle() {
        _ = bump()
        mode = .idle
        animator.endTalking()
        animator.mirrored = false
        animator.play("rest")
        scheduleBeat()
        scheduleBlink()
    }

    private func scheduleBeat() {
        // Lively means shorter gaps, winding down means longer ones, and the
        // 0.55 baseline lands on the interval the user actually chose.
        nextBeat = clock + Double.random(in: personality.beatRange)
            * liveliness.pace * (1.55 - energy)
    }

    private func tick(_ dt: TimeInterval) {
        clock += dt
        updateEnergy(dt)
        advanceTravel(dt)
        if bubbleUntil > 0, clock > bubbleUntil {
            bubbleUntil = 0
            bubble.dismiss()
            animator.endTalking()
            if mode == .idle { animator.play("rest") }
            // Give him a breath after finishing a thought. The gap is scheduled
            // when a beat *starts*, so without this a long turn runs straight
            // into the next one and jokes arrive back to back.
            nextBeat = max(nextBeat, clock + Double.random(in: personality.beatRange)
                * liveliness.pace * 0.6)
        }
        // Every long sequence hands back through a deferred callback, and a
        // dropped one would leave him frozen mid-bit with no way out. Twice
        // during development that actually happened, so: a backstop.
        if mode == .busy {
            if busySince == 0 { busySince = clock }
            else if clock - busySince > 60 {
                plog("stuck busy for 60s — recovering")
                busySince = 0
                goIdle()
            }
        } else {
            busySince = 0
        }

        maybeBlink()
        updateCursor(dt)
        // Never start a beat mid-sentence: the body would animate out from
        // under the mouth patches.
        if mode == .idle, bubbleUntil == 0, clock >= nextBeat { idleBeat() }
        repositionBubble()
    }

    private enum Beat { case settle, wander, bit, flourish, turn }

    private func idleBeat() {
        // Don't start anything while the other one is mid-sentence.
        guard mayStartTalking?() ?? true else {
            nextBeat = clock + Double.random(in: 2...5)
            return
        }
        scheduleBeat()
        plog(String(format: "idleBeat %.0fs energy %.2f next %.1fs",
                    clock, energy, nextBeat - clock))

        // Weights move with energy, so a quiet spell is small and still while a
        // lively one is up and about.
        let settled = 1 - energy
        let beat = Self.weightedPick([(Beat.settle, 0.10 + 0.40 * settled),
                                      (.wander, (0.07 + 0.28 * energy)
                                                * personality.roaming.restlessness),
                                      (.bit, 0.20),
                                      (.flourish, 0.08 + 0.22 * energy),
                                      (.turn, personality.speaks
                                              ? 0.12 + 0.26 * energy
                                              : chattiness.weight)],
                                     roll: Double.random(in: 0..<1)) ?? .settle

        switch beat {
        case .settle:
            // Blinking has its own clock, so a settle beat is a look around —
            // or, often enough, simply staying put. Not every beat has to
            // produce a movement.
            guard Double.random(in: 0...1) > 0.45 else { plog("  settle: stays put"); return }
            perform(move(["lookAround", "shrug", "guard", "stretch"]))
        case .wander:
            wanderNearby()
        case .bit:
            performBit(personality.bits.randomElement()!)
        case .turn:
            // Songs are long, so they come up less often than the rest.
            perform(Self.weightedPick([(Turn.joke, 3.0), (.fact, 3.0), (.riddle, 1.6),
                                       (.twister, 1.0), (.song, 1.0)],
                                      roll: Double.random(in: 0..<1)) ?? .joke)
        case .flourish:
            let name = move(personality.flourishes)
            if Double.random(in: 0...1) < chattiness.speakChance * (0.55 + energy * 0.45) {
                perform(name) { [weak self] in
                    guard let self else { return }
                    self.say(self.recentLines.pick(from: (pack?.idle ?? [])))
                }
            } else {
                perform(name)
            }
        }
    }

    /// Play a one-shot clip, then fall back to idle.
    /// The first of these clips the character actually has.
    ///
    /// The two sprite sets don't cover the same ground — Peedy has a lightbulb
    /// and a first-place ribbon, Bonzi has a vine and a banana — so the shared
    /// routines state a preference and take what's there.
    private func firstAvailable(_ names: [String]) -> String {
        names.first { store.animation($0) != nil } ?? "rest"
    }

    /// Pick one of these, ignoring any this character hasn't got, and falling
    /// back to its own flourishes if it has none of them.
    ///
    /// The shared routines name clips from the Agent characters — "cheer",
    /// "shrug", "lookAround". A sprite rip from a beat-'em-up has none of those
    /// and would otherwise silently perform nothing at all.
    private func move(_ preferred: [String]) -> String {
        let available = preferred.filter { store.animation($0) != nil }
        return recentMoves.pick(from: available.isEmpty ? personality.flourishes
                                                        : available)
    }

    private func perform(_ name: String, then: (() -> Void)? = nil) {
        guard mode == .idle else { return }
        plog("perform \(name)")
        makeNoise(noise(for: name))
        mode = .busy
        let token = bump()
        animator.play(name) { [weak self] in
            guard let self, self.current(token) else { return }
            self.mode = .idle
            self.animator.play("rest")
            then?()
        }
    }

    private func performBit(_ bit: Personality.Bit) {
        guard mode == .idle else { return }
        mode = .busy
        plog("bit \(bit.intro)")
        let token = bump()
        let line = (pack?.byBit ?? [:])[bit.talk].map { recentLines.pick(from: $0) }
        animator.play(bit.intro) { [weak self] in
            guard let self, self.current(token) else { return }
            let finishBit = {
                guard self.current(token) else { return }
                guard let outro = bit.outro else { self.goIdle(); return }
                self.animator.play(outro) { self.goIdle() }
            }
            if let loop = bit.loop {
                self.animator.play(loop)
                let hold = Double.random(in: bit.hold)
                if let line, Double.random(in: 0...1) < max(self.chattiness.speakChance, 0.3) {
                    let talkFor = min(hold, 3.4)
                    self.showBubble(line, duration: talkFor)
                    // Only poses with mouth patches interrupt the loop; the
                    // rest just get a bubble and keep on looping.
                    if let pose = bit.pose {
                        self.animator.beginTalking(pose: pose)
                        DispatchQueue.main.asyncAfter(deadline: .now() + talkFor) {
                            guard self.current(token) else { return }
                            self.animator.endTalking()
                            self.animator.play(loop)
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                    guard self.current(token) else { return }
                    self.animator.endTalking()
                    finishBit()
                }
            } else {
                if let line, Double.random(in: 0...1) < max(self.chattiness.speakChance, 0.3) {
                    self.say(line, pose: bit.pose, duration: 2.6)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        finishBit()
                    }
                } else {
                    finishBit()
                }
            }
        }
    }

    /// Make a noise. Silent for anyone whose game we have no sound rip from.
    @discardableResult
    private func makeNoise(_ kind: SoundBank.Kind) -> Bool {
        let played = sounds?.play(kind) ?? false
        if played { plog("  sound: \(kind)") }
        return played
    }

    /// The noise that suits a movement. Specials and arrivals announce
    /// themselves, landings thud, everything else is exertion.
    private func noise(for clip: String) -> SoundBank.Kind {
        switch clip {
        case "grandUpper", "flameArc", "uppercut", "celebrate", "arrive",
             "cheer", "laugh":
            return .shout
        case "knockdown", "getUp", "hit":
            return .impact
        default:
            return .effort
        }
    }

    /// How long a line stays up for a character with no voice: long enough to
    /// read, and no longer. Nothing else sets the pace — there is no audio to
    /// finish — so this is measured against reading it aloud, roughly 190
    /// words a minute plus a moment to notice the box appeared.
    static func readingTime(_ text: String) -> TimeInterval {
        min(9.0, 1.5 + Double(text.count) * 0.048)
    }

    // MARK: - Speech

    func say(_ text: String, pose: String? = "neutral", duration: TimeInterval? = nil,
             waited: TimeInterval = 0) {
        guard !text.isEmpty, mode != .away else { return }
        // Wait for the floor rather than talk over the other one. Beats already
        // check this before they start, but a bit plays several seconds of
        // animation before its line, and the other character can take the floor
        // in between. Capped, so a long-winded neighbour can't silence him.
        if let may = mayStartTalking, !may(), waited < 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.say(text, pose: pose, duration: duration, waited: waited + 0.4)
            }
            return
        }

        // A character with no speech pack has no voice to render, so the box
        // is the whole performance: it stays up long enough to read, rather
        // than for however long the audio turned out to be.
        guard personality.speaks else {
            let reading = Self.readingTime(text)
            plog(String(format: "say (box, %.1fs): %@", reading, text))
            showBubble(text, duration: reading)
            return
        }

        // Provisional timing from the text; corrected the moment audio starts
        // and the real duration is known.
        let estimate = duration ?? min(6.0, 1.4 + Double(text.count) * 0.055)
        plog(String(format: "say (%@, ~%.1fs): %@", pose ?? "no lip-sync", estimate, text))
        showBubble(text, duration: estimate)

        guard voice.isEnabled else {
            animator.beginTalking(pose: pose)
            return
        }
        voice.speak(text) { [weak self] spoken in
            guard let self else { return }
            plog(String(format: "  audio %.2fs", spoken))
            self.bubbleUntil = self.clock + spoken + 0.4
            self.animator.beginTalking(pose: pose)
        } onFinish: { [weak self] in
            self?.animator.endTalking()
        }
    }

    var isSpeaking: Bool { bubbleUntil > 0 }

    /// Cut a line short - used whenever something else takes over the bird.
    private func stopSpeaking() {
        voice.stop()
        sounds?.stop()
        guard bubbleUntil > 0 else { return }
        bubbleUntil = 0
        bubble.dismiss()
        animator.endTalking()
    }

    fileprivate func showBubble(_ text: String, duration: TimeInterval) {
        guard let screen = currentScreen() else { return }
        bubble.present(text, rightToLeft: language.isRightToLeft,
                       pixel: personality.pixelArt,
                       pointingAt: headAnchor(), on: screen)
        bubbleUntil = clock + duration
    }

    /// Screen point just above the bird's head, where the bubble tail lands.
    private func headAnchor() -> NSPoint {
        let f = window.frame
        return NSPoint(x: f.midX, y: f.maxY - f.height * 0.12)
    }

    private func repositionBubble() {
        guard bubbleUntil > 0, bubble.alphaValue > 0, let screen = currentScreen() else { return }
        let anchor = headAnchor()
        var origin = bubble.frame.origin
        origin.x = anchor.x - bubble.frame.width / 2
        origin.y = anchor.y
        let vf = screen.visibleFrame
        origin.x = min(max(origin.x, vf.minX + 6), vf.maxX - bubble.frame.width - 6)
        origin.y = min(max(origin.y, vf.minY + 6), vf.maxY - bubble.frame.height - 6)
        bubble.setFrameOrigin(origin)
    }

    private func currentScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(window.frame) } ?? NSScreen.main
    }

    // MARK: - Movement

    /// Pick a hop target inside `bounds` for a window currently at `origin`.
    ///
    /// Direction comes from the room actually available, so a bird parked
    /// against an edge never picks a target that clamps back onto itself.
    /// Returns nil when there is nowhere worth going.
    static func wanderTarget(from origin: NSPoint, size: NSSize, in visible: NSRect,
                             hop: CGFloat, dy: CGFloat, preferRight: Bool) -> NSPoint? {
        let minX = visible.minX + 8, maxX = visible.maxX - size.width - 8
        let minY = visible.minY + 8, maxY = max(visible.maxY - size.height - 8, visible.minY + 8)
        guard maxX > minX else { return nil }

        let here = min(max(origin.x, minX), maxX)
        let roomRight = maxX - here
        let roomLeft = here - minX
        let slack: CGFloat = 80

        let dx: CGFloat
        switch (roomRight >= slack, roomLeft >= slack) {
        case (false, false): return nil                   // pinned; try again next beat
        case (true, false): dx = min(hop, roomRight)
        case (false, true): dx = -min(hop, roomLeft)
        case (true, true): dx = preferRight ? min(hop, roomRight) : -min(hop, roomLeft)
        }

        return NSPoint(x: here + dx, y: min(max(origin.y + dy, minY), maxY))
    }

    /// Short hop somewhere else on the same screen.
    private func wanderNearby() {
        guard let screen = currentScreen() else { return }
        let f = window.frame
        plog(String(format: "wander from %.0f,%.0f in %.0f,%.0f %.0fx%.0f",
                    f.origin.x, f.origin.y, screen.visibleFrame.minX,
                    screen.visibleFrame.minY, screen.visibleFrame.width,
                    screen.visibleFrame.height))
        guard let target = Self.wanderTarget(from: f.origin, size: f.size,
                                             in: screen.visibleFrame,
                                             hop: .random(in: personality.roaming.distance),
                                             dy: .random(in: -90...90),
                                             preferRight: .random()) else {
            plog("wander: nowhere to go")
            return
        }
        flyTo(target)
    }

    /// Fly to a window origin, with takeoff and landing.
    func flyTo(_ target: NSPoint, then: (() -> Void)? = nil) {
        guard mode == .idle || mode == .busy else { return }
        stopSpeaking()
        cancelTravel()
        mode = .busy
        let from = window.frame.origin
        plog(String(format: "flyTo (%.0f,%.0f) -> (%.0f,%.0f)", from.x, from.y, target.x, target.y))
        guard hypot(target.x - from.x, target.y - from.y) > 40 else {
            goIdle(); then?(); return
        }
        // The cruise clips face the viewer's left unmirrored, so mirror to go
        // the other way.
        animator.mirrored = target.x > from.x

        let token = bump()
        let distance = Double(hypot(target.x - from.x, target.y - from.y))
        // Travel time comes from the character's own pace, so the cruise
        // animation matches the distance covered instead of the window
        // teleporting under a looping walk cycle.
        let duration = max(0.4, min(14, distance / Double(personality.roaming.speed)))

        let cruise = { [weak self] in
            guard let self, self.current(token) else { return }
            self.animator.play(self.personality.travel.cruise)
            self.travel = (from, target, 0, duration)
            self.travelDone = {
                guard self.current(token) else { return }
                let settle = {
                    self.animator.mirrored = false
                    self.goIdle()
                    then?()
                }
                if case .flies(_, _, let land) = self.personality.travel {
                    self.animator.play(land) { settle() }
                } else {
                    settle()
                }
            }
        }

        if case .flies(let takeoff, _, _) = personality.travel {
            animator.play(takeoff) { cruise() }
        } else {
            cruise()
        }
    }

    private var travelDone: (() -> Void)?

    private func advanceTravel(_ dt: TimeInterval) {
        guard var t = travel else { return }
        t.t = min(1, t.t + dt / t.duration)
        travel = t
        // Ease in/out, plus a shallow arc so it reads as flight, not a slide.
        let e = t.t < 0.5 ? 2 * t.t * t.t : 1 - pow(-2 * t.t + 2, 2) / 2
        let lift = sin(e * .pi) * self.personality.roaming.arc
        let x = t.from.x + (t.to.x - t.from.x) * e
        let y = t.from.y + (t.to.y - t.from.y) * e + lift
        window.setFrameOrigin(NSPoint(x: x, y: y))
        if t.t >= 1 {
            window.setFrameOrigin(t.to)
            travel = nil
            let done = travelDone
            travelDone = nil
            done?()
        }
    }

    private func cancelTravel() {
        travel = nil
        travelDone = nil
    }

    // MARK: - Turns

    /// The set-piece performances, as opposed to idle fidgeting.
    enum Turn: CaseIterable { case joke, riddle, fact, twister, song }

    /// Run one, then hand back to idle. Safe to call from a menu at any time.
    /// `userAsked` distinguishes a menu request from one of his own idle
    /// beats: being asked for something is attention and lifts his energy,
    /// whereas entertaining himself should not wind him up.
    func perform(_ turn: Turn, userAsked: Bool = false) {
        guard mode != .away else { return }
        guard personality.speaks else {
            // No voice, but plenty to say: the sprite rips talk in boxes, out
            // of GameTalk rather than out of a speech pack.
            stopSpeaking()
            cancelTravel()
            mode = .idle
            if userAsked { stir(0.3) }
            switch turn {
            case .joke: tellGameJoke()
            case .fact: say(recentFacts.pick(from: GameTalk.facts))
            default: say(recentLines.pick(from: GameTalk.smallTalk(for: personality.id)))
            }
            return
        }
        stopSpeaking()
        cancelTravel()
        mode = .idle
        if userAsked { stir(0.3) }
        plog("turn: \(turn)\(userAsked ? " (asked)" : "")")
        switch turn {
        case .joke: tellJoke()
        case .riddle: tellRiddle()
        case .fact: tellFact()
        case .twister: tellTwister()
        case .song: sing()
        }
    }

    /// The same shape as `tellJoke`, for a character with no voice: the beat
    /// between setup and punchline is measured in reading time instead.
    private func tellGameJoke() {
        let setup = recentJokes.pick(from: GameTalk.jokes.map(\.setup))
        guard let joke = GameTalk.jokes.first(where: { $0.setup == setup }) else { return }
        say(joke.setup)
        afterSpeaking(0.8) { [weak self] in
            guard let self, self.mode == .idle else { return }
            self.perform(self.move(self.personality.flourishes)) {
                self.say(joke.punchline)
            }
        }
    }

    /// Setup, a beat to let it land, then the punchline with a flourish.
    private func tellJoke() {
        // Pick once: pick() mutates, so calling it inside first(where:) would
        // re-roll for every element and compare against a moving target.
        let setup = recentJokes.pick(from: (pack?.jokes ?? []).map(\.setup))
        guard mode == .idle,
              let joke = (pack?.jokes ?? []).first(where: { $0.setup == setup }) else { return }
        say(joke.setup)
        afterSpeaking(0.7) { [weak self] in
            guard let self, self.mode == .idle else { return }
            let move = self.recentMoves.pick(
                from: ["cheer", "flourish", "announce"].filter {
                    self.store.animation($0) != nil
                })
            self.perform(move) {
                self.say(joke.punchline, pose: "announce")
            }
        }
    }

    /// Same shape, but a longer pause — you're meant to have a go.
    private func tellRiddle() {
        guard mode == .idle,
              let riddle = (pack?.riddles ?? []).randomElement() else { return }
        say(riddle.question)
        afterSpeaking(2.6) { [weak self] in
            guard let self, self.mode == .idle else { return }
            self.perform(self.move(["point", "gestureUp"])) { self.say(riddle.answer) }
        }
    }

    private func tellFact() {
        guard mode == .idle else { return }
        let fact = recentFacts.pick(from: (pack?.facts ?? []))
        let move = firstAvailable(["idea", "announce", "cheer"])
        let pose = store.talkPoses["idea"] != nil ? "idea" : "neutral"
        perform(move) { [weak self] in
            self?.say(fact, pose: pose)
        }
    }

    private func tellTwister() {
        guard mode == .idle else { return }
        say(recentLines.pick(from: (pack?.twisters ?? [])))
    }

    private func sing() {
        guard mode == .idle, voice.isEnabled else {
            // Nothing to sing with; do something visual instead.
            perform(recentMoves.pick(from: ["cheer", "flourish"]))
            return
        }
        let title = recentSongs.pick(from: (pack?.songs ?? []).map(\.title))
        guard let song = (pack?.songs ?? []).first(where: { $0.title == title }) else { return }

        mode = .busy
        let token = bump()
        say(song.intro)
        afterSpeaking(0.5) { [weak self] in
            guard let self, self.current(token) else { return }
            self.animator.play("announce")
            self.voice.sing(song) { [weak self] phrase in
                // Bubble follows the melody, one lyric line at a time.
                guard let self, self.current(token) else { return }
                self.showBubble(song.phrases[phrase].lyric, duration: 30)
            } onStart: { [weak self] duration in
                guard let self, self.current(token) else { return }
                plog(String(format: "  singing %@ for %.1fs", song.title, duration))
                self.animator.play("flourish")
                self.animator.beginTalking(pose: "neutral")
                self.bubbleUntil = self.clock + duration + 0.4
            } onFinish: { [weak self] in
                guard let self, self.current(token) else { return }
                self.animator.endTalking()
                // Back to idle first — perform() only runs from idle, so
                // calling it while still busy would strand him mid-song.
                self.mode = .idle
                self.scheduleBeat()
                self.perform(self.recentMoves.pick(
                    from: ["proud", "cheer", "announce"].filter {
                        self.store.animation($0) != nil
                    }))
            }
        }
    }

    /// When the current line will have finished, in wall-clock seconds from now.
    private func speechEnds() -> TimeInterval { max(0, bubbleUntil - clock) }

    /// Run `work` once he has actually finished the line he is on.
    ///
    /// `say` sets a provisional duration from the text and corrects it when the
    /// audio's real length is known, so scheduling off the estimate lands early
    /// or late. Polling the actual end is accurate either way, and matters most
    /// for a joke's punchline and for two-hander dialogue.
    private func afterSpeaking(_ gap: TimeInterval = 0.35, _ work: @escaping () -> Void) {
        func check() {
            guard bubbleUntil > 0, clock < bubbleUntil else {
                DispatchQueue.main.asyncAfter(deadline: .now() + gap, execute: work)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { check() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { check() }
    }

    private func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, seconds), execute: work)
    }

    // MARK: - Two-hander dialogue

    /// Free to be pulled into a conversation.
    var isAvailable: Bool { mode == .idle && bubbleUntil == 0 }

    var centreX: CGFloat { window.frame.midX }
    var frameOnScreen: NSRect { window.frame }

    /// Turn to look at something. The sprite sets all face the viewer's left
    /// when unmirrored, so facing right means mirroring.
    func face(toward x: CGFloat) {
        animator.mirrored = x > window.frame.midX
    }

    /// Perform one clip as part of an exchange with somebody else: turn to
    /// them, play it, make the noise that goes with it, then call back.
    ///
    /// The speaking characters have `deliver` for this. Two characters who
    /// can't talk still need a way to take turns, and taking turns is most of
    /// what makes an exchange read as an exchange.
    func act(_ preferred: [String], facing: CGFloat?,
             completion: @escaping () -> Void) {
        guard mode == .idle else { completion(); return }
        stopSpeaking()
        if let facing { face(toward: facing) }
        let clip = move(preferred)
        let token = bump()
        mode = .busy
        makeNoise(noise(for: clip))
        animator.play(clip) { [weak self] in
            guard let self, self.current(token) else { completion(); return }
            self.mode = .idle
            self.animator.play("rest")
            completion()
        }
    }
    var isSpeakingNow: Bool { bubbleUntil > 0 }

    /// Deliver one line of an exchange, optionally with a gesture first and
    /// turned toward whoever he is talking to. Calls back when the line lands.
    func deliver(_ text: String, move: String?, facing: CGFloat?,
                 completion: @escaping () -> Void) {
        guard mode == .idle else { completion(); return }
        stopSpeaking()
        stir(0.15)
        if let facing {
            // The directional clips aim to the viewer's right unmirrored.
            animator.mirrored = facing < window.frame.midX
        }
        let token = bump()

        let speak = { [weak self] in
            guard let self, self.current(token) else { completion(); return }
            self.say(text)
            self.afterSpeaking(0.3) {
                guard self.current(token) else { return }
                self.animator.mirrored = false
                completion()
            }
        }

        guard let move, store.animation(move) != nil else { speak(); return }
        mode = .busy
        animator.play(move) { [weak self] in
            guard let self, self.current(token) else { completion(); return }
            self.mode = .idle
            self.animator.play("rest")
            speak()
        }
    }

    /// Hold off his own idle beats — used while a conversation is running so
    /// he doesn't wander off mid-sentence.
    func holdBeats(for seconds: TimeInterval) {
        nextBeat = max(nextBeat, clock + seconds)
    }

    /// Walk/fly over to stand near `x`, on the same screen.
    func moveNear(x: CGFloat, completion: (() -> Void)? = nil) {
        guard mode == .idle, let screen = currentScreen() else { completion?(); return }
        let vf = screen.visibleFrame
        let f = window.frame
        let side: CGFloat = x < vf.midX ? 1 : -1
        let target = min(max(x + side * (f.width * 0.85), vf.minX + 8),
                         vf.maxX - f.width - 8)
        flyTo(NSPoint(x: target, y: f.origin.y)) { completion?() }
    }

    // MARK: - Direct interaction

    /// Say hello, in his own words, sometimes noting the time of day.
    func greet() {
        guard mode == .idle else { return }
        stopSpeaking()
        stir(0.2)
        guard personality.speaks else {
            perform(move(["celebrate", "guard", "stretch"]))
            return
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let pool = Bool.random() ? self.timeOfDayPool(hour) : (self.pack?.greetings ?? [])
        perform(move(["greet", "cheer"])) { [weak self] in
            guard let self else { return }
            self.say(self.recentLines.pick(from: pool))
        }
    }

    func poke() {
        guard mode == .idle else { return }
        stopSpeaking()
        stir(0.3)
        pokeStreak = (clock - lastPokeAt < 7) ? pokeStreak + 1 : 1
        lastPokeAt = clock

        let reaction = Self.reaction(forStreak: pokeStreak)
        plog("poked x\(pokeStreak) -> \(reaction)")

        let clip: String
        let pool: [String]?
        switch reaction {
        case .startled:
            clip = move(["surprised", "greet", "guard"])
            pool = pack?.poked ?? []
        case .playful:
            clip = move(["cheer", "greet", "point", "shrug", "punch", "jab"])
            pool = pack?.poked ?? []
        case .tiring:
            clip = move(["shrug", "lookAround", "guard"])
            pool = pack?.pokedAgain ?? []
        case .hadEnough:
            // He has stopped finding it interesting. A blink and nothing else.
            nextBlink = clock
            return
        }

        perform(clip) { [weak self] in
            guard let self, self.chattiness != .quiet, let pool else { return }
            self.say(self.recentLines.pick(from: pool))
        }
    }

    func doATrick() {
        guard mode != .away else { return }
        stopSpeaking()
        stir(0.25)
        cancelTravel()
        mode = .idle
        performBit(personality.bits.randomElement()!)
    }

    func comeHere() {
        guard mode != .away else { return }
        stopSpeaking()
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSEvent.mouseLocation)
        }) ?? NSScreen.main else { return }
        cancelTravel()
        mode = .idle
        let vf = screen.visibleFrame
        let f = window.frame
        let mouse = NSEvent.mouseLocation
        let x = min(max(mouse.x - f.width / 2, vf.minX + 8), vf.maxX - f.width - 8)
        let y = min(max(mouse.y - f.height * 0.9, vf.minY + 8), vf.maxY - f.height - 8)
        flyTo(NSPoint(x: x, y: y)) { [weak self] in
            self?.say("Reporting for duty.")
        }
    }

    private func wireWindow() {
        window.onClick = { [weak self] in self?.poke() }
        window.onDragBegan = { [weak self] in
            guard let self else { return }
            self.stopSpeaking()
            self.cancelTravel()
            self.stir(0.35)
            plog("drag began")
            _ = self.bump()
            self.mode = .dragging
            self.bubble.dismiss()
            self.bubbleUntil = 0
            self.animator.endTalking()
            self.animator.play(self.personality.travel.cruise)
        }
        window.onDragMoved = { [weak self] _ in
            self?.repositionBubble()
        }
        window.onDragEnded = { [weak self] in
            guard let self else { return }
            self.mode = .busy
            plog("drag ended")
            let settle = {
                self.goIdle()
                if self.chattiness != .quiet {
                    self.say(self.recentLines.pick(from: (self.pack?.dropped ?? [])))
                }
            }
            if case .flies(_, _, let land) = self.personality.travel {
                self.animator.play(land) { settle() }
            } else {
                settle()
            }
        }
    }

    /// Keep him on-screen if displays change underneath him.
    func clampToScreen() {
        guard mode != .away, let screen = currentScreen() else { return }
        let vf = screen.visibleFrame
        var o = window.frame.origin
        o.x = min(max(o.x, vf.minX), vf.maxX - window.frame.width)
        o.y = min(max(o.y, vf.minY), vf.maxY - window.frame.height)
        window.setFrameOrigin(o)
    }
}
