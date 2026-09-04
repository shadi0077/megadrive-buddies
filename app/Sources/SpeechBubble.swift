import AppKit

/// A speech box with a tail, drawn in its own transparent window so it can
/// hang outside the character's window bounds.
///
/// Square corners, a hard border and a hard shadow: these are Mega Drive
/// characters, and a soft rounded balloon on top of a 16-bit sprite looks like
/// a sprite with a modern app stuck to its head. The tail is stepped rather
/// than smooth for the same reason.
final class BubbleView: NSView {
    enum TailSide { case bottom, top }

    var text: String = "" { didSet { needsDisplay = true } }
    var tail: TailSide = .bottom { didSet { needsDisplay = true } }
    /// Horizontal position of the tail, in view coordinates.
    var tailX: CGFloat = 0 { didSet { needsDisplay = true } }

    static let inset = NSEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
    static let tailHeight: CGFloat = 11
    static let tailWidth: CGFloat = 16
    static let border: CGFloat = 2.5
    static let shadow: CGFloat = 4
    static let maxTextWidth: CGFloat = 250

    override var isOpaque: Bool { false }

    static func attributed(_ s: String) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        para.lineSpacing = 1
        return NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: para,
        ])
    }

    /// Total window size needed for a line of text.
    static func size(for text: String) -> NSSize {
        let a = attributed(text)
        let bounds = a.boundingRect(with: NSSize(width: maxTextWidth, height: 400),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading])
        return NSSize(width: ceil(bounds.width) + inset.left + inset.right + shadow,
                      height: ceil(bounds.height) + inset.top + inset.bottom
                              + tailHeight + shadow)
    }

    private var boxRect: NSRect {
        var r = bounds
        r.size.height -= Self.tailHeight + Self.shadow
        r.size.width -= Self.shadow
        r.origin.x += Self.shadow
        if tail == .bottom { r.origin.y = Self.tailHeight + Self.shadow }
        else { r.origin.y = Self.shadow }
        return r
    }

    /// One continuous outline: the box with the tail spliced into the relevant
    /// edge, so stroking never leaves a seam at the junction.
    private func boxPath(offsetBy dx: CGFloat = 0, _ dy: CGFloat = 0) -> NSBezierPath {
        let r = boxRect.offsetBy(dx: dx, dy: dy)
        let tw = Self.tailWidth, th = Self.tailHeight
        let tx = min(max(tailX + dx, r.minX + tw), r.maxX - tw)

        let path = NSBezierPath()
        path.move(to: NSPoint(x: r.minX, y: r.minY))
        if tail == .bottom {
            path.line(to: NSPoint(x: tx - tw / 2, y: r.minY))
            path.line(to: NSPoint(x: tx - tw / 6, y: r.minY - th))
            path.line(to: NSPoint(x: tx + tw / 2, y: r.minY))
        }
        path.line(to: NSPoint(x: r.maxX, y: r.minY))
        path.line(to: NSPoint(x: r.maxX, y: r.maxY))
        if tail == .top {
            path.line(to: NSPoint(x: tx + tw / 2, y: r.maxY))
            path.line(to: NSPoint(x: tx - tw / 6, y: r.maxY + th))
            path.line(to: NSPoint(x: tx - tw / 2, y: r.maxY))
        }
        path.line(to: NSPoint(x: r.minX, y: r.maxY))
        path.close()
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        // Hard shadow, no blur — the era didn't have one.
        NSColor(calibratedWhite: 0, alpha: 0.45).setFill()
        boxPath(offsetBy: Self.shadow, -Self.shadow).fill()

        let path = boxPath()
        NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.93, alpha: 1).setFill()
        path.fill()
        NSColor(calibratedWhite: 0.08, alpha: 1).setStroke()
        path.lineWidth = Self.border
        path.stroke()

        var textRect = boxRect
        textRect.origin.x += Self.inset.left
        textRect.origin.y += Self.inset.bottom
        textRect.size.width -= Self.inset.left + Self.inset.right
        textRect.size.height -= Self.inset.top + Self.inset.bottom
        Self.attributed(text).draw(with: textRect,
                                   options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    // Clicks belong to whatever is underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class SpeechBubbleWindow: NSPanel {
    private let bubble = BubbleView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: 40),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary,
                              .ignoresCycle]
        contentView = bubble
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Show `text` pointing at `anchor` — a screen point just above the
    /// character's head.
    func present(_ text: String, pointingAt anchor: NSPoint, on screen: NSScreen) {
        let size = BubbleView.size(for: text)
        let vf = screen.visibleFrame

        var origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y)
        var side = BubbleView.TailSide.bottom
        if origin.y + size.height > vf.maxY {          // no room above: flip below
            origin.y = anchor.y - size.height
            side = .top
        }
        origin.x = min(max(origin.x, vf.minX + 6), vf.maxX - size.width - 6)
        origin.y = min(max(origin.y, vf.minY + 6), vf.maxY - size.height - 6)

        bubble.text = text
        bubble.tail = side
        setFrame(NSRect(origin: origin, size: size), display: true)
        bubble.tailX = anchor.x - origin.x
        bubble.needsDisplay = true

        orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            if self?.alphaValue == 0 { self?.orderOut(nil) }
        }
    }
}
