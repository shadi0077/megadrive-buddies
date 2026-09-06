import AppKit
_ = NSApplication.shared

// Does the speech balloon lay out Arabic correctly — shaped, joined, and
// right-to-left — with the tail still under the right part of the text?
let samples = [
    ("Peedy, idle", "هل حان وقت البسكويت؟", true),
    ("Peedy, joke", "يقولون إن الكلام من فضة والسكوت من ذهب.", true),
    ("Bonzi, idle", "الجاذبية تقوم بمعظم العمل اليوم.", true),
    ("Bonzi, riddle", "ما هو الشيء الذي يمشي بلا أرجل ويبكي بلا عيون؟", true),
    ("English", "Is it cracker o'clock yet?", false),
]

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if ok { print("  ok   \(label)") } else { print("  FAIL \(label) \(detail)"); failures += 1 }
}

var y: CGFloat = 12
var shots: [(String, NSImage)] = []
for (label, text, rtl) in samples {
    let size = BubbleView.size(for: text, rightToLeft: rtl)
    let v = BubbleView(frame: NSRect(origin: .zero, size: size))
    v.text = text
    v.rightToLeft = rtl
    v.tail = .bottom
    v.tailX = size.width / 2
    v.appearance = NSAppearance(named: .aqua)
    let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
    v.cacheDisplay(in: v.bounds, to: rep)
    let img = NSImage(size: size)
    img.addRepresentation(rep)
    shots.append((label, img))
    print("  \(label): \(Int(size.width))x\(Int(size.height))")
    y += size.height
}

let W = shots.map { $0.1.size.width }.max()! + 140
let H = shots.reduce(0) { $0 + $1.1.size.height + 18 } + 16
let out = NSImage(size: NSSize(width: W, height: H))
out.lockFocus()
NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.22, alpha: 1).setFill()
NSRect(origin: .zero, size: out.size).fill()
var cursor = H - 8
for (label, img) in shots {
    cursor -= img.size.height + 18
    (label as NSString).draw(at: NSPoint(x: 8, y: cursor + img.size.height / 2 - 6),
        withAttributes: [.font: NSFont.systemFont(ofSize: 11),
                         .foregroundColor: NSColor(calibratedRed: 1, green: 0.85, blue: 0.5, alpha: 1)])
    img.draw(in: NSRect(x: 130, y: cursor, width: img.size.width, height: img.size.height))
}
out.unlockFocus()
if let t = out.tiffRepresentation, let r = NSBitmapImageRep(data: t),
   let p = r.representation(using: .png, properties: [:]) {
    try? p.write(to: URL(fileURLWithPath: "shots/arabic_bubbles.png"))
    print("wrote shots/arabic_bubbles.png")
}


// The direction flag has to actually change the layout, not just be stored.
let arabic = "هل حان وقت البسكويت؟"
let asRTL = BubbleView.size(for: arabic, rightToLeft: true)
let asLTR = BubbleView.size(for: arabic, rightToLeft: false)
check("Arabic gets a larger type size than Latin", asRTL.height >= asLTR.height,
      "\(asRTL.height) vs \(asLTR.height)")

func render(_ text: String, rtl: Bool, fixed: NSSize? = nil) -> NSBitmapImageRep {
    let size = fixed ?? BubbleView.size(for: text, rightToLeft: rtl)
    let v = BubbleView(frame: NSRect(origin: .zero, size: size))
    v.text = text; v.rightToLeft = rtl; v.tail = .bottom; v.tailX = size.width / 2
    v.appearance = NSAppearance(named: .aqua)
    let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
    v.cacheDisplay(in: v.bounds, to: rep)
    return rep
}
func ink(_ rep: NSBitmapImageRep) -> Int {
    var n = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 2)
        where (rep.colorAt(x: x, y: y)?.brightnessComponent ?? 1) < 0.4 { n += 1 }
    }
    return n
}
check("Arabic actually draws glyphs", ink(render(arabic, rtl: true)) > 40,
      "\(ink(render(arabic, rtl: true))) dark samples")

// A mixed line is where bidi goes wrong if the base direction isn't set: the
// Latin run and the trailing full stop end up on the wrong side. Centroids
// barely move on centred text, so compare the pixels themselves — identical
// renderings would mean the flag does nothing.
let mixed = "اسمي بيدي، and I am a parrot."
func samples(_ rep: NSBitmapImageRep) -> [Bool] {
    var out: [Bool] = []
    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            out.append((rep.colorAt(x: x, y: y)?.brightnessComponent ?? 1) < 0.4)
        }
    }
    return out
}
// Same frame for both, so the comparison is of layout and not of size.
let frame = BubbleView.size(for: mixed, rightToLeft: true)
let a = samples(render(mixed, rtl: true, fixed: frame))
let b = samples(render(mixed, rtl: false, fixed: frame))
let differing = zip(a, b).filter { $0 != $1 }.count
check("base direction changes how a mixed line lays out",
      a.count == b.count && differing > a.count / 100,
      "\(differing) of \(a.count) samples differ")

check("an empty bubble is still a sane size",
      BubbleView.size(for: "", rightToLeft: true).height > 20)

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
