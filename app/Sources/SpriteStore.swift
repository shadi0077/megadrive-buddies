import AppKit

/// One drawable step of an animation: a frame of the sheet.
struct Step {
    let frame: Int
}

struct AnimationDef {
    let name: String
    let steps: [Step]
    let fps: Double
    let loop: Bool

    var duration: TimeInterval { Double(steps.count) / fps }
}

/// Loads the trimmed frame atlas and hands out decoded images on demand.
///
/// Frames were trimmed to their opaque bounds at build time, so each one
/// carries the offset it must be drawn at to stay registered with the others.
final class SpriteStore {
    struct Trim { let x: Int; let y: Int; let w: Int; let h: Int }

    let canvas: NSSize
    private let trims: [Trim?]
    private let framesURL: URL
    private let cache = NSCache<NSNumber, NSImage>()

    private(set) var animations: [String: AnimationDef] = [:]

    let character: String

    init?(character: String, bundle: Bundle = .main) {
        self.character = character
        let dir = "characters/\(character)"
        guard let framesJSON = bundle.url(forResource: "frames", withExtension: "json",
                                          subdirectory: dir),
              let animJSON = bundle.url(forResource: "animations", withExtension: "json",
                                        subdirectory: dir),
              let framesDir = bundle.url(forResource: "frames", withExtension: nil,
                                         subdirectory: dir),
              let fData = try? Data(contentsOf: framesJSON),
              let aData = try? Data(contentsOf: animJSON),
              let fRoot = try? JSONSerialization.jsonObject(with: fData) as? [String: Any],
              let aRoot = try? JSONSerialization.jsonObject(with: aData) as? [String: Any],
              let cv = fRoot["canvas"] as? [String: Any],
              let cw = cv["w"] as? Int, let ch = cv["h"] as? Int,
              let list = fRoot["frames"] as? [Any]
        else { return nil }

        canvas = NSSize(width: cw, height: ch)
        framesURL = framesDir
        trims = list.map { entry in
            guard let d = entry as? [String: Any],
                  let x = d["x"] as? Int, let y = d["y"] as? Int,
                  let w = d["w"] as? Int, let h = d["h"] as? Int else { return nil }
            return Trim(x: x, y: y, w: w, h: h)
        }
        // The working set for any one animation is small; this is generous.
        cache.totalCostLimit = 24 * 1024 * 1024

        if let anims = aRoot["animations"] as? [String: Any] {
            for (name, raw) in anims {
                guard let d = raw as? [String: Any],
                      let rawSteps = d["steps"] as? [[String: Any]],
                      let fps = d["fps"] as? Double,
                      let loop = d["loop"] as? Bool else { continue }
                let steps = rawSteps.compactMap { s -> Step? in
                    (s["f"] as? Int).map { Step(frame: $0) }
                }
                guard !steps.isEmpty else { continue }
                animations[name] = AnimationDef(name: name, steps: steps, fps: fps, loop: loop)
            }
        }
    }

    func animation(_ name: String) -> AnimationDef? { animations[name] }

    /// Image for a frame, plus the rect it occupies in canvas space
    /// (top-left origin, matching how the frames were exported).
    func image(_ index: Int) -> (NSImage, NSRect)? {
        guard index >= 0, index < trims.count, let t = trims[index] else { return nil }
        let rect = NSRect(x: CGFloat(t.x), y: CGFloat(t.y),
                          width: CGFloat(t.w), height: CGFloat(t.h))
        if let hit = cache.object(forKey: NSNumber(value: index)) { return (hit, rect) }
        let url = framesURL.appendingPathComponent(String(format: "%04d.png", index))
        guard let img = NSImage(contentsOf: url) else { return nil }
        img.size = rect.size
        cache.setObject(img, forKey: NSNumber(value: index), cost: t.w * t.h * 4)
        return (img, rect)
    }

    /// A frame scaled to a menu-bar glyph, in full colour.
    ///
    /// A tiny green parrot is unmistakably him, which matters more than strict
    /// template convention here — on a busy menu bar (or inside something like
    /// Bartender's hidden-items list) a generic monochrome bird is very hard
    /// to pick out.
    func menuBarIcon(frame index: Int, height: CGFloat) -> NSImage? {
        guard let (img, rect) = image(index), rect.height > 0 else { return nil }
        let scale = height / rect.height
        let size = NSSize(width: max(1, (rect.width * scale).rounded()), height: height)
        let out = NSImage(size: size)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        img.draw(in: NSRect(origin: .zero, size: size), from: .zero,
                 operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }

    /// A monochrome template cut from a frame's alpha, for the menu bar.
    ///
    /// SF Symbols only learned "bird" in macOS 13, so on older systems the
    /// status item needs a glyph of its own — and a silhouette of the actual
    /// sprite is more on-brand than a generic symbol anyway.
    func silhouette(frame index: Int, height: CGFloat) -> NSImage? {
        guard let (img, rect) = image(index), rect.height > 0 else { return nil }
        let scale = height / rect.height
        let size = NSSize(width: max(1, (rect.width * scale).rounded()), height: height)
        let out = NSImage(size: size)
        out.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        // Keep the black only where the sprite has alpha.
        img.draw(in: NSRect(origin: .zero, size: size), from: .zero,
                 operation: .destinationIn, fraction: 1)
        out.unlockFocus()
        out.isTemplate = true
        return out
    }

    /// Pull a handful of frames into the cache so an animation starts smoothly.
    func warm(_ names: [String]) {
        for name in names {
            guard let a = animations[name] else { continue }
            for s in a.steps.prefix(6) { _ = image(s.frame) }
        }
    }
}
