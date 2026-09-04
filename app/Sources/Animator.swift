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

    /// Called every tick with the delta, for movement.
    var onTick: ((TimeInterval) -> Void)?

    init(store: SpriteStore, view: BuddyView) {
        self.store = store
        self.view = view
    }

    var currentName: String? { current?.name }

    func start() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps them alive while menus are tracking or a drag is live.
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

    /// Hold a single frame (used while dragging).
    func hold(_ frame: Int) {
        current = AnimationDef(name: "hold", steps: [Step(frame: frame)],
                               fps: 1, loop: true)
        elapsed = 0
        onFinish = nil
        render()
    }

    /// Mirrors the sprite horizontally. Every rip faces the viewer's left
    /// unmirrored, but what mirroring *means* still depends on the clip, so
    /// callers set it explicitly rather than going through a "facing" idea
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
        view.step = def.steps[index]
    }
}
