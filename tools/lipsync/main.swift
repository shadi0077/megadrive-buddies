import AppKit
import AVFoundation

// Speaks a line, samples the loudness envelope while it plays, and renders the
// visemes it actually chose as a filmstrip with the level plotted underneath.
_ = NSApplication.shared
let who = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"

guard let store = SpriteStore(character: who, bundle: Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"] ?? "build/Desktop Buddies.app")!),
      let pose = store.talkPoses["neutral"] else { print("no sprites"); exit(1) }

let line = "Is it cracker o'clock yet?"
let voice = Voice()
voice.volume = 0.03
var duration: TimeInterval = -1
var done = false
var samples: [(t: TimeInterval, level: Float)] = []

voice.speak(line) { duration = $0 } onFinish: { done = true }
var dl = Date().addingTimeInterval(4)
while duration < 0, Date() < dl { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.008)) }

let began = CACurrentMediaTime()
dl = Date().addingTimeInterval(duration + 1)
while !done, Date() < dl {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    if voice.isSpeaking { samples.append((CACurrentMediaTime() - began, voice.level)) }
}
print(String(format: "spoke %.2fs, %d samples", duration, samples.count))

// Evenly spaced stills across the utterance.
let cols = 14
let picks = (0..<cols).map { i -> (t: TimeInterval, level: Float) in
    samples.isEmpty ? (0, 0) : samples[i * (samples.count - 1) / max(cols - 1, 1)]
}

let cell = NSSize(width: 120, height: 96)
let plotH: CGFloat = 54
let labelH: CGFloat = 20
let pad: CGFloat = 4
let size = NSSize(width: CGFloat(cols) * (cell.width + pad) + pad,
                  height: cell.height + labelH + plotH + 34)
let out = NSImage(size: size)
out.lockFocus()
NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.21, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

("lip sync: \"\(line)\"  —  beak follows speech loudness" as NSString).draw(
    at: NSPoint(x: 6, y: size.height - 22),
    withAttributes: [.font: NSFont.boldSystemFont(ofSize: 13),
                     .foregroundColor: NSColor(calibratedRed: 1, green: 0.86, blue: 0.47, alpha: 1)])

for (i, pick) in picks.enumerated() {
    let x = pad + CGFloat(i) * (cell.width + pad)
    let y = size.height - 30 - cell.height
    NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.32, alpha: 1).setFill()
    NSRect(x: x, y: y, width: cell.width, height: cell.height).fill()

    let view = BuddyView(store: store)
    view.frame = NSRect(origin: .zero, size: cell)
    view.step = Step(frame: pose.body, overlay: pose.mouth(forLevel: pick.level))
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    rep.draw(in: NSRect(x: x, y: y, width: cell.width, height: cell.height))

    (String(format: "%.2fs  %.0f%%", pick.t, pick.level * 100) as NSString).draw(
        at: NSPoint(x: x + 4, y: y - 15),
        withAttributes: [.font: NSFont.systemFont(ofSize: 10),
                         .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 1)])
}

// Envelope plot along the bottom.
let plot = NSRect(x: pad, y: 6, width: size.width - 2 * pad, height: plotH - 6)
NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.16, alpha: 1).setFill()
plot.fill()
if samples.count > 1 {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: plot.minX, y: plot.minY))
    for (i, s) in samples.enumerated() {
        let px = plot.minX + plot.width * CGFloat(i) / CGFloat(samples.count - 1)
        path.line(to: NSPoint(x: px, y: plot.minY + plot.height * CGFloat(s.level)))
    }
    path.line(to: NSPoint(x: plot.maxX, y: plot.minY))
    path.close()
    NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.45, alpha: 0.85).setFill()
    path.fill()
}
out.unlockFocus()

if let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "shots/lipsync.png"))
    print("wrote shots/lipsync.png")
}
