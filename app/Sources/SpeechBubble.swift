import AppKit

/// A rounded speech balloon with a tail, drawn in its own transparent window
/// so it can hang outside the bird's window bounds.
final class BubbleView: NSView {
    enum TailSide { case bottom, top }

    var text: String = "" { didSet { needsDisplay = true } }

    /// Two looks, because there are two kinds of character here. The Agent
    /// characters are 3D renders and get a soft balloon; a 16-bit sprite with
    /// a soft balloon over its head looks like a modern app stuck to it, so
    /// those get square corners, a hard border and a hard shadow.
    var pixel = false { didSet { needsDisplay = true } }
    /// Arabic reads right to left. CoreText shapes and joins the glyphs on its
    /// own, but the paragraph's base direction has to be set explicitly or
    /// punctuation and any embedded Latin land on the wrong end of the line.
    var rightToLeft = false { didSet { needsDisplay = true } }
    var tail: TailSide = .bottom { didSet { needsDisplay = true } }
    /// Horizontal position of the tail, in view coordinates.
    var tailX: CGFloat = 0 { didSet { needsDisplay = true } }

    static let inset = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    static let tailHeight: CGFloat = 12
    static let tailWidth: CGFloat = 18
    static let maxTextWidth: CGFloat = 240

    override var isOpaque: Bool { false }

    static func attributed(_ s: String, rightToLeft: Bool = false) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        para.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        // Arabic sits smaller than Latin at the same point size, so give it a
        // little more room to stay comfortably readable in a small balloon.
        let size: CGFloat = rightToLeft ? 15 : 13
        return NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: para,
        ])
    }

    /// Total window size needed for a line of text.
    static func size(for text: String, rightToLeft: Bool = false) -> NSSize {
        let a = attributed(text, rightToLeft: rightToLeft)
        let bounds = a.boundingRect(with: NSSize(width: maxTextWidth, height: 400),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading])
        return NSSize(width: ceil(bounds.width) + inset.left + inset.right,
                      height: ceil(bounds.height) + inset.top + inset.bottom + tailHeight)
    }

    private var balloonRect: NSRect {
        var r = bounds
        r.size.height -= Self.tailHeight
        if tail == .bottom { r.origin.y = Self.tailHeight }
        return r
    }

    /// One continuous outline: the rounded rect with the tail spliced into
    /// the relevant edge, so stroking never leaves a seam at the junction.
    private func balloonPath() -> NSBezierPath {
        let r = balloonRect
        let radius: CGFloat = pixel ? 0 : 11
        let tw = Self.tailWidth, th = Self.tailHeight
        let tx = min(max(tailX, r.minX + radius + tw), r.maxX - radius - tw)

        let path = NSBezierPath()
        path.move(to: NSPoint(x: r.minX + radius, y: r.minY))
        if tail == .bottom {
            path.line(to: NSPoint(x: tx - tw / 2, y: r.minY))
            path.line(to: NSPoint(x: tx + 2, y: r.minY - th))
            path.line(to: NSPoint(x: tx + tw / 2, y: r.minY))
        }
        path.line(to: NSPoint(x: r.maxX - radius, y: r.minY))
        path.appendArc(withCenter: NSPoint(x: r.maxX - radius, y: r.minY + radius),
                       radius: radius, startAngle: 270, endAngle: 360)
        path.line(to: NSPoint(x: r.maxX, y: r.maxY - radius))
        path.appendArc(withCenter: NSPoint(x: r.maxX - radius, y: r.maxY - radius),
                       radius: radius, startAngle: 0, endAngle: 90)
        if tail == .top {
            path.line(to: NSPoint(x: tx + tw / 2, y: r.maxY))
            path.line(to: NSPoint(x: tx + 2, y: r.maxY + th))
            path.line(to: NSPoint(x: tx - tw / 2, y: r.maxY))
        }
        path.line(to: NSPoint(x: r.minX + radius, y: r.maxY))
        path.appendArc(withCenter: NSPoint(x: r.minX + radius, y: r.maxY - radius),
                       radius: radius, startAngle: 90, endAngle: 180)
        path.line(to: NSPoint(x: r.minX, y: r.minY + radius))
        path.appendArc(withCenter: NSPoint(x: r.minX + radius, y: r.minY + radius),
                       radius: radius, startAngle: 180, endAngle: 270)
        path.close()
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = balloonPath()

        if pixel {
            // Hard shadow, no blur — the era didn't have one.
            NSColor(calibratedWhite: 0, alpha: 0.45).setFill()
            let shadowPath = balloonPath()
            var shift = AffineTransform.identity
            shift.translate(x: 4, y: -4)
            shadowPath.transform(using: shift)
            shadowPath.fill()
        } else {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.set()
            NSColor(calibratedRed: 1, green: 0.99, blue: 0.94, alpha: 1).setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        if pixel {
            NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.93, alpha: 1).setFill()
            path.fill()
        }
        NSColor(calibratedWhite: pixel ? 0.08 : 0.25, alpha: pixel ? 1 : 0.85).setStroke()
        path.lineWidth = pixel ? 2.5 : 1.5
        path.stroke()

        var textRect = balloonRect.insetBy(dx: 0, dy: 0)
        textRect.origin.x += Self.inset.left
        textRect.origin.y += Self.inset.bottom
        textRect.size.width -= Self.inset.left + Self.inset.right
        textRect.size.height -= Self.inset.top + Self.inset.bottom
        Self.attributed(text, rightToLeft: rightToLeft).draw(
            with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
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
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = bubble
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Show `text` pointing at `anchor` — a screen point at the character's head.
    func present(_ text: String, rightToLeft: Bool = false, pixel: Bool = false,
                 pointingAt anchor: NSPoint, on screen: NSScreen) {
        let size = BubbleView.size(for: text, rightToLeft: rightToLeft)
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
        bubble.rightToLeft = rightToLeft
        bubble.pixel = pixel
        bubble.tail = side
        setFrame(NSRect(origin: origin, size: size), display: true)
        bubble.tailX = anchor.x - origin.x
        bubble.needsDisplay = true

        orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            if self?.alphaValue == 0 { self?.orderOut(nil) }
        }
    }
}
