import AppKit

/// The rail down the window's left side: window controls, a name set vertically, and, on the main window, layout glyphs.
/// Dragging the rail moves the window; double-clicking it zooms.
final class SpineView: NSView {
    private let name: String
    private let lights: [WindowMark]
    private let glyphs: [GlyphButton]
    private var ink = NSColor.secondaryLabelColor
    private var isHoveringLights = false

    /// The main window's rail carries every control; an auxiliary window's rail only closes it.
    init(name: String, isMain: Bool) {
        self.name = name
        lights = isMain ? [WindowMark(.close), WindowMark(.minimize), WindowMark(.zoom)] : [WindowMark(.close)]
        glyphs = isMain ? [
            GlyphButton(.splitRight, action: #selector(PaneContainerView.splitRight(_:)), help: "Split right"),
            GlyphButton(.splitDown, action: #selector(PaneContainerView.splitDown(_:)), help: "Split down"),
            GlyphButton(.float, action: #selector(MainWindowController.toggleFloating(_:)), help: "Float on top"),
        ] : []
        super.init(frame: .zero)
        (lights as [NSView] + glyphs).forEach(addSubview)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        guard isMain else { return }
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
        (lights as [RailControl] + glyphs).forEach { $0.ink = palette.ink; $0.platform = palette.chassisLit }
        needsDisplay = true
    }

    private static let lightSize: CGFloat = 27
    private static let lightGap: CGFloat = 1
    private static let glyphSize = NSSize(width: 27, height: 27)
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
                y: bounds.height - Self.edge - Self.glyphSize.height * CGFloat(index + 1) - 1 * CGFloat(index),
                width: Self.glyphSize.width,
                height: Self.glyphSize.height
            )
        }
    }

    // The name reads bottom to top, centered between the controls above and the glyphs below.
    override func draw(_ dirtyRect: NSRect) {
        let name = NSAttributedString(string: self.name, attributes: [.font: Typography.railName, .foregroundColor: ink, .kern: Typography.railNameKern])
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
