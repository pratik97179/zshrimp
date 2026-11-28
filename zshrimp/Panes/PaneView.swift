import AppKit
import QuartzCore

/// A pane's surface: the padding ring around its terminal, the light on its rim and the veil over it at rest. Only layer opacity animates; the terminal view is never touched.
final class PaneView: NSView {
    let content: NSView
    private let fill = CAShapeLayer()
    private let veil = CAShapeLayer()
    // A grey fill in saturation blend mode drains the color from whatever is beneath it.
    private let desaturation = CAShapeLayer()
    // Light falling from above: bright along the top edge, fading out down the sides.
    private let rim = CAGradientLayer()
    private let rimStroke = CAShapeLayer()
    private var padding: CGFloat = 0
    private var isFocused = false
    private var isHovered = false
    private var look = PaneLook.rest

    init(content: NSView) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(content)

        fill.fillRule = .evenOdd
        fill.zPosition = -1
        desaturation.zPosition = 1
        desaturation.fillColor = NSColor.gray.cgColor
        desaturation.compositingFilter = "saturationBlendMode"
        veil.zPosition = 1.5
        rim.zPosition = 2
        rimStroke.fillColor = nil
        rimStroke.strokeColor = NSColor.black.cgColor
        rim.mask = rimStroke
        rim.startPoint = CGPoint(x: 0.5, y: 0)
        rim.endPoint = CGPoint(x: 0.5, y: 1)
        rim.locations = [0, 0.5, 1]
        [fill, desaturation, veil, rim].forEach { layer?.addSublayer($0) }

        rim.opacity = look.rim
        veil.opacity = look.veil
        desaturation.opacity = look.desaturation

        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    func apply(_ values: Settings.Values, _ palette: ElevationPalette) {
        padding = values.padding
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.fillColor = values.backgroundColor.cgColor
        veil.fillColor = palette.veil.cgColor
        rim.colors = [palette.rim, palette.rim.withAlphaComponent(palette.rim.alphaComponent * 0.5), palette.rim.withAlphaComponent(palette.rim.alphaComponent * 0.2)].map(\.cgColor)
        CATransaction.commit()
        needsLayout = true
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        updateLook()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateLook()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateLook()
    }

    private func updateLook() {
        let new: PaneLook = isFocused ? .lit : isHovered ? .near : .rest
        guard new != look else { return }
        let pace: Elevation.Pace = new.rim > look.rim ? .answer : look == .lit ? .settle : .release
        look = new
        animate(rim, to: new.rim, pace)
        animate(veil, to: new.veil, pace)
        animate(desaturation, to: new.desaturation, pace)
    }

    private func animate(_ layer: CALayer, to value: Float, _ pace: Elevation.Pace) {
        // Starting from what is on screen lets a reversal mid-flight continue smoothly.
        let from = layer.presentation()?.opacity ?? layer.opacity
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = value
        CATransaction.commit()
        layer.add(Elevation.animation(keyPath: "opacity", from: from, to: value, pace: pace), forKey: "look")
    }

    // Keeps the terminal's corners inside the rounded surface, so nothing has to clip the terminal.
    private var cornerRadius: CGFloat {
        min(Elevation.cornerRadius, padding / (1 - 1 / 2.squareRoot()))
    }

    override func layout() {
        super.layout()
        content.frame = bounds.insetBy(dx: padding, dy: padding)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = cornerRadius
        let outline = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let ring = CGMutablePath()
        ring.addPath(outline)
        ring.addRect(content.frame)
        fill.frame = bounds
        fill.path = ring
        for layer in [veil, desaturation] {
            layer.frame = bounds
            layer.path = outline
        }

        let line: CGFloat = 1
        let inset = bounds.insetBy(dx: line / 2, dy: line / 2)
        rim.frame = bounds
        rimStroke.frame = bounds
        rimStroke.lineWidth = line
        rimStroke.path = CGPath(roundedRect: inset, cornerWidth: max(0, radius - line / 2), cornerHeight: max(0, radius - line / 2), transform: nil)

        CATransaction.commit()
    }
}
