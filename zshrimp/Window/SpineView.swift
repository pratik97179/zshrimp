import AppKit

/// The rail down the window's left side: window controls, the app's name set vertically, and layout glyphs.
/// Dragging the rail moves the window; double-clicking it zooms.
final class SpineView: NSView {
    private let lights = [WindowMark(.close), WindowMark(.minimize), WindowMark(.zoom)]
    private let glyphs = [
        GlyphButton(.splitRight, action: #selector(PaneContainerView.splitRight(_:)), help: "Split right"),
        GlyphButton(.splitDown, action: #selector(PaneContainerView.splitDown(_:)), help: "Split down"),
        GlyphButton(.float, action: #selector(MainWindowController.toggleFloating(_:)), help: "Float on top"),
    ]
    private var ink = NSColor.secondaryLabelColor
    private var isHoveringLights = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        (lights as [NSView] + glyphs).forEach(addSubview)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        Task { [weak self] in
            for await floating in Observations({ Settings.shared.values.isFloating }) {
                self?.glyphs.last?.isOn = floating
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    func apply(_ palette: ElevationPalette) {
        ink = palette.label
        glyphs.forEach { $0.ink = palette.label; $0.inkOn = palette.ink }
        lights.forEach { $0.rest = palette.label; $0.near = palette.ink }
        needsDisplay = true
    }

    private static let lightSize: CGFloat = 14
    private static let lightGap: CGFloat = 6
    private static let glyphSize = NSSize(width: 22, height: 20)
    private static let edge: CGFloat = 16

    override func layout() {
        super.layout()
        let x = (bounds.width - Self.lightSize) / 2
        for (index, light) in lights.enumerated() {
            light.frame = NSRect(x: x, y: Self.edge + CGFloat(index) * (Self.lightSize + Self.lightGap), width: Self.lightSize, height: Self.lightSize)
        }
        let glyphX = (bounds.width - Self.glyphSize.width) / 2
        for (index, glyph) in glyphs.reversed().enumerated() {
            glyph.frame = NSRect(
                x: glyphX,
                y: bounds.height - Self.edge - Self.glyphSize.height * CGFloat(index + 1) - 2 * CGFloat(index),
                width: Self.glyphSize.width,
                height: Self.glyphSize.height
            )
        }
    }

    // The name reads bottom to top, centered between the controls above and the glyphs below.
    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.systemFont(ofSize: 20, weight: .ultraLight)
        let name = NSAttributedString(string: "zshrimp", attributes: [.font: font, .foregroundColor: ink, .kern: 7])
        let size = name.size()
        let top = lights.last.map { $0.frame.maxY } ?? 0
        let bottom = glyphs.first.map { $0.frame.minY } ?? bounds.height
        guard bottom - top > size.width + 12 else { return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX - size.height / 2, yBy: (top + bottom) / 2 + size.width / 2)
        transform.rotate(byDegrees: -90)
        transform.concat()
        name.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseEntered(with event: NSEvent) { updateLightsHover(event) }
    override func mouseExited(with event: NSEvent) { setLightsHover(false) }
    override func mouseMoved(with event: NSEvent) { updateLightsHover(event) }

    private func updateLightsHover(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let group = lights.map(\.frame).reduce(NSRect.null) { $0.union($1) }.insetBy(dx: -10, dy: -10)
        setLightsHover(group.contains(point))
    }

    private func setLightsHover(_ hovering: Bool) {
        guard hovering != isHoveringLights else { return }
        isHoveringLights = hovering
        lights.forEach { $0.isNear = hovering }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        window?.acceptsMouseMovedEvents = true
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.zoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

/// A window control drawn as a single ink stroke: an open ensō closes, a horizon line minimizes, two corners zoom.
/// At rest the strokes are faint; near the pointer they darken, and the ensō takes a seal's vermilion when it is the one under the pointer.
final class WindowMark: NSView {
    enum Kind { case close, minimize, zoom }
    let kind: Kind
    var rest = NSColor.tertiaryLabelColor { didSet { needsDisplay = true } }
    var near = NSColor.labelColor { didSet { needsDisplay = true } }
    var isNear = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private static let seal = NSColor(srgbRed: 0.84, green: 0.33, blue: 0.24, alpha: 1)

    init(_ kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        setAccessibilityRole(.button)
        let label = switch kind {
        case .close: "Close"
        case .minimize: "Minimize"
        case .zoom: "Zoom"
        }
        setAccessibilityLabel(label)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isHovered && kind == .close ? Self.seal : isNear ? near : rest
        color.setStroke()
        let box = bounds.insetBy(dx: 2.5, dy: 2.5)
        let path = NSBezierPath()
        path.lineWidth = 1.3
        path.lineCapStyle = .round
        switch kind {
        case .close:
            // Open where the brush lifts, upper right, as an ensō is.
            path.appendArc(withCenter: NSPoint(x: box.midX, y: box.midY), radius: box.width / 2, startAngle: -50, endAngle: 250, clockwise: false)
        case .minimize:
            path.move(to: NSPoint(x: box.minX, y: box.midY))
            path.line(to: NSPoint(x: box.maxX, y: box.midY))
        case .zoom:
            let arm = box.width * 0.42
            path.move(to: NSPoint(x: box.minX, y: box.minY + arm))
            path.line(to: NSPoint(x: box.minX, y: box.minY))
            path.line(to: NSPoint(x: box.minX + arm, y: box.minY))
            path.move(to: NSPoint(x: box.maxX, y: box.maxY - arm))
            path.line(to: NSPoint(x: box.maxX, y: box.maxY))
            path.line(to: NSPoint(x: box.maxX - arm, y: box.maxY))
        }
        path.stroke()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { perform() }
    }

    override func accessibilityPerformPress() -> Bool {
        perform()
        return true
    }

    private func perform() {
        switch kind {
        case .close: window?.performClose(nil)
        case .minimize: window?.performMiniaturize(nil)
        case .zoom: window?.zoom(nil)
        }
    }
}

/// A layout control expressed as a line drawing of what it does. Sends its action up the responder chain, so it reaches the focused pane.
final class GlyphButton: NSView {
    enum Shape { case splitRight, splitDown, float }
    let shape: Shape
    let action: Selector
    var ink = NSColor.secondaryLabelColor { didSet { needsDisplay = true } }
    var inkOn = NSColor.labelColor { didSet { needsDisplay = true } }
    var isOn = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }

    init(_ shape: Shape, action: Selector, help: String) {
        self.shape = shape
        self.action = action
        super.init(frame: .zero)
        toolTip = help
        setAccessibilityRole(.button)
        setAccessibilityLabel(help)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        (isOn || isHovered ? inkOn : ink).setStroke()
        let box = NSRect(x: bounds.midX - 8, y: bounds.midY - 6, width: 16, height: 12)
        let frame = NSBezierPath(roundedRect: box.insetBy(dx: 0.6, dy: 0.6), xRadius: 2.5, yRadius: 2.5)
        frame.lineWidth = 1.2
        frame.stroke()
        let line = NSBezierPath()
        line.lineWidth = 1.2
        switch shape {
        case .splitRight:
            line.move(to: NSPoint(x: box.midX, y: box.minY))
            line.line(to: NSPoint(x: box.midX, y: box.maxY))
        case .splitDown:
            line.move(to: NSPoint(x: box.minX, y: box.midY))
            line.line(to: NSPoint(x: box.maxX, y: box.midY))
        case .float:
            // A smaller window lifted off the larger one.
            let raised = NSRect(x: box.minX + 6, y: box.minY - 3, width: 12, height: 9)
            NSColor.clear.setFill()
            let lifted = NSBezierPath(roundedRect: raised, xRadius: 2, yRadius: 2)
            lifted.lineWidth = 1.2
            lifted.stroke()
        }
        line.stroke()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        NSApp.sendAction(action, to: nil, from: self)
    }

    override func accessibilityPerformPress() -> Bool {
        NSApp.sendAction(action, to: nil, from: self)
    }
}
