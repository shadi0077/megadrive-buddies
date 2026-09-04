import AppKit

// Every shipped frame holds exactly one sprite.
//
// The sheet cutter finds horizontal bands and then columns inside them, so a
// column that happens to hold two stacked sprites came out as one frame — and
// the character rendered with a second body growing out of his head. Galsia
// shipped like that. Nothing about the frame's size gives it away; the only
// signal is a band of empty rows through the middle of it.
_ = NSApplication.shared
var failures = 0

let bundle = Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"]
                    ?? "build/MegaDrive Buddies.app")!

/// Rows of the image that are entirely transparent.
func gaps(in image: NSImage) -> Int {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return 0 }
    let h = rep.pixelsHigh, w = rep.pixelsWide
    var empty: [Bool] = []
    for y in 0..<h {
        var blank = true
        for x in 0..<w where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
            blank = false; break
        }
        empty.append(blank)
    }
    // Count runs of 5+ blank rows that have content above and below them.
    var runs = 0, run = 0
    for (y, blank) in empty.enumerated() {
        if blank { run += 1; continue }
        if run >= 5, empty[..<(y - run)].contains(false) { runs += 1 }
        run = 0
    }
    return runs
}

for p in Personality.all {
    guard let store = SpriteStore(character: p.id, bundle: bundle) else {
        print("  FAIL \(p.name) does not load"); failures += 1; continue
    }
    let used = Set(store.animations.values.flatMap { $0.steps.map(\.frame) })
    var split: [Int] = []
    for index in used.sorted() {
        guard let (image, _) = store.image(index) else { continue }
        if gaps(in: image) > 0 { split.append(index) }
    }
    if split.isEmpty {
        print("  ok   \(p.name): \(used.count) frames, one sprite each")
    } else {
        print("  FAIL \(p.name): frames holding more than one sprite: "
              + split.map(String.init).joined(separator: ", "))
        failures += 1
    }
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
