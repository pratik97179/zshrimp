import AppKit

final class PaneContainerView: NSView {
    private static let grabWidth: CGFloat = 8

    var onEmpty: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    private var tree = SplitTree()
    private var surfaces: [PaneID: TerminalSurface] = [:]
    private var paneViews: [PaneID: PaneView] = [:]
    private var titles: [PaneID: String] = [:]
    private var dragging: SplitTree.Divider?
    private let overlay = PitOverlay()
    private var responderObservation: NSKeyValueObservation?
    private var settings = Settings.shared.values
    private var palette = ElevationPalette(Settings.shared.values)
    private var backgroundImage: NSImage?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        // The pit's rounded edge clips the panes and the aspect-filled image alike.
        clipsToBounds = true
        layer?.cornerRadius = Elevation.pitRadius
        layer?.cornerCurve = .continuous
        addSubview(overlay)
        tree.panes.forEach(addSurface)
        apply(settings)
        Task { [weak self] in
            for await values in Observations({ Settings.shared.values }) {
                guard let self else { break }
                self.apply(values)
            }
        }
    }

    private func apply(_ values: Settings.Values) {
        if values.backgroundImage != settings.backgroundImage || backgroundImage == nil {
            backgroundImage = values.backgroundImage.isEmpty ? nil : NSImage(contentsOfFile: values.backgroundImage)
        }
        settings = values
        palette = ElevationPalette(values)
        for view in paneViews.values { view.apply(values, palette) }
        overlay.palette = palette
        needsLayout = true
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func terminateAll() {
        for surface in surfaces.values {
            surface.onExit = nil
            surface.terminate()
        }
    }

    @objc func splitRight(_ sender: Any?) { split(.horizontal) }
    @objc func splitDown(_ sender: Any?) { split(.vertical) }
    @objc func focusLeft(_ sender: Any?) { moveFocus(.left) }
    @objc func focusRight(_ sender: Any?) { moveFocus(.right) }
    @objc func focusUp(_ sender: Any?) { moveFocus(.up) }
    @objc func focusDown(_ sender: Any?) { moveFocus(.down) }

    @objc func closePane(_ sender: Any?) {
        if let pane = focusedPane { close(pane) }
    }

    private func split(_ axis: Axis) {
        guard let pane = focusedPane ?? tree.panes.first, let new = tree.split(pane, axis: axis) else { return }
        addSurface(new)
        layoutSubtreeIfNeeded()
        focus(new)
    }

    private func moveFocus(_ direction: Direction) {
        guard let pane = focusedPane, let next = tree.neighbor(of: pane, direction) else { return }
        focus(next)
    }

    private func close(_ pane: PaneID) {
        guard let surface = surfaces.removeValue(forKey: pane) else { return }
        titles[pane] = nil
        let next = tree.close(pane)
        surface.onExit = nil
        surface.terminate()
        paneViews.removeValue(forKey: pane)?.removeFromSuperview()

        if tree.root == nil {
            onEmpty?()
            return
        }
        needsLayout = true
        if focusedPane == nil, let next { focus(next) }
    }

    private func addSurface(_ pane: PaneID) {
        let surface = TerminalSurface()
        surfaces[pane] = surface
        let paneView = PaneView(content: surface.view)
        paneView.apply(settings, palette)
        paneViews[pane] = paneView
        addSubview(paneView, positioned: .below, relativeTo: overlay)
        surface.onExit = { [weak self] in self?.close(pane) }
        surface.onTitleChange = { [weak self] title in self?.titleChanged(title, for: pane) }
        surface.onDirectoryChange = { [weak paneView] path in paneView?.setDirectory(path) }
        surface.onRunningChange = { [weak paneView] running in paneView?.setRunning(running) }
        paneView.setDirectory(FileManager.default.homeDirectoryForCurrentUser.path)
        needsLayout = true
        surface.start()
    }

    private var focusedPane: PaneID? {
        guard let responder = window?.firstResponder as? NSView else { return nil }
        return surfaces.first { responder.isDescendant(of: $0.value.view) }?.key
    }

    private func focus(_ pane: PaneID) {
        window?.makeFirstResponder(surfaces[pane]?.view)
    }

    private func updateFocus() {
        let focused = focusedPane
        for (pane, view) in paneViews { view.setFocused(pane == focused) }
    }

    private func titleChanged(_ title: String, for pane: PaneID) {
        titles[pane] = title
        if pane == focusedPane { onTitleChange?(title) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        responderObservation = window?.observe(\.firstResponder) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateFocus()
                guard let pane = self.focusedPane else { return }
                self.onTitleChange?(self.titles[pane] ?? "zshrimp")
            }
        }
        if focusedPane == nil, let first = tree.panes.first { focus(first) }
        // Lets the background opacity show the desktop through the window.
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (pane, frame) in tree.frames(in: bounds) {
            paneViews[pane]?.frame = backingAlignedRect(frame, options: .alignAllEdgesNearest)
        }
        CATransaction.commit()
        overlay.frame = bounds
        overlay.dividers = tree.dividers(in: bounds)
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if let backgroundImage {
            drawAspectFill(backgroundImage)
        } else {
            palette.pit.setFill()
            bounds.fill()
        }
    }

    private func drawAspectFill(_ image: NSImage) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = max(bounds.width / size.width, bounds.height / size.height)
        let drawn = NSSize(width: size.width * scale, height: size.height * scale)
        let rect = NSRect(x: bounds.midX - drawn.width / 2, y: bounds.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func grabRect(_ divider: SplitTree.Divider) -> NSRect {
        let half = Self.grabWidth / 2
        return divider.axis == .horizontal
            ? NSRect(x: divider.position - half, y: divider.parent.minY, width: Self.grabWidth, height: divider.parent.height)
            : NSRect(x: divider.parent.minX, y: divider.position - half, width: divider.parent.width, height: Self.grabWidth)
    }

    private func divider(at point: NSPoint) -> SplitTree.Divider? {
        tree.dividers(in: bounds).last { grabRect($0).contains(point) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return divider(at: local) != nil ? self : super.hitTest(point)
    }

    override func resetCursorRects() {
        for divider in tree.dividers(in: bounds) {
            addCursorRect(grabRect(divider), cursor: divider.axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragging = divider(at: convert(event.locationInWindow, from: nil))
    }

    // Panes follow the pointer live, like a window's live resize.
    override func mouseDragged(with event: NSEvent) {
        guard let dragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let parent = dragging.parent
        let ratio = dragging.axis == .horizontal
            ? (point.x - parent.minX) / parent.width
            : (point.y - parent.minY) / parent.height
        tree.setRatio(ratio, at: dragging.path)
        needsLayout = true
    }

    override func mouseUp(with event: NSEvent) {
        dragging = nil
    }
}

/// Drawn over the panes: the seams between them and the shade that presses the pit into the chassis. Takes no clicks.
private final class PitOverlay: NSView {
    var palette = ElevationPalette(Settings.shared.values) { didSet { needsDisplay = true } }
    var dividers: [SplitTree.Divider] = [] { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        for divider in dividers { drawSeam(divider, in: context) }
        drawShade(in: context)
    }

    // A line of light that fades out toward both ends, so it separates without boxing anything in.
    private func drawSeam(_ divider: SplitTree.Divider, in context: CGContext) {
        let vertical = divider.axis == .horizontal
        let parent = divider.parent.insetBy(
            dx: vertical ? 0 : divider.parent.width * (1 - Elevation.seamSpan) / 2,
            dy: vertical ? divider.parent.height * (1 - Elevation.seamSpan) / 2 : 0
        )
        let line = backingAlignedRect(
            vertical
                ? NSRect(x: divider.position - 0.5, y: parent.minY, width: 1, height: parent.height)
                : NSRect(x: parent.minX, y: divider.position - 0.5, width: parent.width, height: 1),
            options: .alignAllEdgesNearest
        )
        let length = vertical ? line.height : line.width
        let fade = min(Elevation.seamFade, length / 2) / max(length, 1)
        let clear = palette.seam.withAlphaComponent(0)
        guard let gradient = CGGradient(
            colorsSpace: nil,
            colors: [clear, palette.seam, palette.seam, clear].map(\.cgColor) as CFArray,
            locations: [0, fade, 1 - fade, 1]
        ) else { return }
        context.saveGState()
        context.clip(to: line)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: line.minX, y: line.minY),
            end: vertical ? CGPoint(x: line.minX, y: line.maxY) : CGPoint(x: line.maxX, y: line.minY),
            options: []
        )
        context.restoreGState()
    }

    // A ring outside the pit casts its shadow inward: deep under the top edge, faint along the sides.
    private func drawShade(in context: CGContext) {
        let pit = CGPath(roundedRect: bounds, cornerWidth: Elevation.pitRadius, cornerHeight: Elevation.pitRadius, transform: nil)
        let ring = CGMutablePath()
        ring.addRect(bounds.insetBy(dx: -40, dy: -40))
        ring.addPath(pit)
        context.saveGState()
        context.addPath(pit)
        context.clip()
        // Shadow offsets are in unflipped space: negative height falls downward, into the pit.
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: palette.pitShade.cgColor)
        context.addPath(ring)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }
}
