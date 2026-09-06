import AppKit

// The speech bubble: does it fit the text, sit where it's told, and read at
// the size it will actually be seen at?
_ = NSApplication.shared
var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

let longestFact: String = GameTalk.facts.max(by: { $0.count < $1.count }) ?? ""
let samples: [String] = [
    "Groovy.",
    "Blast processing.",
    "What's a hedgehog's favourite kind of music?",
    "Sega is short for Service Games. It started out supplying coin-op machines to army bases in Japan.",
    longestFact,
]

print("every line fits a bubble:")
for text in samples {
    let size = BubbleView.size(for: text)
    // Wrapped text plus the padding either side: anything wider means the
    // wrapping didn't happen and the box is about to run off the screen.
    let padding: CGFloat = BubbleView.inset.left + BubbleView.inset.right
    let widest: CGFloat = BubbleView.maxTextWidth + padding + 8
    let fits: Bool = size.width <= widest
    check("\(Int(size.width))x\(Int(size.height)) for \(text.prefix(28))…", fits,
          "\(size.width) > \(widest)")
}

print("\nnothing in the repertoire is too long to read in one bubble:")
// A bubble taller than this covers the character it belongs to.
var tallest: [String] = GameTalk.facts
tallest += GameTalk.idle
tallest += GameTalk.jokes.map(\.setup)
tallest += GameTalk.jokes.map(\.punchline)
tallest += GameTalk.exchanges.flatMap { $0.map(\.text) }
tallest += GameTalk.personal.values.flatMap { $0 }
let worst = tallest.max(by: { BubbleView.size(for: $0).height < BubbleView.size(for: $1).height })!
check("tallest bubble is \(Int(BubbleView.size(for: worst).height))pt",
      BubbleView.size(for: worst).height < 170, worst)
check("every line reads in under nine seconds",
      tallest.allSatisfy { Brain.readingTime($0) <= 9.0 })

/// Render a bubble into a bitmap that actually has an alpha channel.
///
/// `bitmapImageRepForCachingDisplay` hands back an opaque bitmap for a view
/// with no layer, which turns every transparent pixel white — fine for a
/// screenshot on a white page, useless for checking what the bubble covers.
func render(_ view: BubbleView) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(view.bounds.width),
                               pixelsHigh: Int(view.bounds.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

print("\nthe tail points at the character:")
let view = BubbleView(frame: NSRect(x: 0, y: 0, width: 240, height: 80))
view.text = samples[3]
for (name, side) in [("below", BubbleView.TailSide.bottom), ("above", .top)] {
    view.tail = side
    view.tailX = 120
    let rep = render(view)
    // The tail is drawn outside the box, so the extreme row must have ink in
    // it on the side the tail is on and none on the other.
    let row = side == .bottom ? rep.pixelsHigh - 1 : 0
    var inked = false
    for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: row)?.alphaComponent ?? 0) > 0.1 {
        inked = true; break
    }
    check("tail \(name) puts ink on that edge", inked)
}

// A contact sheet to look at, since "does it read" is not a thing to assert.
let shots = NSImage(size: NSSize(width: 620, height: 440))
shots.lockFocus()
NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.21, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 620, height: 440).fill()
var y: CGFloat = 420
for text in samples {
    let size = BubbleView.size(for: text)
    let v = BubbleView(frame: NSRect(origin: .zero, size: size))
    v.text = text
    v.tail = .bottom
    v.tailX = size.width / 2
    y -= size.height + 12
    // sourceOver, not the default: a bitmap rep drawn plainly copies its
    // transparency straight over the page and punches a hole in it.
    let img = NSImage(size: size)
    img.addRepresentation(render(v))
    img.draw(in: NSRect(x: 20, y: y, width: size.width, height: size.height),
             from: .zero, operation: .sourceOver, fraction: 1)
}
shots.unlockFocus()
if let tiff = shots.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "shots/bubbles.png"))
    print("\nwrote shots/bubbles.png")
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
