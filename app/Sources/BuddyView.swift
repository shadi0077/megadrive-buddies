import AppKit

/// Draws one sprite frame, optionally mirrored so a character can face either
/// way without a second set of frames.
///
/// Frames were trimmed at build time and carry a canvas offset with a
/// top-left origin; this view flips that into AppKit's bottom-left space
/// rather than using `isFlipped`, which would also invert image content.
final class BuddyView: NSView {
    private let store: SpriteStore

    var step: Step? { didSet { if step != oldValue { needsDisplay = true } } }
    var mirrored = false { didSet { if mirrored != oldValue { needsDisplay = true } } }

    init(store: SpriteStore) {
        self.store = store
        super.init(frame: NSRect(origin: .zero, size: store.canvas))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { false }

    /// Where a frame lands inside this view, in view coordinates.
    private func destination(for index: Int) -> NSRect? {
        guard let (_, rect) = store.image(index) else { return nil }
        let sx = bounds.width / store.canvas.width
        let sy = bounds.height / store.canvas.height
        var box = NSRect(x: rect.minX * sx,
                         y: (store.canvas.height - rect.maxY) * sy,
                         width: rect.width * sx,
                         height: rect.height * sy)
        if mirrored { box.origin.x = bounds.width - box.maxX }
        return box
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let step, let ctx = NSGraphicsContext.current else { return }
        // Mega Drive sprites are pixel art: scaled any other way they turn to
        // mush, and at 1.55x mush is very visible.
        ctx.imageInterpolation = .none
        guard let (img, _) = store.image(step.frame),
              let dest = destination(for: step.frame) else { return }
        if mirrored {
            ctx.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: dest.maxX + dest.minX, yBy: 0)
            t.scaleX(by: -1, yBy: 1)
            t.concat()
            img.draw(in: dest, from: .zero, operation: .sourceOver, fraction: 1)
            ctx.restoreGraphicsState()
        } else {
            img.draw(in: dest, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    /// The window is mostly empty space; only take clicks on the bird itself.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let step, let dest = destination(for: step.frame) else { return nil }
        // `point` arrives in the superview's space; for a content view that is
        // the window's base space, which convert(_:from: nil) handles.
        return dest.contains(convert(point, from: superview)) ? self : nil
    }
}

extension Step: Equatable {
    static func == (a: Step, b: Step) -> Bool { a.frame == b.frame }
}
