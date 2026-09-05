import AVFoundation
import AppKit

// Does sound actually reach the speakers?
//
// Deliberately not part of ./test.sh. Playing clips in bulk is what wedged the
// machine's audio server last time, and a CI runner has no audio device at
// all, so this is the one that gets run by hand: ./test.sh audio
_ = NSApplication.shared
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

let bundle = Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"]
                    ?? "build/MegaDrive Buddies.app")!

for set in ["_sor2", "_sonic2", "_ristar"] {
    guard let bank = SoundBank(set: set, bundle: bundle) else {
        check("\(set) loads", false); continue
    }
    for kind in SoundBank.Kind.allCases {
        guard let url = bank.source(for: kind) else {
            check("\(set)/\(kind.rawValue) resolves", false); continue
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            check("\(set)/\(kind.rawValue) opens", false); continue
        }
        let started = player.play()
        // play() returning true is the audio server accepting it; isPlaying a
        // moment later is the audio server actually doing it.
        Thread.sleep(forTimeInterval: 0.15)
        check("\(set)/\(kind.rawValue): \(url.lastPathComponent) plays",
              started && (player.isPlaying || player.duration < 0.2),
              started ? "accepted but not playing" : "refused")
        player.stop()
    }
}

// And the thing the last bug was about: a play that never returns must not
// take the caller with it.
let bank = SoundBank(set: "_sor2", bundle: bundle)!
let began = Date()
for _ in 0..<12 { bank.play(.effort) }
let spent = Date().timeIntervalSince(began)
check(String(format: "twelve sounds queued in %.0f ms, off the calling thread", spent * 1000),
      spent < 0.25, String(format: "%.2fs", spent))
Thread.sleep(forTimeInterval: 0.6)
bank.stop()

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
