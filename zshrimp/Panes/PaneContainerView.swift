import AppKit

final class PaneContainerView: NSView {
    // The gap between panes is the divider's grab area.
    private static let grabWidth = max(Elevation.gap, 6)

    var onEmpty: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    private var tree = SplitTree()
    private var surfaces: [PaneID: TerminalSurface] = [:]
    private var paneViews: [PaneID: PaneView] = [:]
    private var titles: [PaneID: String] = [:]
    private var dragging: SplitTree.Divider?
    private var pendingRatio: Double?
    private let dragGuide: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        view.isHidden = true
        return view
    }()
    private var responderObservation: NSKeyValueObservation?
    private var settings = Settings.shared.values
    private var palette = ElevationPalette(Settings.shared.values)
    private var backgroundImage: NSImage?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        // The aspect-filled image overflows the view and would paint over the title bar.
        clipsToBounds = true
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
        addSubview(paneView)
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
        for (pane, frame) in tree.frames(in: workspace) {
            guard let view = paneViews[pane] else { continue }
            let half = Elevation.gap / 2
            view.frame = backingAlignedRect(frame.insetBy(dx: half, dy: half), options: .alignAllEdgesNearest)
        }
        CATransaction.commit()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    /// The tree is laid out half a gap in from the edges, so every pane ends up a full gap from the window and from its neighbors.
    private var workspace: NSRect {
        // Content runs under the transparent title bar; panes start below it.
        var area = bounds
        area.origin.y += safeAreaInsets.top
        area.size.height -= safeAreaInsets.top
        return area.insetBy(dx: Elevation.gap / 2, dy: Elevation.gap / 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let backgroundImage {
            drawAspectFill(backgroundImage)
        } else {
            palette.workspace.setFill()
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
        tree.dividers(in: workspace).last { grabRect($0).contains(point) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return divider(at: local) != nil ? self : super.hitTest(point)
    }

    override func resetCursorRects() {
        for divider in tree.dividers(in: workspace) {
            addCursorRect(grabRect(divider), cursor: divider.axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragging = divider(at: convert(event.locationInWindow, from: nil))
    }

    // Only a guide line moves while dragging; panes resize once on release so shells get one size change, not dozens.
    override func mouseDragged(with event: NSEvent) {
        guard let dragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let parent = dragging.parent
        let raw = dragging.axis == .horizontal
            ? (point.x - parent.minX) / parent.width
            : (point.y - parent.minY) / parent.height
        let ratio = min(max(raw, SplitTree.ratioRange.lowerBound), SplitTree.ratioRange.upperBound)
        pendingRatio = ratio

        if dragGuide.superview == nil { addSubview(dragGuide) }
        dragGuide.frame = dragging.axis == .horizontal
            ? NSRect(x: parent.minX + parent.width * ratio - 1, y: parent.minY, width: 2, height: parent.height)
            : NSRect(x: parent.minX, y: parent.minY + parent.height * ratio - 1, width: parent.width, height: 2)
        dragGuide.isHidden = false
    }

    override func mouseUp(with event: NSEvent) {
        if let dragging, let pendingRatio {
            tree.setRatio(pendingRatio, at: dragging.path)
            needsLayout = true
        }
        dragging = nil
        pendingRatio = nil
        dragGuide.isHidden = true
    }
}
