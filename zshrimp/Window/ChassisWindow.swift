import AppKit

/// A borderless panel shaped by its chassis. The system shadow follows the drawn silhouette.
final class ChassisWindow: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        minSize = NSSize(width: 360, height: 240)
        contentView = ChassisView(content: content)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The window's body: a rail on the left and the workspace set into the rest.
final class ChassisView: NSView {
    /// Heavier on the rail side, tighter on the right, so the silhouette leans.
    static let leadingRadius: CGFloat = 30
    static let trailingRadius: CGFloat = 26
    static let railWidth: CGFloat = 44
    static let inset: CGFloat = 12

    private let content: NSView
    private let spine = SpineView()
    private let body = CAGradientLayer()
    private let highlight = CAShapeLayer()
    private let silhouette = CAShapeLayer()
    private let highlightFade = CAGradientLayer()

    init(content: NSView) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        layer?.mask = silhouette
        body.startPoint = CGPoint(x: 0, y: 0.5)
        body.endPoint = CGPoint(x: 1, y: 0.5)
        highlight.fillColor = nil
        highlight.lineWidth = 1
        // Light falls from the top-left: the edge glints along the top and the rail side only.
        highlightFade.colors = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0).cgColor]
        highlightFade.startPoint = CGPoint(x: 0, y: 0)
        highlightFade.endPoint = CGPoint(x: 0.6, y: 0.8)
        highlight.mask = highlightFade
        [body, highlight].forEach { layer?.addSublayer($0) }
        highlight.zPosition = 10
        addSubview(spine)
        addSubview(content)

        apply(Settings.shared.values)
        Task { [weak self] in
            for await values in Observations({ Settings.shared.values }) {
                guard let self else { break }
                self.apply(values)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    private func apply(_ values: Settings.Values) {
        let palette = ElevationPalette(values)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The rail catches more light than the far side of the body.
        body.colors = [palette.chassisLit.cgColor, palette.chassis.cgColor]
        highlight.strokeColor = palette.edge.cgColor
        CATransaction.commit()
        spine.apply(palette)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = Self.outline(in: bounds)
        silhouette.frame = bounds
        silhouette.path = path
        body.frame = bounds
        body.locations = [0, NSNumber(value: Double(Self.railWidth * 1.6 / max(bounds.width, 1)))]
        highlight.frame = bounds
        highlight.path = Self.outline(in: bounds.insetBy(dx: 0.5, dy: 0.5))
        highlightFade.frame = bounds
        CATransaction.commit()

        spine.frame = NSRect(x: 0, y: 0, width: Self.railWidth, height: bounds.height)
        content.frame = NSRect(
            x: Self.railWidth,
            y: Self.inset,
            width: bounds.width - Self.railWidth - Self.inset,
            height: bounds.height - Self.inset * 2
        )
        window?.invalidateShadow()
    }

    private static func outline(in rect: NSRect) -> CGPath {
        let l = min(leadingRadius, rect.height / 2), t = min(trailingRadius, rect.height / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + t), radius: t)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - t, y: rect.maxY), radius: t)
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - l), radius: l)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + l, y: rect.minY), radius: l)
        path.closeSubpath()
        return path
    }
}
