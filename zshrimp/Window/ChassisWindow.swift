import AppKit

/// A borderless panel shaped by its chassis. The system shadow follows the drawn silhouette.
final class ChassisWindow: NSPanel {
    private let isMain: Bool

    /// The main window resizes and minimizes; an auxiliary one, such as Settings, keeps its size and only closes.
    init(content: NSView, name: String = "zshrimp", isMain: Bool = true) {
        self.isMain = isMain
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: isMain ? [.closable, .miniaturizable, .resizable, .nonactivatingPanel] : [.closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        minSize = NSSize(width: 360, height: 240)
        contentView = ChassisView(content: content, spine: SpineView(name: name, isMain: isMain))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Without a title bar AppKit has no buttons to press, so its perform* variants only beep.
    override func performClose(_ sender: Any?) {
        if delegate?.windowShouldClose?(self) ?? true { close() }
    }

    // Escape closes an auxiliary window; in the main window the terminal takes it first.
    override func cancelOperation(_ sender: Any?) {
        if !isMain { performClose(sender) }
    }

    override func performMiniaturize(_ sender: Any?) {
        miniaturize(sender)
    }

    private var unzoomedFrame: NSRect?

    override func zoom(_ sender: Any?) {
        guard styleMask.contains(.resizable), let visible = screen?.visibleFrame else { return }
        if let unzoomedFrame, frame.equalTo(visible) {
            setFrame(unzoomedFrame, display: true, animate: true)
            self.unzoomedFrame = nil
        } else {
            unzoomedFrame = frame
            setFrame(visible, display: true, animate: true)
        }
    }
}

/// The window's body: a rail on the left and the workspace set into the rest.
final class ChassisView: NSView {
    /// Heavier on the rail side, tighter on the right, so the silhouette leans.
    static let leadingRadius: CGFloat = 30
    static let trailingRadius: CGFloat = 26
    static let railWidth: CGFloat = 44
    static let inset: CGFloat = 12

    private let content: NSView
    private let spine: SpineView
    private let body = CAGradientLayer()
    private let highlight = CAShapeLayer()
    private let silhouette = CAShapeLayer()
    private let highlightFade = CAGradientLayer()

    init(content: NSView, spine: SpineView) {
        self.content = content
        self.spine = spine
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
