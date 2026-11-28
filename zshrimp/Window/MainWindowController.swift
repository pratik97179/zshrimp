import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private let panes = PaneContainerView()

    private var isFloating: Bool {
        get { Settings.shared.values.isFloating }
        set { Settings.shared.values.isFloating = newValue }
    }

    init() {
        let panel = ChassisWindow(content: panes)
        panel.title = "zshrimp"
        panel.hidesOnDeactivate = false
        panel.center()
        super.init(window: panel)

        panel.delegate = self
        panes.onTitleChange = { [weak panel] title in panel?.title = title }
        panes.onEmpty = { [weak panel] in panel?.close() }
        Task { [weak self] in
            for await _ in Observations({ Settings.shared.values.isFloating }) {
                guard let self else { break }
                self.applyFloating()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func terminateSessions() {
        panes.terminateAll()
    }

    @objc func toggleFloating(_ sender: Any?) {
        isFloating.toggle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleFloating(_:)) {
            menuItem.state = isFloating ? .on : .off
        }
        return true
    }

    private func applyFloating() {
        guard let window else { return }
        window.level = isFloating ? .floating : .normal
        window.collectionBehavior = isFloating ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    // Non-activating is fixed at creation and needed to float over full-screen apps; normal mode activates by hand.
    func windowDidBecomeKey(_ notification: Notification) {
        if !isFloating { NSApp.activate() }
    }

    func windowWillClose(_ notification: Notification) {
        panes.terminateAll()
    }
}
