import AVFoundation
import AppKit
_ = NSApplication.shared

// The crash this guards against: AVAudioPlayerNode.play() raises an uncatchable
// ObjC exception if the engine's IO thread isn't rendering. Speak repeatedly
// while the audio graph is disturbed underneath — what a device coming and
// going looks like — and check nothing dies.
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}
func pump(_ s: TimeInterval, while active: () -> Bool = { true }) {
    let dl = Date().addingTimeInterval(s)
    while Date() < dl, active() {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
}

let v = Voice()
v.volume = 0.02

print("speaking repeatedly while the graph is disturbed:")
var completed = 0, started = 0
for round in 1...5 {
    var done = false
    v.speak("Round \(round), still here.") { _ in started += 1 } onFinish: {
        completed += 1; done = true
    }
    // Kick the configuration between utterances, the way plugging headphones
    // in and out does.
    if round % 2 == 0 {
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: nil)
    }
    pump(8) { !done }
    if !done { v.stop() }
}
check("survived five utterances across graph changes", true)
check("they started", started >= 4, "\(started) of 5")
check("they completed", completed >= 4, "\(completed) of 5")

print("\nrapid interruption:")
for _ in 1...12 {
    v.speak("Interrupt me.") { _ in } onFinish: {}
    pump(0.05)
    v.stop()
}
check("stopping mid-render doesn't crash", true)

print("\nstill works afterwards:")
var reported = -1.0, done = false
v.speak("And afterwards it still speaks.") { reported = $0 } onFinish: { done = true }
pump(8) { reported < 0 }
check("still reports a duration", reported > 0.5, "\(reported)")
pump(reported + 4) { !done }
check("still completes", done)
v.stop()

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
