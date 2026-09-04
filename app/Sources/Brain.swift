import AppKit

/// Set BUDDY_DEBUG=1 to trace behaviour decisions on stderr.
let buddyDebug = ProcessInfo.processInfo.environment["BUDDY_DEBUG"] == "1"

func plog(_ message: @autoclosure () -> String) {
    guard buddyDebug else { return }
    FileHandle.standardError.write("[cast] \(message())\n".data(using: .utf8)!)
}

/// How often they do anything at all.
enum Liveliness: Int, CaseIterable {
    case calm = 0, occasional = 1, restless = 2

    var title: String {
        switch self {
        case .calm: return "Calm"
        case .occasional: return "Occasional"
        case .restless: return "Restless"
        }
    }
    /// Multiplier on the character's own beat interval, so a lumbering Max and
    /// a teenager on rollerblades both settle or liven up without losing the
    /// difference between them.
    var pace: Double {
        switch self {
        case .calm: return 1.7
        case .occasional: return 1.0
        case .restless: return 0.62
        }
    }
}

/// Decides what a character does and when. Everything user-visible funnels
/// through here so only one thing is ever in flight at a time.
final class Brain {
    let personality: Personality
    /// The game's own sound effects — what these characters have instead of a
    /// voice.
    let sounds: SoundBank?

    /// Trace lines carry the character's name, so a two-hander is readable.
    private func plog(_ message: @autoclosure () -> String) {
        guard buddyDebug else { return }
        FileHandle.standardError.write(
            "[\(personality.id)] \(message())\n".data(using: .utf8)!)
    }

    /// Set by the Cast: false while somebody else has the floor. Two of them
    /// swinging at once is a scrum rather than a fight.
    var mayAct: (() -> Bool)?
    private let store: SpriteStore
    private let animator: Animator
    private let window: BuddyWindow

    private enum Mode { case away, busy, idle, dragging }
    private var mode: Mode = .away

    /// Bumped on every state change. Deferred callbacks capture the value
    /// they were issued under and bail if the bird has moved on since.
    private var generation = 0
    private func bump() -> Int { generation += 1; return generation }
    private func current(_ token: Int) -> Bool { generation == token }

    private var nextBeat: TimeInterval = 0
    private var clock: TimeInterval = 0

    /// In-flight travel, driven from the animator tick.
    private var travel: (from: NSPoint, to: NSPoint, t: Double, duration: Double)?

    /// How lively they are, 0...1. Rises when something happens to them and
    /// decays back toward a baseline set by whether anyone is actually at the
    /// machine. The gap between beats and what they pick to do both read off
    /// it, so there are busy spells and quiet spells instead of one flat tempo.
    private var energy: Double = 0.55
    private var wasAway = false
    /// When he last entered .busy, for the stuck-state backstop below.
    private var busySince: TimeInterval = 0

    private var lastCursor: NSPoint = .zero
    private var cursorSpeed: Double = 0
    private var lastNoticed: TimeInterval = -100
    private var cursorWasNear = false

    private var pokeStreak = 0
    private var lastPokeAt: TimeInterval = -100

    private var recentMoves = RecentPicks(limit: 4)

    var liveliness: Liveliness = .occasional {
        didSet { scheduleBeat() }
    }

    var isVisible: Bool { mode != .away }

    init(personality: Personality, store: SpriteStore,
         animator: Animator, window: BuddyWindow) {
        self.personality = personality
        self.sounds = personality.soundSet.flatMap { SoundBank(set: $0) }
        self.store = store
        self.animator = animator
        self.window = window
        animator.onTick = { [weak self] dt in self?.tick(dt) }
        wireWindow()
    }

    /// Make a noise.
    @discardableResult
    private func makeNoise(_ kind: SoundBank.Kind) -> Bool {
        let played = sounds?.play(kind) ?? false
        if played { plog("  sound: \(kind)") }
        return played
    }

    /// The noise that suits a movement. Attacks land, efforts grunt.
    private func noise(for clip: String) -> SoundBank.Kind {
        switch clip {
        case "grandUpper", "flameArc", "uppercut", "celebrate", "arrive":
            return .shout
        case "knockdown", "getUp":
            return .impact
        default:
            return .effort
        }
    }

    var displayName: String { personality.name }

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
        guard mode == .idle else { return }
        plog("welcome back")
        energy = 0.9
        scheduleBeat()
        perform(move(["celebrate", "guard", "stretch"]))
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
        guard mode == .idle, clock - lastNoticed > 9 else { return }

        let dx = now.x - frame.midX
        guard mayAct?() ?? true else { return }
        lastNoticed = clock
        stir(0.2)
        plog(String(format: "noticed cursor dx=%.0f speed=%.0f", dx, cursorSpeed))

        if cursorSpeed > 1100 {
            perform(move(["surprised", "guard", "jumpKick"]))   // shot past him
        } else {
            // The directional clips aim to the viewer's right unmirrored.
            animator.mirrored = dx < 0
            perform(move(["point", "punch", "jab"])) { [weak self] in
                self?.animator.mirrored = false
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
            self?.goIdle()
        }
    }

    /// Where they were standing before leaving, so they come back to it.
    private(set) var lastOrigin: NSPoint = .zero

    func vanish(_ completion: (() -> Void)? = nil) {
        guard mode != .away else { completion?(); return }
        lastOrigin = window.frame.origin
        cancelTravel()
        mode = .busy
        animator.play("depart") { [weak self] in
            self?.hideNow()
            completion?()
        }
    }

    private func hideNow() {
        sounds?.stop()
        mode = .away
        window.orderOut(nil)
    }

    // MARK: - Beats

    private func goIdle() {
        _ = bump()
        mode = .idle
        animator.mirrored = false
        animator.play("rest")
        scheduleBeat()
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
        // Every long sequence hands back through a deferred callback, and a
        // dropped one would leave them frozen mid-bit with no way out. Twice
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

        updateCursor(dt)
        if mode == .idle, clock >= nextBeat { idleBeat() }
    }

    private enum Beat { case settle, wander, bit, flourish }

    private func idleBeat() {
        // Don't start anything while somebody else has the floor.
        guard mayAct?() ?? true else {
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
                                      (.flourish, 0.20 + 0.48 * energy)],
                                     roll: Double.random(in: 0..<1)) ?? .settle

        switch beat {
        case .settle:
            // Often enough, a settle beat is simply staying put. Not every beat
            // has to produce a movement — standing guard is a thing they do.
            guard Double.random(in: 0...1) > 0.45 else { plog("  settle: stays put"); return }
            perform(move(["lookAround", "shrug", "guard", "stretch"]))
        case .wander:
            wanderNearby()
        case .bit:
            performBit(personality.bits.randomElement()!)
        case .flourish:
            perform(move(personality.flourishes))
        }
    }

    /// Pick one of these, ignoring any this character hasn't got, and falling
    /// back to its own flourishes if it has none of them.
    ///
    /// The rips don't cover the same ground: the Streets of Rage 2 four have a
    /// dozen moves each, an enemy sprite has three. Naming a clip directly
    /// means a character without it silently performs nothing at all, which is
    /// exactly what Axel did with "cheer" before this existed.
    private func move(_ preferred: [String]) -> String {
        let available = preferred.filter { store.animation($0) != nil }
        return recentMoves.pick(from: available.isEmpty ? personality.flourishes
                                                        : available)
    }

    /// Cut any noise short — used whenever something else takes over.
    private func stopNoise() {
        sounds?.stop()
    }

    /// Play one clip and hand back, whether or not the clip ever ends.
    ///
    /// `Animator.play` only calls back for a clip that finishes, and a looping
    /// one never does. That matters because half a platformer character's
    /// repertoire loops — a run cycle, Tails' flight — and performing one left
    /// the character stranded in `.busy` until the 60-second backstop caught
    /// it. Sonic did exactly that, standing on the spot running for a minute.
    /// So a looping clip is held for a moment and then handed back, which
    /// reads as a beat of running on the spot rather than a lock-up.
    private func playOnce(_ name: String, token: Int, then: @escaping () -> Void) {
        animator.play(name) { [weak self] in
            guard let self, self.current(token) else { return }
            then()
        }
        guard store.animation(name)?.loop == true else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.1...2.0)) {
            [weak self] in
            guard let self, self.current(token) else { return }
            then()
        }
    }

    private func perform(_ name: String, then: (() -> Void)? = nil) {
        guard mode == .idle else { return }
        plog("perform \(name)")
        makeNoise(noise(for: name))
        mode = .busy
        let token = bump()
        playOnce(name, token: token) { [weak self] in
            guard let self else { return }
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
        makeNoise(noise(for: bit.intro))
        playOnce(bit.intro, token: token) { [weak self] in
            guard let self else { return }
            let finishBit = {
                guard self.current(token) else { return }
                guard let outro = bit.outro else { self.goIdle(); return }
                self.makeNoise(self.noise(for: outro))
                self.animator.play(outro) { self.goIdle() }
            }
            guard let loop = bit.loop else { finishBit(); return }
            self.animator.play(loop)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: bit.hold)) {
                guard self.current(token) else { return }
                finishBit()
            }
        }
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
        walkTo(target)
    }

    /// Walk to a window origin.
    func walkTo(_ target: NSPoint, then: (() -> Void)? = nil) {
        guard mode == .idle || mode == .busy else { return }
        stopNoise()
        cancelTravel()
        mode = .busy
        let from = window.frame.origin
        plog(String(format: "walkTo (%.0f,%.0f) -> (%.0f,%.0f)", from.x, from.y, target.x, target.y))
        guard hypot(target.x - from.x, target.y - from.y) > 40 else {
            goIdle(); then?(); return
        }
        // The walk cycles face the viewer's left unmirrored, so mirror to go
        // the other way.
        animator.mirrored = target.x > from.x

        let token = bump()
        let distance = Double(hypot(target.x - from.x, target.y - from.y))
        // Travel time comes from the character's own pace, so the cruise
        // animation matches the distance covered instead of the window
        // teleporting under a looping walk cycle.
        let duration = max(0.4, min(14, distance / Double(personality.roaming.speed)))

        animator.play(personality.walk)
        travel = (from, target, 0, duration)
        travelDone = { [weak self] in
            guard let self, self.current(token) else { return }
            self.animator.mirrored = false
            self.goIdle()
            then?()
        }
    }

    private var travelDone: (() -> Void)?

    private func advanceTravel(_ dt: TimeInterval) {
        guard var t = travel else { return }
        t.t = min(1, t.t + dt / t.duration)
        travel = t
        // Ease in and out, so a walk starts and stops rather than snapping to
        // full speed. No arc — they're on their feet, not in the air.
        let e = t.t < 0.5 ? 2 * t.t * t.t : 1 - pow(-2 * t.t + 2, 2) / 2
        let x = t.from.x + (t.to.x - t.from.x) * e
        let y = t.from.y + (t.to.y - t.from.y) * e
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

    // MARK: - Squaring up

    /// Free to be pulled into an exchange.
    var isAvailable: Bool { mode == .idle }

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
    /// Taking turns is most of what makes an exchange read as an exchange —
    /// one swings, the other blocks and counters, and nobody moves while
    /// somebody else is mid-swing.
    func act(_ preferred: [String], facing: CGFloat?,
             completion: @escaping () -> Void) {
        guard mode == .idle else { completion(); return }
        stopNoise()
        if let facing { face(toward: facing) }
        let clip = move(preferred)
        let token = bump()
        mode = .busy
        makeNoise(noise(for: clip))
        playOnce(clip, token: token) { [weak self] in
            guard let self else { completion(); return }
            self.mode = .idle
            self.animator.play("rest")
            completion()
        }
    }
    /// Hold off their own idle beats — used while an exchange is running so
    /// nobody wanders off mid-fight.
    func holdBeats(for seconds: TimeInterval) {
        nextBeat = max(nextBeat, clock + seconds)
    }

    /// Walk over to stand near `x`, on the same screen.
    func moveNear(x: CGFloat, completion: (() -> Void)? = nil) {
        guard mode == .idle, let screen = currentScreen() else { completion?(); return }
        let vf = screen.visibleFrame
        let f = window.frame
        let side: CGFloat = x < vf.midX ? 1 : -1
        let target = min(max(x + side * (f.width * 0.85), vf.minX + 8),
                         vf.maxX - f.width - 8)
        walkTo(NSPoint(x: target, y: f.origin.y)) { completion?() }
    }

    // MARK: - Direct interaction

    /// Acknowledge you, in the only way they have.
    func greet() {
        guard mode == .idle else { return }
        stopNoise()
        stir(0.2)
        perform(move(["celebrate", "guard", "stretch"]))
    }

    func poke() {
        guard mode == .idle else { return }
        stopNoise()
        stir(0.3)
        pokeStreak = (clock - lastPokeAt < 7) ? pokeStreak + 1 : 1
        lastPokeAt = clock

        let reaction = Self.reaction(forStreak: pokeStreak)
        plog("poked x\(pokeStreak) -> \(reaction)")

        let clip: String
        switch reaction {
        case .startled:
            clip = move(["surprised", "guard", "jumpKick"])
        case .playful:
            clip = move(["celebrate", "point", "shrug", "punch", "jab"])
        case .tiring:
            clip = move(["shrug", "lookAround", "guard"])
        case .hadEnough:
            // They have stopped finding it interesting. Nothing at all.
            plog("  ignoring you")
            return
        }

        perform(clip)
    }

    func doATrick() {
        guard mode != .away else { return }
        stopNoise()
        stir(0.25)
        cancelTravel()
        mode = .idle
        performBit(personality.bits.randomElement()!)
    }

    func comeHere() {
        guard mode != .away else { return }
        stopNoise()
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
        walkTo(NSPoint(x: x, y: y)) { [weak self] in
            guard let self else { return }
            self.perform(self.move(["guard", "celebrate"]))
        }
    }

    private func wireWindow() {
        window.onClick = { [weak self] in self?.poke() }
        window.onDragBegan = { [weak self] in
            guard let self else { return }
            self.stopNoise()
            self.cancelTravel()
            self.stir(0.35)
            plog("drag began")
            _ = self.bump()
            self.mode = .dragging
            // Held up by the scruff, legs still going.
            self.animator.play(self.personality.walk)
        }
        window.onDragEnded = { [weak self] in
            guard let self else { return }
            plog("drag ended")
            self.makeNoise(.impact)
            self.goIdle()
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
