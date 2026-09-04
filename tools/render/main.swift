import AppKit

// Headless harness: renders every animation through the real BuddyView, so the
// trim offsets, the bottom-centre anchoring and mirroring are all exercised
// without needing screen-recording permission.
_ = NSApplication.shared

let bundlePath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/MegaDrive Buddies.app"
let who = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "axel"
guard let bundle = Bundle(path: bundlePath),
      let store = SpriteStore(character: who, bundle: bundle) else {
    FileHandle.standardError.write("cannot load store from \(bundlePath)\n".data(using: .utf8)!)
    exit(1)
}

let scale: CGFloat = 2
let cell = NSSize(width: store.canvas.width * scale, height: store.canvas.height * scale)

func render(_ step: Step, mirrored: Bool) -> NSImage {
    let view = BuddyView(store: store)
    view.frame = NSRect(origin: .zero, size: cell)
    view.step = step
    view.mirrored = mirrored
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    let img = NSImage(size: cell)
    img.addRepresentation(rep)
    return img
}

func sheet(_ title: String, _ steps: [Step], mirrored: Bool = false, cols: Int = 8) -> NSImage {
    let rows = (steps.count + cols - 1) / cols
    let pad: CGFloat = 4
    let head: CGFloat = 22
    let size = NSSize(width: CGFloat(cols) * (cell.width + pad) + pad,
                      height: CGFloat(rows) * (cell.height + pad) + pad + head)
    let out = NSImage(size: size)
    out.lockFocus()
    NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.21, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    (title as NSString).draw(at: NSPoint(x: 6, y: size.height - head + 4), withAttributes: [
        .font: NSFont.boldSystemFont(ofSize: 13),
        .foregroundColor: NSColor(calibratedRed: 1, green: 0.86, blue: 0.47, alpha: 1),
    ])
    for (i, step) in steps.enumerated() {
        let c = i % cols, r = i / cols
        let origin = NSPoint(x: pad + CGFloat(c) * (cell.width + pad),
                             y: size.height - head - pad - CGFloat(r + 1) * (cell.height + pad))
        NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.32, alpha: 1).setFill()
        NSRect(origin: origin, size: cell).fill()
        render(step, mirrored: mirrored).draw(in: NSRect(origin: origin, size: cell))
    }
    out.unlockFocus()
    return out
}

func write(_ img: NSImage, _ path: String) {
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

try? FileManager.default.createDirectory(atPath: "shots", withIntermediateDirectories: true)

// One sheet per requested animation, sampled evenly.
// Whatever this character actually has.
let wanted = store.animations.keys.sorted()
for name in wanted {
    guard let def = store.animation(name) else { print("missing \(name)"); continue }
    let n = min(16, def.steps.count)
    let picked = (0..<n).map { def.steps[$0 * (def.steps.count - 1) / max(n - 1, 1)] }
    write(sheet("\(name)  (\(def.steps.count) steps @ \(Int(def.fps))fps)", picked),
          "shots/\(who)_anim_\(name).png")
}

// Mirroring: everybody faces the viewer's left unmirrored, so the walk
// mirrored is the one to look at.
if let walk = store.animation(store.animations["walk"] != nil ? "walk" : "rest") {
    write(sheet("walk mirrored (walking right)", Array(walk.steps.prefix(8)), mirrored: true),
          "shots/\(who)_anim_mirrored.png")
}

print("rendered")
