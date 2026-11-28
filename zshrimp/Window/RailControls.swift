import AppKit

/// A control on the rail: an outlined ink mark sitting on a round, softly raised platform.
/// Light falls from the top-left, so the platform glints there and casts a soft shade to the bottom-right; pressing sinks it flat.
class RailControl: NSView {
    var ink = NSColor.labelColor { didSet { needsDisplay = true } }
    var platform = NSColor.windowBackgroundColor { didSet { needsDisplay = true } }
    /// Set by the rail while the pointer is near the group, so its members brighten together.
    var isNear = false { didSet { needsDisplay = true } }
    var isOn = false { didSet { ease() } }
    private var isHovered = false { didSet { ease() } }
    private var isPressed = false { didSet { needsDisplay = true } }
    private(set) var hover: CGFloat = 0
    private(set) var on: CGFloat = 0
    private var timer: Timer?

    /// The platform's diameter; the view leaves room around it for the shadows.
    static let diameter: CGFloat = 19

    init(label: String) {
        super.init(frame: .zero)
        toolTip = label
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) { isPressed = true }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { perform() }
    }

    override func accessibilityPerformPress() -> Bool {
        perform()
        return true
    }

    func perform() {}

    // MARK: Drawing

    /// Draws the mark in `markInk` on the 24-unit grid of the platform.
    func drawMark() {}

    var markInk: NSColor { ink }

    override func draw(_ dirtyRect: NSRect) {
        let d = Self.diameter
        let disc = NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
        let isLight = (platform.usingColorSpace(.sRGB)?.brightnessComponent ?? 0) > 0.6
        let path = NSBezierPath(ovalIn: disc)
        let lift: CGFloat = isPressed ? 0.2 : 1

        // Shadow offsets ignore the flipped view: positive height points up.
        NSGraphicsContext.saveGraphicsState()
        let glint = NSShadow()
        glint.shadowColor = NSColor.white.withAlphaComponent((isLight ? 0.8 : 0.07) * lift)
        glint.shadowOffset = NSSize(width: -1.5, height: 1.5)
        glint.shadowBlurRadius = 3
        glint.set()
        platform.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        let shade = NSShadow()
        shade.shadowColor = NSColor.black.withAlphaComponent((isLight ? 0.16 : 0.5) * lift)
        shade.shadowOffset = NSSize(width: 1.5, height: -2)
        shade.shadowBlurRadius = 4
        shade.set()
        platform.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        // A faint top-left sheen on the face; pressed, the face dips a shade darker instead.
        let face = isPressed
            ? NSGradient(colors: [platform.blended(withFraction: 0.08, of: .black) ?? platform, platform])
            : NSGradient(colors: [platform.blended(withFraction: isLight ? 0.5 : 0.05, of: .white) ?? platform, platform])
        face?.draw(in: path, angle: -45)

        let level = 0.55 + 0.45 * max(hover, isNear ? 0.6 : 0, on)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(level)
        NSGraphicsContext.current?.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
        markInk.set()
        drawMark()
        NSGraphicsContext.current?.cgContext.endTransparencyLayer()
        NSGraphicsContext.restoreGraphicsState()
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        let u = Self.diameter / 24
        return NSPoint(x: bounds.midX + (x - 12) * u, y: bounds.midY + (y - 12) * u)
    }

    func stroke(_ build: (NSBezierPath) -> Void) {
        let path = NSBezierPath()
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        build(path)
        path.stroke()
    }

    func frame(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSBezierPath {
        let a = point(x0, y0), b = point(x1, y1)
        let path = NSBezierPath(roundedRect: NSRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y), xRadius: 2, yRadius: 2)
        path.lineWidth = 1.7
        path.lineJoinStyle = .round
        return path
    }

    // MARK: Easing

    private static let duration: TimeInterval = 0.18

    private func ease() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            hover = isHovered ? 1 : 0
            on = isOn ? 1 : 0
            needsDisplay = true
            return
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func step() {
        let delta = CGFloat(1.0 / 60 / Self.duration)
        hover = approach(hover, isHovered ? 1 : 0, delta)
        on = approach(on, isOn ? 1 : 0, delta)
        needsDisplay = true
        if hover == (isHovered ? 1 : 0), on == (isOn ? 1 : 0) {
            timer?.invalidate()
            timer = nil
        }
    }

    private func approach(_ value: CGFloat, _ target: CGFloat, _ delta: CGFloat) -> CGFloat {
        value < target ? min(value + delta, target) : max(value - delta, target)
    }
}

/// Close, minimize and resize: a rounded cross, a bar, and a two-headed diagonal arrow.
final class WindowMark: RailControl {
    enum Kind { case close, minimize, zoom }
    let kind: Kind
    private static let seal = NSColor(srgbRed: 0.84, green: 0.33, blue: 0.24, alpha: 1)

    init(_ kind: Kind) {
        self.kind = kind
        let label = switch kind {
        case .close: "Close"
        case .minimize: "Minimize"
        case .zoom: "Resize"
        }
        super.init(label: label)
    }

    override var markInk: NSColor {
        kind == .close ? ink.blended(withFraction: hover, of: Self.seal) ?? ink : ink
    }

    override func drawMark() {
        switch kind {
        case .close:
            stroke {
                $0.move(to: point(8.5, 8.5)); $0.line(to: point(15.5, 15.5))
                $0.move(to: point(15.5, 8.5)); $0.line(to: point(8.5, 15.5))
            }
        case .minimize:
            stroke { $0.move(to: point(7.5, 12)); $0.line(to: point(16.5, 12)) }
        case .zoom:
            stroke {
                $0.move(to: point(8, 16)); $0.line(to: point(16, 8))
                $0.move(to: point(11.5, 8)); $0.line(to: point(16, 8)); $0.line(to: point(16, 12.5))
                $0.move(to: point(8, 11.5)); $0.line(to: point(8, 16)); $0.line(to: point(12.5, 16))
            }
        }
    }

    override func perform() {
        switch kind {
        case .close: window?.performClose(nil)
        case .minimize: window?.performMiniaturize(nil)
        case .zoom: window?.zoom(nil)
        }
    }
}

/// A layout control drawn as an outlined window. Sends its action up the responder chain, so it reaches the focused pane.
final class GlyphButton: RailControl {
    enum Shape { case splitRight, splitDown, float }
    let shape: Shape
    let action: Selector

    init(_ shape: Shape, action: Selector, help: String) {
        self.shape = shape
        self.action = action
        super.init(label: help)
    }

    override func drawMark() {
        switch shape {
        case .splitRight:
            frame(6.5, 7.5, 17.5, 16.5).stroke()
            stroke { $0.move(to: point(12, 7.5)); $0.line(to: point(12, 16.5)) }
        case .splitDown:
            frame(6.5, 7.5, 17.5, 16.5).stroke()
            stroke { $0.move(to: point(6.5, 12)); $0.line(to: point(17.5, 12)) }
        case .float:
            // A window lifted off another; it rises further while floating.
            frame(6, 10.5, 14.5, 17).stroke()
            let lift = 1.5 * max(hover * 0.5, on)
            let front = frame(9.5, 7 - lift, 18, 13.5 - lift)
            platform.setFill()
            front.fill()
            front.stroke()
        }
    }

    override func perform() {
        NSApp.sendAction(action, to: nil, from: self)
    }
}
