import AppKit
_ = NSApplication.shared
let who = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "peedy"
guard let store = SpriteStore(character: who, bundle: Bundle(path: ProcessInfo.processInfo.environment["BUDDY_APP"] ?? "build/Desktop Buddies.app")!) else { exit(1) }
// Each character names its own menu-bar frame in its catalogue.
let hero = store.heroFrame

// The shipped menu-bar glyph, at real size and blown up, on light and dark bars.
let HEIGHT: CGFloat = 18
guard let icon = store.menuBarIcon(frame: hero, height: HEIGHT),
      let big = store.menuBarIcon(frame: hero, height: 120) else {
    print("icon failed"); exit(1)
}
print(String(format: "menu-bar icon: %.0f x %.0f pt", icon.size.width, icon.size.height))

let out = NSImage(size: NSSize(width: 460, height: 190))
out.lockFocus()
NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 460, height: 190).fill()

for (i, bar) in [NSColor(calibratedWhite: 0.96, alpha: 1),
                 NSColor(calibratedWhite: 0.12, alpha: 1)].enumerated() {
    let y: CGFloat = 150 - CGFloat(i) * 44
    bar.setFill()
    NSRect(x: 16, y: y, width: 180, height: 26).fill()
    icon.draw(in: NSRect(x: 24, y: y + (26 - HEIGHT) / 2,
                         width: icon.size.width, height: HEIGHT))
    // Neighbours, for a sense of scale on a real bar.
    NSColor(calibratedWhite: i == 0 ? 0.25 : 0.8, alpha: 1).setFill()
    for n in 0..<3 {
        NSRect(x: 24 + icon.size.width + 14 + CGFloat(n) * 22, y: y + 8, width: 12, height: 11).fill()
    }
}
big.draw(in: NSRect(x: 250, y: 30, width: big.size.width, height: 120))
out.unlockFocus()

if let t = out.tiffRepresentation, let r = NSBitmapImageRep(data: t),
   let p = r.representation(using: .png, properties: [:]) {
    try? p.write(to: URL(fileURLWithPath: "shots/\(who)_menubar_icon.png"))
    print("wrote shots/menubar_icon.png")
}
