import AppKit

// Regression test for "talking sprites clip with movement".
//
// Mouth patches are drawn to register with exactly one body frame. If one is
// composited onto any other frame you get a rectangle of beak floating in the
// middle of the wrong pose. This drives the animator through the cases that
// used to do that and asserts the invariant holds.
_ = NSApplication.shared
let who = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"

guard let store = SpriteStore(character: who, bundle: Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"] ?? "build/Desktop Buddies.app")!) else {
    print("cannot load sprites"); exit(1)
}
// A character with no mouth patches has no registration to violate — but it
// does have the other half of the invariant to satisfy: it must gesture
// through its lines rather than freeze, or a whole sentence plays over a still
// body. That's the only thing worth checking here for those characters.
guard let neutral = store.talkPoses["neutral"] else {
    print("no mouth patches in this sprite set — checking the talk loop instead")
    let loops = store.animation("express") ?? store.animation("pant")
        ?? store.animation("fidget") ?? store.animation("rest")
    guard let loop = loops else { print("  FAIL nothing to loop"); exit(1) }
    let view = BuddyView(store: store)
    let animator = Animator(store: store, view: view)
    animator.talkLoop = loop.name
    animator.start()
    var frames: [Int] = []
    animator.beginTalking(pose: "neutral")
    let deadline = Date().addingTimeInterval(1.0)
    while Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.008))
        if let f = view.step?.frame { frames.append(f) }
    }
    let inClip = Set(loop.steps.map(\.frame))
    check("gestures rather than freezing while speaking", Set(frames).count > 1,
          "\(Set(frames).count) distinct frames")
    check("the frames come from the talk loop", frames.allSatisfy(inClip.contains))
    check("no overlay is composited", view.step?.overlay == nil)
    animator.endTalking()
    print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
    exit(failures == 0 ? 0 : 1)
}

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") }
    else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

/// Runs the animator for `seconds`, returning every distinct step it rendered.
func observe(_ seconds: TimeInterval, _ setup: (Animator) -> Void) -> [Step] {
    let view = BuddyView(store: store)
    let animator = Animator(store: store, view: view)
    animator.start()
    setup(animator)
    var seen: [Step] = []
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.008))
        if let s = view.step, seen.last != s { seen.append(s) }
    }
    animator.stop()
    return seen
}

func misregistered(_ steps: [Step], body: Int) -> [Step] {
    steps.filter { $0.overlay != nil && $0.frame != body }
}

print("talking while a clip plays over the top:")
// Whatever this character has that would take the body away from the pose.
let clips = ["fly", "vineSwing", "cheer", "arrive", "depart", "reading",
             "listening", "sunglassesIdle", "sitting"]
    .filter { store.animation($0) != nil }
for clip in clips {
    let steps = observe(0.8) { a in
        a.beginTalking(pose: "neutral")
        a.play(clip)                       // clip takes the body away from the pose
    }
    let bad = misregistered(steps, body: neutral.body)
    check("\(clip): no mouth patch on a foreign pose", bad.isEmpty,
          "\(bad.count) bad steps e.g. frame \(bad.first?.frame ?? -1)")
}

print("\ntalking while the body is holding the right pose:")
let held = observe(0.8) { $0.beginTalking(pose: "neutral") }
check("lip-sync actually happens", held.contains { $0.overlay != nil },
      "no overlay was ever emitted")
check("every overlay sits on its own body", misregistered(held, body: neutral.body).isEmpty)
check("more than one viseme is used",
      Set(held.compactMap(\.overlay)).count > 1,
      "visemes: \(Set(held.compactMap(\.overlay)).count)")

print("\nposes with no mouth patches in the sprite set:")
let silent = observe(0.6) { a in
    a.beginTalking(pose: nil)
    a.play(store.animation("listening") != nil ? "listening" : "rest")
}
check("never composites an overlay", silent.allSatisfy { $0.overlay == nil })
check("leaves the animation running", silent.count > 1, "only \(silent.count) steps")

let unknown = observe(0.4) { $0.beginTalking(pose: "no-such-pose") }
check("an unknown pose is inert, not a crash", unknown.allSatisfy { $0.overlay == nil })

print("\nevery other pose this character has registers correctly too:")
for name in store.talkPoses.keys.sorted() where name != "neutral" {
    guard let pose = store.talkPoses[name] else { continue }
    let steps = observe(0.6) { $0.beginTalking(pose: name) }
    check("\(name): lip-syncs on body \(pose.body)",
          steps.contains { $0.overlay != nil } && misregistered(steps, body: pose.body).isEmpty)
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
