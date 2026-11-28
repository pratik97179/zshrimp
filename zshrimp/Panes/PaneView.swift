import AppKit
import QuartzCore

/// A pane: its terminal, a header line with the directory and a running dot, and the veil over it at rest.
/// It has no surface of its own; the terminal background and the pit behind it are one color, so panes are told apart only by the seams between them.
/// Only layer opacity animates; the terminal view is never touched.
final class PaneView: NSView {
    static let headerHeight: CGFloat = 24
    let content: NSView
    private let label = NSTextField(labelWithString: "")
    private let runningDot = CAShapeLayer()
    private var isRunning = false
    private let veil = CALayer()
    // A grey fill in saturation blend mode drains the color from whatever is beneath it.
    private let desaturation = CALayer()
    private var padding: CGFloat = 0
    private var isFocused = false
    private var isHovered = false
    private var look = PaneLook.rest

    init(content: NSView) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(content)
        label.font = Typography.paneLabel
        // The end of a path names where you are; the start is what to drop.
        label.lineBreakMode = .byTruncatingHead
        addSubview(label)

        desaturation.zPosition = 1
        desaturation.backgroundColor = NSColor.gray.cgColor
        desaturation.compositingFilter = "saturationBlendMode"
        veil.zPosition = 1.5
        runningDot.zPosition = 0.5
        runningDot.opacity = 0
        [runningDot, desaturation, veil].forEach { layer?.addSublayer($0) }

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
        veil.backgroundColor = palette.veil.cgColor
        runningDot.fillColor = palette.running.cgColor
        label.textColor = palette.label
        CATransaction.commit()
        needsLayout = true
    }

    func setDirectory(_ path: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        label.stringValue = path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
        label.toolTip = path
    }

    func setRunning(_ running: Bool) {
        guard running != isRunning else { return }
        isRunning = running
        animate(runningDot, to: running ? 1 : 0, running ? .answer : .release)
    }

    // The header is not the terminal, but a click on it still means this pane.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(content)
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
        let pace: Elevation.Pace = new.veil < look.veil ? .answer : look == .lit ? .settle : .release
        look = new
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

    override func layout() {
        super.layout()
        let header = Self.headerHeight
        content.frame = NSRect(x: padding, y: header, width: bounds.width - padding * 2, height: bounds.height - header - padding)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        veil.frame = bounds
        desaturation.frame = bounds

        let side = max(padding, 12)
        let dot: CGFloat = 6
        runningDot.frame = bounds
        runningDot.path = CGPath(ellipseIn: CGRect(x: bounds.maxX - side - dot, y: (header - dot) / 2, width: dot, height: dot), transform: nil)
        let height = label.intrinsicContentSize.height
        label.frame = NSRect(x: side, y: (header - height) / 2, width: max(0, bounds.width - side * 2 - dot - 8), height: height)

        CATransaction.commit()
    }
}
