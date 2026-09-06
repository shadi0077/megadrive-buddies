import AppKit

/// Plays animation clips into a `BuddyView` and drives per-frame motion.
///
/// A single 60 Hz tick advances both the sprite clock and any in-flight
/// movement, so the two never drift apart.
final class Animator {
    private let store: SpriteStore
    private let view: BuddyView
    private var timer: Timer?

    private var current: AnimationDef?
    private var elapsed: TimeInterval = 0
    private var lastTick: TimeInterval = 0
    private var onFinish: (() -> Void)?

    /// Lip-sync overrides the mouth patch while a line is being "spoken".
    private var talking: TalkPose?
    private var mouthClock: TimeInterval = 0

    /// Called every tick with the delta, for movement.
    var onTick: ((TimeInterval) -> Void)?

    /// Live mouth openness (0...1) while a voice is speaking. When this is
    /// nil the mouth falls back to cycling visemes on a timer.
    var mouthLevel: (() -> Float?)?

    init(store: SpriteStore, view: BuddyView) {
        self.store = store
        self.view = view
    }

    var currentName: String? { current?.name }

    func start() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps the bird alive while menus are tracking or a drag is live.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Play a clip. Non-looping clips call `then` when they finish.
    func play(_ name: String, then: (() -> Void)? = nil) {
        guard let def = store.animation(name) else {
            then?()
            return
        }
        current = def
        elapsed = 0
        onFinish = then
        render()
    }

    /// Hold a single pose (used while dragging, or as a talk base).
    func hold(_ frame: Int) {
        current = AnimationDef(name: "hold", steps: [Step(frame: frame, overlay: nil)],
                               fps: 1, loop: true)
        elapsed = 0
        onFinish = nil
        render()
    }

    /// A clip to loop while speaking, for characters whose sprite set has no
    /// mouth patches.
    ///
    /// Five of the Office assistants were ripped as finished frames with no
    /// overlays, so there is nothing to composite a mouth from — Rover has six
    /// small frames in seven hundred, and none of them is a mouth. Holding a
    /// still pose through a whole sentence reads as a freeze, so they gesture
    /// instead, which is what the original characters did for these
    /// animations anyway.
    var talkLoop: String?
    private var loopingTalk = false

    /// Start lip-syncing in `pose`, holding the body frame its mouth patches
    /// were drawn for. Pass nil (or a pose with no mouth set in the sprite
    /// data) to speak without lip-sync — which gestures instead if this
    /// character has a talk loop, and otherwise leaves the animation alone.
    func beginTalking(pose: String?) {
        if let pose, let talk = store.talkPoses[pose] {
            talking = talk
            mouthClock = 0
            hold(talk.body)
            return
        }
        talking = nil
        guard let name = talkLoop, let def = store.animation(name) else { return }
        loopingTalk = true
        current = AnimationDef(name: def.name, steps: def.steps, fps: def.fps, loop: true)
        elapsed = 0
        onFinish = nil
        render()
    }

    func endTalking() {
        talking = nil
        guard loopingTalk else { return }
        loopingTalk = false
        // Back to standing, or they gesture on after the sentence ends.
        if store.animation("rest") != nil { play("rest") }
    }

    /// Mirrors the sprite horizontally. What that *means* depends on the clip —
    /// the flight frames fly left unmirrored, the point aims right unmirrored —
    /// so callers set it explicitly rather than going through a "facing" idea
    /// that would be wrong for half the animations.
    var mirrored: Bool {
        get { view.mirrored }
        set { view.mirrored = newValue }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.25)   // clamp after sleep/stalls
        lastTick = now

        elapsed += dt
        mouthClock += dt
        onTick?(dt)

        guard let def = current else { return }
        if !def.loop {
            let total = def.duration
            if elapsed >= total {
                elapsed = total
                render()
                let done = onFinish
                onFinish = nil
                current = nil
                done?()
                return
            }
        }
        render()
    }

    private func render() {
        guard let def = current else { return }
        var index = Int(elapsed * def.fps)
        if def.loop {
            index %= def.steps.count
        } else {
            index = min(index, def.steps.count - 1)
        }
        var step = def.steps[index]

        // Mouth patches are drawn to register with one specific body frame, so
        // they may only ever be composited onto that frame. Anything else puts
        // a rectangle of beak in the middle of the wrong pose.
        if let talk = talking, step.frame == talk.body {
            if let level = mouthLevel?() {
                step = Step(frame: step.frame, overlay: talk.mouth(forLevel: level))
            } else {
                // No audio to follow: cycle visemes at a chatter-like rate.
                let m = Int(mouthClock * 9) % talk.mouths.count
                step = Step(frame: step.frame, overlay: talk.mouths[m])
            }
        }
        view.step = step
    }
}
