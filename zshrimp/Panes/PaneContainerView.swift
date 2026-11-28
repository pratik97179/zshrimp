import AppKit

final class PaneContainerView: NSView {
    private static let dividerWidth: CGFloat = 1
    private static let grabWidth: CGFloat = 6

    var onEmpty: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    private var tree = SplitTree()
    private var surfaces: [PaneID: TerminalSurface] = [:]
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
    private var paneFrames: [PaneID: NSRect] = [:]
    private var settings = Settings.shared.values
    private var backgroundImage: NSImage?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
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
        surface.view.removeFromSuperview()
        paneFrames[pane] = nil

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
        addSubview(surface.view)
        surface.onExit = { [weak self] in self?.close(pane) }
        surface.onTitleChange = { [weak self] title in self?.titleChanged(title, for: pane) }
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

    private func titleChanged(_ title: String, for pane: PaneID) {
        titles[pane] = title
        if pane == focusedPane { onTitleChange?(title) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        responderObservation = window?.observe(\.firstResponder) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, let pane = self.focusedPane else { return }
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
        let half = Self.dividerWidth / 2
        for (pane, frame) in tree.frames(in: bounds) {
            // Leave half a divider on every edge shared with another pane.
            let inset = NSRect(
                x: frame.minX + (frame.minX > bounds.minX ? half : 0),
                y: frame.minY + (frame.minY > bounds.minY ? half : 0),
                width: frame.width - (frame.minX > bounds.minX ? half : 0) - (frame.maxX < bounds.maxX ? half : 0),
                height: frame.height - (frame.minY > bounds.minY ? half : 0) - (frame.maxY < bounds.maxY ? half : 0)
            )
            let paneFrame = backingAlignedRect(inset, options: .alignAllEdgesNearest)
            paneFrames[pane] = paneFrame
            surfaces[pane]?.view.frame = paneFrame.insetBy(dx: settings.padding, dy: settings.padding)
        }
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    // The terminal paints its own background, so only the padding ring around it is filled here.
    override func draw(_ dirtyRect: NSRect) {
        if let backgroundImage { drawAspectFill(backgroundImage) }

        settings.backgroundColor.setFill()
        for (pane, frame) in paneFrames {
            guard let view = surfaces[pane]?.view else { continue }
            let ring = NSBezierPath(rect: frame)
            ring.append(NSBezierPath(rect: view.frame))
            ring.windingRule = .evenOdd
            ring.fill()
        }

        NSColor.separatorColor.setFill()
        for divider in tree.dividers(in: bounds) {
            let half = Self.dividerWidth / 2
            let rect = divider.axis == .horizontal
                ? NSRect(x: divider.position - half, y: divider.parent.minY, width: Self.dividerWidth, height: divider.parent.height)
                : NSRect(x: divider.parent.minX, y: divider.position - half, width: divider.parent.width, height: Self.dividerWidth)
            backingAlignedRect(rect, options: .alignAllEdgesNearest).fill()
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
